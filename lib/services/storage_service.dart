/// StorageService - 本地持久化存储
library;

import 'package:shared_preferences/shared_preferences.dart';

/// 文件选择器类型
enum FilePickerType {
  gallery,    // 系统相册（默认）
  system,     // 系统原生选择器
  mtManager,  // MT 管理器
}

class StorageService {
  static const _keyOutputDir = 'iconvert_output_dir';
  static const _keyFirstRunDone = 'iconvert_first_run_done';
  static const _keyFilePickerType = 'iconvert_file_picker_type';
  static const _defaultOutputDir = '/storage/emulated/0/Download/iConvert';

  static Future<String> getOutputDir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOutputDir) ?? _defaultOutputDir;
  }

  static Future<void> setOutputDir(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOutputDir, path);
    await prefs.setBool(_keyFirstRunDone, true);
  }

  static Future<bool> isFirstRunDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFirstRunDone) ?? false;
  }

  /// 获取文件选择器类型（默认 gallery）
  static Future<FilePickerType> getFilePickerType() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_keyFilePickerType) ?? 0;
    return FilePickerType.values[index];
  }

  /// 设置文件选择器类型
  static Future<void> setFilePickerType(FilePickerType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFilePickerType, type.index);
  }

  static String get defaultOutputDir => _defaultOutputDir;
}
