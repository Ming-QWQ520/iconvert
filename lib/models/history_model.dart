/// HistoryModel - 历史记录持久化管理
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iconvert/models/conversion_task.dart';
import 'package:iconvert/services/file_service.dart';

class HistoryModel extends ChangeNotifier {
  static const _key = 'iconvert_history';
  final List<ConversionTask> _history = [];

  List<ConversionTask> get history => List.unmodifiable(_history);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        _history.clear();
        _history.addAll(
          list.map((e) => ConversionTask.fromJson(e as Map<String, dynamic>)),
        );
        _history.sort((a, b) =>
            (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));
        notifyListeners();
      } catch (e) {
        debugPrint('加载历史失败: $e');
      }
    }
  }

  Future<void> add(ConversionTask task) async {
    _history.insert(0, task);
    await _persist();
    notifyListeners();
  }

  Future<void> removeRecord(String id) async {
    _history.removeWhere((t) => t.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> removeRecordAndFile(String id) async {
    final task = _history.firstWhere((t) => t.id == id);
    if (task.outputPath != null) {
      try {
        final file = await FileService.fileFromPath(task.outputPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('删除物理文件失败: $e');
      }
    }
    _history.removeWhere((t) => t.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _history.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_history.map((t) => t.toJson()).toList());
    await prefs.setString(_key, json);
  }
}
