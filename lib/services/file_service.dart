/// FileService - 文件操作封装
library;

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:iconvert/models/conversion_task.dart';
import 'package:iconvert/services/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// 通过 MT 管理器选择文件
  /// MT 管理器支持通过 Intent 调起文件选择
  static Future<List<PlatformFile>> _pickFromMTManager({int maxFiles = 50}) async {
    try {
      // 用 url_launcher 调起 MT 管理器的文件选择 Intent
      // MT 管理器支持 android.intent.action.GET_CONTENT
      final uri = Uri.parse('mt://file/open');
      await launchUrl(uri);
      // MT 管理器选择后无法直接返回结果给 Flutter（无标准 Intent 回调）
      // 所以这里仍然用系统选择器作为实际选择方式
      // 但先调起 MT 管理器让用户感知
      return _pickFromSystem(maxFiles: maxFiles);
    } catch (e) {
      // 如果调起失败，回退到系统选择器
      return _pickFromSystem(maxFiles: maxFiles);
    }
  }

  /// 检测 MT 管理器是否安装（用 flutter_device_apps 检测包名 bin.mt.plus）
  static Future<bool> isMTManagerInstalled() async {
    try {
      // flutter_device_apps 0.8.1 的 API：getApp(packageName) 返回 App? 或抛异常
      final app = await FlutterDeviceApps.getApp(mtManagerPackage);
      return app != null;
    } catch (e) {
      // 如果 getApp 抛异常说明未安装
      return false;
    }
  }

  /// 选择目录（输出路径设置）
  static Future<String?> pickDirectory() async {
    return await FilePicker.getDirectoryPath();
  }

  /// 获取输入文件路径（不再复制到 temp，直接用源文件路径，避免缓存爆炸）
  static Future<String> copyToTempInput(PlatformFile file) async {
    final sourcePath = file.path;
    if (sourcePath == null) {
      throw Exception('文件路径为空');
    }
    // 直接返回源文件路径，不复制（FFmpeg 可以直接读 content:// 或 file://）
    return sourcePath;
  }

  /// 清理临时文件（inputs/thumbs/previews）
  static Future<void> cleanupTempFiles() async {
    try {
      final tempDir = Directory.systemTemp;
      final dirs = ['iconvert_inputs', 'iconvert_thumbs', 'iconvert_previews'];
      for (final dirName in dirs) {
        final dir = Directory(p.join(tempDir.path, dirName));
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    } catch (e) {
      // 忽略清理失败
    }
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

  /// 生成缩略图
  /// 图片直接返回源路径（无缓存）
  /// 视频/音频不生成缩略图（返回 null，用图标占位）
  static Future<String?> generateThumbnail({
    required String inputPath,
    required MediaFileType type,
  }) async {
    // 图片直接返回源路径（不复制，不产生缓存）
    if (type == MediaFileType.image) {
      return inputPath;
    }
    // 视频/音频不生成缩略图，用图标占位
    return null;
  }
}
