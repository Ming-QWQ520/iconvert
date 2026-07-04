/// BackgroundService - 管理背景图路径
library;

import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class BackgroundService {
  static const _keyBackgroundPath = 'iconvert_background_path';

  /// 默认背景（assets 内）
  static const defaultBackground = 'assets/default_background.png';

  /// 获取背景路径
  /// 返回 'assets/...' 表示内置资源，否则是文件系统绝对路径
  static Future<String> getBackgroundPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBackgroundPath) ?? defaultBackground;
  }

  /// 设置背景路径
  static Future<void> setBackgroundPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBackgroundPath, path);
  }

  /// 重置为默认背景
  static Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBackgroundPath);
  }

  /// 从相册选择背景图
  /// 返回选中的文件路径，null 表示用户取消
  static Future<String?> pickFromGallery() async {
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image != null) {
        await setBackgroundPath(image.path);
        return image.path;
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  /// 判断路径是否是 assets 资源
  static bool isAsset(String path) {
    return path.startsWith('assets/');
  }

  /// 判断背景文件是否存在（文件系统路径）
  static bool fileExists(String path) {
    if (isAsset(path)) return true;
    return File(path).existsSync();
  }
}
