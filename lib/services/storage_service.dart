/// StorageService - 本地持久化存储
///
/// 通过 SharedPreferences 存储输出路径等配置。
library;

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _keyOutputDir = 'iconvert_output_dir';
  static const _defaultOutputDir = '/storage/emulated/0/Download/iConvert';

  /// 获取输出目录
  static Future<String> getOutputDir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOutputDir) ?? _defaultOutputDir;
  }

  /// 设置输出目录
  static Future<void> setOutputDir(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOutputDir, path);
  }

  /// 默认输出目录
  static String get defaultOutputDir => _defaultOutputDir;
}
