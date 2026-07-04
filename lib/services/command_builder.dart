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

  static List<String> _buildImageArgs(ConversionTask task) {
    final args = <String>[];

    if (task.width != null && task.height != null) {
      args.add('-vf');
      args.add(
        'scale=${task.width}:${task.height}:force_original_aspect_ratio=decrease,'
        'pad=${task.width}:${task.height}:(ow-iw)/2:(oh-ih)/2',
      );
    }

    switch (task.outputFormat.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        final q = (31 - (task.quality / 100) * 29).round().clamp(2, 31);
        args.addAll(['-q:v', q.toString()]);
        break;
      case 'webp':
        args.addAll(['-q:v', (task.quality / 10).round().toString()]);
        break;
      case 'png':
        args.addAll(['-compression_level', '6']);
        break;
      case 'bmp':
      case 'tiff':
      case 'tif':
        // BMP/TIFF 无损，无需额外参数
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
        // MOV/AVI/FLV 用 H.264 + AAC 通用兼容
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
