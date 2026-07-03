/// FileService - 文件操作封装
///
/// 提供文件选择、路径处理、临时目录管理、缩略图生成等功能。
/// 通过 file_picker 走 SAF（无需动态权限），降级用传统路径。
library;

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:iconvert/models/conversion_task.dart';

class FileService {
  /// 允许的文件扩展名
  static const imageExts = ['jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp'];
  static const videoExts = ['mp4', 'mkv', 'mov', 'avi', 'webm', 'flv', 'wmv'];

  /// 多选文件，返回平台文件对象列表
  static Future<List<PlatformFile>> pickFiles({int maxFiles = 50}) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [...imageExts, ...videoExts],
    );
    if (result == null) return [];
    return result.files.take(maxFiles).toList();
  }

  /// 选择目录（输出路径设置）
  static Future<String?> pickDirectory() async {
    return await FilePicker.getDirectoryPath();
  }

  /// 把选中的文件复制到 temp/inputs/，返回新路径（FFmpeg 用绝对路径）
  static Future<String> copyToTempInput(PlatformFile file) async {
    final tempDir = Directory.systemTemp;
    final inputsDir = Directory(p.join(tempDir.path, 'iconvert_inputs'));
    if (!await inputsDir.exists()) {
      await inputsDir.create(recursive: true);
    }

    final destPath = p.join(inputsDir.path, file.name);
    final sourcePath = file.path;
    if (sourcePath == null) {
      throw Exception('文件路径为空');
    }

    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// 推断文件类型（基于扩展名）
  static MediaFileType inferType(String filename) {
    final ext = p.extension(filename).toLowerCase().replaceAll('.', '');
    if (imageExts.contains(ext)) return MediaFileType.image;
    return MediaFileType.video;
  }

  /// 生成输出文件路径
  static Future<String> generateOutputPath({
    required String outputDir,
    required String originalName,
    required String outputFormat,
  }) async {
    final baseName = p.basenameWithoutExtension(originalName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = '${baseName}_$timestamp.$outputFormat';
    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return p.join(outputDir, filename);
  }

  /// 从绝对路径获取 File 对象
  static Future<File> fileFromPath(String path) async {
    return File(path);
  }

  /// 生成缩略图（图片直接复制，视频用 video_thumbnail）
  /// 返回缩略图绝对路径，失败返回 null
  static Future<String?> generateThumbnail({
    required String inputPath,
    required MediaFileType type,
  }) async {
    try {
      final tempDir = Directory.systemTemp;
      final thumbDir = Directory(p.join(tempDir.path, 'iconvert_thumbs'));
      if (!await thumbDir.exists()) {
        await thumbDir.create(recursive: true);
      }
      final thumbPath = p.join(
        thumbDir.path,
        '${p.basenameWithoutExtension(inputPath)}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (type == MediaFileType.image) {
        // 图片：直接复制，UI 端用 cacheWidth 缩放显示
        await File(inputPath).copy(thumbPath);
      } else {
        // 视频：用 FFmpeg 抽首帧生成缩略图
        // -ss 0 -i input -frames:v 1 -vf scale=200:200:force_original_aspect_ratio=decrease
        final cmd = '-ss 0 -i "$inputPath" -frames:v 1 '
            '-vf "scale=200:200:force_original_aspect_ratio=decrease" '
            '-q:v 5 "$thumbPath" -y';
        final session = await FFmpegKit.execute(cmd);
        final code = await session.getReturnCode();
        if (!ReturnCode.isSuccess(code)) {
          return null;
        }
      }
      return thumbPath;
    } catch (e) {
      return null;
    }
  }
}
