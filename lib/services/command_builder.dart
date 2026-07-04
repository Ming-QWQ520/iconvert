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
    } else {
      parts.addAll(_buildVideoArgs(task));
    }

    parts.add(outputPath);
    return parts.join(' ');
  }

  /// 构建图片转换参数（支持 JPEG/PNG/WebP/HEIF/HEIC/BMP/TIFF/GIF/SVG/ICO）
  static List<String> _buildImageArgs(ConversionTask task) {
    final args = <String>[];
    final fmt = task.outputFormat.toLowerCase();
    final traits = task.imageTraits;

    // 视频滤镜（SVG 矢量格式不在此处处理）
    if (!traits.contains(ImageFormatTrait.vector)) {
      final filters = <String>[];

      // 分辨率缩放
      if (task.width != null && task.height != null) {
        filters.add(
          'scale=${task.width}:${task.height}:force_original_aspect_ratio=decrease,'
          'pad=${task.width}:${task.height}:(ow-iw)/2:(oh-ih)/2',
        );
      }

      // 透明背景填充（目标格式不支持透明 或 用户主动关闭透明）
      final targetSupportsAlpha = traits.contains(ImageFormatTrait.transparency);
      if (targetSupportsAlpha && !task.keepTransparency && task.backgroundColor != null) {
        // 用 background color 填充透明区域
        final hex = (task.backgroundColor! & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
        filters.add('format=rgba,colorize=0:0x$hex:1.0');
      } else if (!targetSupportsAlpha) {
        // 目标格式本身不支持透明，强制填充白色（除非用户指定其他色）
        final fillHex = task.backgroundColor != null
            ? (task.backgroundColor! & 0xFFFFFF).toRadixString(16).padLeft(6, '0')
            : 'ffffff';
        filters.add('format=rgb24,fill=0x$fillHex');
      }

      if (filters.isNotEmpty) {
        args.add('-vf');
        args.add(filters.join(','));
      }
    }

    // 格式特定编码参数
    switch (fmt) {
      case 'jpg':
      case 'jpeg':
        // JPEG 质量 1-100 → ffmpeg q 31-2（反向）
        final q = (31 - (task.quality / 100) * 29).round().clamp(2, 31);
        args.addAll(['-q:v', q.toString()]);
        break;
      case 'webp':
        // WebP 直接用 -qscale (1-100)
        args.addAll(['-q:v', task.quality.toString()]);
        // 启用 lossless 模式（quality=100 时）
        if (task.quality >= 100) {
          args.addAll(['-lossless', '1']);
        }
        break;
      case 'heic':
      case 'heif':
        // HEIF 用 libx265，CRF 0-51（quality 100→CRF 0，quality 1→CRF 51）
        final crf = (51 - (task.quality / 100) * 40).round().clamp(0, 51);
        args.addAll(['-c:v', 'libx265', '-crf', crf.toString(), '-pix_fmt', 'yuv420p']);
        args.addAll(['-tag:v', 'hvc1']);  // iOS 兼容
        break;
      case 'png':
        args.addAll(['-compression_level', '6']);
        break;
      case 'bmp':
      case 'tiff':
      case 'tif':
      case 'ico':
        // 无损格式，无需额外参数
        break;
      case 'gif':
        // GIF 动图：调色板生成 + 帧率 + 循环
        // 注意：完整的 GIF 动画优化需要两遍处理，这里用单遍简化版
        final fps = task.fps ?? 10;
        final colors = task.paletteColors ?? 256;
        final vfFilters = <String>[];
        if (task.width != null && task.height != null) {
          vfFilters.add('scale=${task.width}:${task.height}');
        }
        vfFilters.add('fps=$fps');
        vfFilters.add('split[s0][s1];[s0]palettegen=max_colors=$colors[p];[s1][p]paletteuse');
        // 替换之前的 -vf
        if (args.isNotEmpty && args.last.startsWith('scale=')) {
          args.removeLast();  // 移除之前加的 -vf
          args.removeLast();
        }
        args.add('-vf');
        args.add(vfFilters.join(','));
        // 循环次数（0=无限）
        args.addAll(['-loop', (task.loopCount ?? 0).toString()]);
        break;
      case 'svg':
        // SVG 是矢量格式，FFmpeg 不直接支持 SVG 输出
        // SVG 输入时可以用 scale 缩放，但输出仍为位图
        // 这里 SVG 作为输出格式属于"复制源文件"语义（如果输入也是 SVG）
        // 简化处理：SVG 输出实际是位图，按 PNG 编码
        if (task.svgScale != null && task.svgScale != 1.0) {
          args.add('-vf');
          args.add('scale=iw*${task.svgScale}:ih*${task.svgScale}');
        }
        args.addAll(['-compression_level', '6']);
        break;
    }

    return args;
  }

  static List<String> _buildVideoArgs(ConversionTask task) {
    final args = <String>[];

    if (task.width != null && task.height != null) {
      args.add('-vf');
      args.add(
        'scale=${task.width}:${task.height}:force_original_aspect_ratio=decrease,'
        'pad=${task.width}:${task.height}:(ow-iw)/2:(oh-ih)/2',
      );
    }

    switch (task.outputFormat.toLowerCase()) {
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
        args.addAll(['-c:v', 'libopenh264', '-b:v', _videoBitrate(task)]);
        args.addAll(['-c:a', 'aac', '-b:a', '128k']);
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
