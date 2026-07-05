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
  static const _keyLiquidGlass = 'iconvert_liquid_glass';
  static const _keyLiquidGlassBlur = 'iconvert_liquid_glass_blur';
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

  /// 获取液态玻璃开关（默认关闭）
  static Future<bool> isLiquidGlassEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLiquidGlass) ?? false;
  }

  /// 设置液态玻璃开关
  static Future<void> setLiquidGlassEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLiquidGlass, enabled);
  }

  /// 获取液态玻璃模糊强度（0.0 - 1.0）
  /// 0.0 = 几乎无模糊（清晰），1.0 = 强模糊
  static Future<double> getLiquidGlassBlur() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyLiquidGlassBlur) ?? 0.4;
  }

  /// 设置液态玻璃模糊强度
  static Future<void> setLiquidGlassBlur(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLiquidGlassBlur, value.clamp(0.0, 1.0));
  }

  static String get defaultOutputDir => _defaultOutputDir;
}
