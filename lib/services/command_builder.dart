/// CommandBuilder - FFmpeg 命令构建与执行
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:iconvert/models/conversion_task.dart';
import 'package:iconvert/services/file_service.dart';

class CommandBuilder {
  static FFmpegSession? _currentSession;

  static void cancel() {
    _currentSession?.cancel();
    _currentSession = null;
  }

  static Future<String> execute({
    required ConversionTask task,
    required String outputDir,
    required void Function(double progress) onProgress,
  }) async {
    final outputPath = await FileService.generateOutputPath(
      outputDir: outputDir,
      originalName: task.originalName,
      outputFormat: task.outputFormat,
    );

    final command = build(task: task, outputPath: outputPath);
    debugPrint('FFmpeg 命令: ffmpeg $command');

    final inputFile = File(task.inputPath);
    if (!await inputFile.exists()) {
      throw Exception('输入文件不存在: ${task.inputPath}');
    }

    final completer = Completer<String>();

    final session = await FFmpegKit.executeAsync(
      command,
      (session) async {
        final code = await session.getReturnCode();
        if (ReturnCode.isSuccess(code)) {
          if (!completer.isCompleted) completer.complete(outputPath);
        } else {
          final logs = await session.getAllLogsAsString();
          final logsStr = logs ?? '';
          final tail = logsStr.length > 300
              ? logsStr.substring(logsStr.length - 300)
              : logsStr;
          if (!completer.isCompleted) {
            completer.completeError(Exception('FFmpeg 转换失败: $tail'));
          }
        }
      },
      (log) {
        final progress = _parseProgress(log.getMessage());
        if (progress != null) onProgress(progress);
      },
    );

    _currentSession = session;

    try {
      return await completer.future.timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          _currentSession?.cancel();
          throw Exception('FFmpeg 转换超时');
        },
      );
    } finally {
      _currentSession = null;
    }
  }

  static String build({
    required ConversionTask task,
    required String outputPath,
  }) {
    final parts = <String>['-y', '-i', task.inputPath];

    if (task.type == MediaFileType.image) {
      parts.addAll(_buildImageArgs(task));
    } else if (task.type == MediaFileType.audio) {
      parts.addAll(_buildAudioArgs(task));
    } else {
      parts.addAll(_buildVideoArgs(task));
    }

    parts.add(outputPath);
    return parts.join(' ');
  }

  /// 构建图片转换参数
  /// 支持: JPEG/PNG/WebP/HEIC/BMP/GIF/ICO/TIFF
  /// 注意: SVG 作为输出已移除（FFmpeg 不支持写 SVG）
  static List<String> _buildImageArgs(ConversionTask task) {
    final args = <String>[];
    final fmt = task.outputFormat.toLowerCase();
    final traits = task.imageTraits;

    // 构建滤镜链（GIF 特殊处理，用 filter_complex）
    final filters = <String>[];

    // 分辨率缩放
    if (task.width != null && task.height != null) {
      filters.add('scale=${task.width}:${task.height}:force_original_aspect_ratio=decrease');
      filters.add('pad=${task.width}:${task.height}:(ow-iw)/2:(oh-ih)/2:color=white');
    }

    // 不支持透明的格式 → 转 rgb24（丢弃 alpha 通道）
    if (!traits.contains(ImageFormatTrait.transparency)) {
      filters.add('format=rgb24');
    }
    // 支持透明但用户关闭了透明 → 也转 rgb24
    else if (!task.keepTransparency) {
      filters.add('format=rgb24');
    }

    // GIF 特殊处理：需要 filter_complex（调色板生成）
    if (fmt == 'gif') {
      // 静态图片转 GIF：简单转换即可，不需要动画参数
      // 但可以优化调色板
      final paletteColors = task.paletteColors ?? 256;
      if (filters.isNotEmpty) {
        args.add('-vf');
        args.add(filters.join(','));
      }
      // GIF 调色板优化（两遍处理太慢，单遍用默认调色板）
      args.addAll(['-loop', (task.loopCount ?? 0).toString()]);
      return args;
    }

    // 非 GIF 格式：应用滤镜
    if (filters.isNotEmpty) {
      args.add('-vf');
      args.add(filters.join(','));
    }

    // 格式特定编码参数
    switch (fmt) {
      case 'jpg':
      case 'jpeg':
        final q = (31 - (task.quality / 100) * 29).round().clamp(2, 31);
        args.addAll(['-q:v', q.toString()]);
        break;
      case 'webp':
        args.addAll(['-q:v', task.quality.toString()]);
        break;
      case 'heic':
      case 'heif':
        // HEIF: 尝试用 libx265 编码 + heic 容器
        // 注意：FFmpeg 默认可能不支持 heic 容器输出，会自动 fallback 到 mp4
        final crf = (51 - (task.quality / 100) * 40).round().clamp(0, 51);
        args.addAll(['-c:v', 'libx265', '-crf', crf.toString(), '-pix_fmt', 'yuv420p']);
        args.addAll(['-tag:v', 'hvc1']);
        // 不指定 -f heic，让 FFmpeg 根据扩展名自动选择容器
        // 如果 heic 不支持会 fallback 到 mp4/mov
        break;
      case 'png':
        args.addAll(['-compression_level', '6']);
        break;
      case 'bmp':
      case 'tiff':
      case 'tif':
        // 无损格式，FFmpeg 原生支持，无需额外参数
        break;
      case 'ico':
        // ICO 实际是容器格式，FFmpeg 用 image2 muxer + png 编码
        // 输出 .ico 扩展名时 FFmpeg 会自动处理
        args.addAll(['-c:v', 'png', '-f', 'image2']);
        break;
    }

    return args;
  }

  static List<String> _buildVideoArgs(ConversionTask task) {
    final args = <String>[];
    final fmt = task.outputFormat.toLowerCase();

    // GIF 视频：需要 filter_complex 做调色板 + 帧率
    if (fmt == 'gif') {
      final fps = task.fps ?? 10;
      final colors = task.paletteColors ?? 256;
      final baseFilters = <String>['fps=$fps'];
      if (task.width != null && task.height != null) {
        baseFilters.add('scale=${task.width}:${task.height}');
      }
      final filterStr = '${baseFilters.join(',')},split[s0][s1];'
          '[s0]palettegen=max_colors=$colors[p];'
          '[s1][p]paletteuse';
      args.add('-filter_complex');
      args.add(filterStr);
      args.addAll(['-loop', (task.loopCount ?? 0).toString()]);
      return args;
    }

    // 普通视频格式
    if (task.width != null && task.height != null) {
      args.add('-vf');
      args.add(
        'scale=${task.width}:${task.height}:force_original_aspect_ratio=decrease,'
        'pad=${task.width}:${task.height}:(ow-iw)/2:(oh-ih)/2',
      );
    }

    switch (fmt) {
      case 'mp4':
        args.addAll(['-c:v', 'h264_mediacodec', '-b:v', _videoBitrate(task)]);
        args.addAll(['-c:a', 'aac', '-b:a', '128k']);
        args.add('-movflags');
        args.add('+faststart');
        break;
      case 'mkv':
        args.addAll(['-c:v', 'libopenh264', '-b:v', _videoBitrate(task)]);
        args.addAll(['-c:a', 'aac', '-b:a', '128k']);
        break;
      case 'webm':
        args.addAll(['-c:v', 'libvpx-vp9', '-crf', _vp9Crf(task)]);
        args.addAll(['-c:a', 'libopus', '-b:a', '128k']);
        break;
      case 'mov':
      case 'avi':
      case 'flv':
      case 'wmv':
      case 'mpeg':
      case 'mpg':
        // MOV/AVI/FLV/WMV/MPEG/MPG 用 H.264 + AAC 通用兼容
        args.addAll(['-c:v', 'libopenh264', '-b:v', _videoBitrate(task)]);
        args.addAll(['-c:a', 'aac', '-b:a', '128k']);
        // WMV 用 wmv2 编码更兼容
        if (fmt == 'wmv') {
          args.addAll(['-c:v', 'wmv2', '-b:v', _videoBitrate(task)]);
          args.addAll(['-c:a', 'wmav2', '-b:a', '128k']);
        }
        break;
    }

    return args;
  }

  /// 构建音频转换参数
  /// 支持: MP3/AAC/WMA/OGG/FLAC/WAV/APE
  /// 参数: 采样率/量化位数/比特率/声道/3D环绕
  static List<String> _buildAudioArgs(ConversionTask task) {
    final args = <String>[];
    final fmt = task.outputFormat.toLowerCase();

    // 3D 环绕效果：左右声道单声道循环变大变小
    // 用 pan 滤镜把左声道设为左耳+部分右耳，右声道设为右耳+部分左耳
    // 然后用 aecho 和 tremolo 制造空间感和循环起伏
    if (task.enable3DSurround) {
      args.add('-filter_complex');
      // 3D 环绕：把单声道扩展为立体声，并用 tremolo 制造左右循环变化
      // [0:a]asetpts=N/SR/TB[a]; 
      // 用 pan 分离左右声道，再各自加 tremolo（不同频率制造空间感）
      args.add(
        '[0:a]aformat=channel_layouts=stereo,'
        'tremolo=f=0.5:d=0.3,'
        'aecho=0.8:0.7:20:0.3,'
        'volume=1.2'
      );
    }

    // 采样率
    if (task.sampleRate != null) {
      args.addAll(['-ar', task.sampleRate.toString()]);
    }

    // 声道数
    if (task.channels != null) {
      args.addAll(['-ac', task.channels.toString()]);
    }

    // 格式特定编码参数
    switch (fmt) {
      case 'mp3':
        args.addAll(['-c:a', 'libmp3lame']);
        if (task.audioBitrate != null) {
          args.addAll(['-b:a', '${task.audioBitrate}k']);
        }
        // 量化位数（MP3 仅支持 16-bit，所以这里忽略）
        break;
      case 'aac':
      case 'm4a':
        args.addAll(['-c:a', 'aac']);
        if (task.audioBitrate != null) {
          args.addAll(['-b:a', '${task.audioBitrate}k']);
        }
        break;
      case 'wma':
        args.addAll(['-c:a', 'wmav2']);
        if (task.audioBitrate != null) {
          args.addAll(['-b:a', '${task.audioBitrate}k']);
        }
        break;
      case 'ogg':
        args.addAll(['-c:a', 'libvorbis']);
        if (task.audioBitrate != null) {
          args.addAll(['-b:a', '${task.audioBitrate}k']);
        }
        break;
      case 'flac':
        args.addAll(['-c:a', 'flac']);
        if (task.bitDepth != null) {
          args.addAll(['-sample_fmt', 's${task.bitDepth}']);
        }
        break;
      case 'wav':
        args.addAll(['-c:a', 'pcm_s16le']);
        if (task.bitDepth == 24) {
          args.addAll(['-c:a', 'pcm_s24le']);
        } else if (task.bitDepth == 32) {
          args.addAll(['-c:a', 'pcm_s32le']);
        }
        break;
      case 'ape':
        // APE (Monkey's Audio) FFmpeg 可能不支持编码，fallback 到 FLAC
        args.addAll(['-c:a', 'flac']);
        break;
    }

    return args;
  }

  static String _videoBitrate(ConversionTask task) {
    final kbps = task.quality * 25 + 500;
    return '${kbps}k';
  }

  static String _vp9Crf(ConversionTask task) {
    final crf = (28 - (task.quality / 100) * 11).round().clamp(17, 28);
    return crf.toString();
  }

  static double? _parseProgress(String log) {
    final match = RegExp(r'time=(\d+):(\d+):(\d+\.\d+)').firstMatch(log);
    if (match == null) return null;
    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final s = double.parse(match.group(3)!);
    final seconds = h * 3600 + m * 60 + s;
    return (seconds / 600).clamp(0.0, 0.95);
  }
}

Future<void> _warmupFFmpeg() async {
  try {
    await FFmpegKitConfig.init();
  } catch (e) {
    debugPrint('FFmpeg 预热: $e');
  }
}

Future<void> warmupFFmpeg() => _warmupFFmpeg();
