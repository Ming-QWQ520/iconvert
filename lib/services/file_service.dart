/// FileService - 文件操作封装
library;

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:iconvert/models/conversion_task.dart';
import 'package:iconvert/services/storage_service.dart';

class FileService {
  /// MT 管理器包名
  static const mtManagerPackage = 'bin.mt.plus';

  /// 允许的文件扩展名
  static const imageExts = [
    'jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp',
    'tiff', 'tif', 'ico', 'tga', 'ppm', 'pgm', 'pbm',
    'heic', 'heif', 'svg',
  ];
  static const videoExts = [
    'mp4', 'mkv', 'mov', 'avi', 'webm', 'flv', 'wmv',
    'mpeg', 'mpg', 'ts', 'm2ts', 'mts', '3gp', '3g2',
    'vob', 'ogv', 'rm', 'rmvb', 'asf', 'f4v',
  ];
  static const audioExts = [
    'mp3', 'aac', 'wma', 'ogg', 'flac', 'wav', 'ape',
    'm4a', 'opus', 'amr', 'aac', 'ac3', 'aiff',
  ];

  /// 根据设置选择对应的文件选择方式
  /// [mediaType] 媒体类型（image/video/audio），相册模式用
  /// [allowedExtensions] 允许的扩展名，系统选择器模式用
  static Future<List<PlatformFile>> pickFiles({
    int maxFiles = 50,
    List<String>? allowedExtensions,
    MediaFileType? mediaType,
  }) async {
    final pickerType = await StorageService.getFilePickerType();

    switch (pickerType) {
      case FilePickerType.gallery:
        return _pickFromGallery(mediaType: mediaType ?? MediaFileType.image, maxFiles: maxFiles);
      case FilePickerType.mtManager:
        return _pickFromMTManager(maxFiles: maxFiles);
      case FilePickerType.system:
        return _pickFromSystem(allowedExtensions: allowedExtensions, maxFiles: maxFiles);
    }
  }

  /// 通过 image_picker 调起系统相册
  static Future<List<PlatformFile>> _pickFromGallery({
    required MediaFileType mediaType,
    int maxFiles = 50,
  }) async {
    final picker = ImagePicker();
    try {
      if (mediaType == MediaFileType.image) {
        // 多选图片
        final images = await picker.pickMultiImage(
          imageQuality: 100,
          limit: maxFiles,
        );
        return images.map((xfile) => PlatformFile(
          path: xfile.path,
          name: xfile.name,
          size: 0,
        )).toList();
      } else if (mediaType == MediaFileType.video) {
        // 单选视频（image_picker 不支持多选视频）
        final video = await picker.pickVideo(source: ImageSource.gallery);
        if (video == null) return [];
        return [PlatformFile(path: video.path, name: video.name, size: 0)];
      } else {
        // 音频用系统选择器
        return _pickFromSystem(allowedExtensions: audioExts.toList(), maxFiles: maxFiles);
      }
    } catch (e) {
      // 失败回退到系统选择器
      return _pickFromSystem(allowedExtensions: mediaType == MediaFileType.image
          ? imageExts.toList()
          : (mediaType == MediaFileType.video ? videoExts.toList() : audioExts.toList()),
          maxFiles: maxFiles);
    }
  }

  /// 通过系统原生选择器（file_picker）
  static Future<List<PlatformFile>> _pickFromSystem({
    List<String>? allowedExtensions,
    int maxFiles = 50,
  }) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: allowedExtensions ?? [...imageExts, ...videoExts, ...audioExts],
    );
    if (result == null) return [];
    return result.files.take(maxFiles).toList();
  }

  /// 通过 MT 管理器选择文件（用 Intent）
  /// 检测包名 bin.mt.plus 是否安装
  static Future<List<PlatformFile>> _pickFromMTManager({int maxFiles = 50}) async {
    // MT 管理器不支持多选返回，回退到系统选择器
    // 这里先用系统选择器代替，但保留检测逻辑
    return _pickFromSystem(maxFiles: maxFiles);
  }

  /// 检测 MT 管理器是否安装
  static Future<bool> isMTManagerInstalled() async {
    try {
      // 通过文件系统检查包名（简单实现）
      // 实际应该用 package_info_plus 或 device_apps 插件
      // 这里简化：返回 false，让 UI 提示用户
      return false;
    } catch (e) {
      return false;
    }
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
    if (audioExts.contains(ext)) return MediaFileType.audio;
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

  /// 生成缩略图（图片直接复制，视频用 FFmpeg 抽首帧）
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
        await File(inputPath).copy(thumbPath);
      } else {
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
