/// ConversionModel - 转换任务状态管理
library;

import 'package:flutter/foundation.dart';
import 'package:iconvert/models/conversion_task.dart';
import 'package:iconvert/services/command_builder.dart';

class ConversionModel extends ChangeNotifier {
  final List<ConversionTask> _tasks = [];
  bool _isConverting = false;
  bool _cancelRequested = false;

  List<ConversionTask> get tasks => List.unmodifiable(_tasks);
  bool get isConverting => _isConverting;

  int get pendingCount =>
      _tasks.where((t) => t.status == TaskStatus.waiting).length;

  int get completedCount =>
      _tasks.where((t) => t.status == TaskStatus.completed).length;

  double get overallProgress {
    if (_tasks.isEmpty) return 0.0;
    final sum = _tasks.fold<double>(
      0.0,
      (acc, t) => acc + (t.status == TaskStatus.completed ? 1.0 : t.progress),
    );
    return sum / _tasks.length;
  }

  void addTask(ConversionTask task) {
    _tasks.add(task);
    notifyListeners();
  }

  void addAll(List<ConversionTask> tasks) {
    _tasks.addAll(tasks);
    notifyListeners();
  }

  void updateTask(ConversionTask task) {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx >= 0) {
      _tasks[idx] = task;
      notifyListeners();
    }
  }

  void removeTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void clearAll() {
    _tasks.clear();
    _isConverting = false;
    _cancelRequested = false;
    notifyListeners();
  }

  void clearCompleted() {
    _tasks.removeWhere((t) =>
        t.status == TaskStatus.completed || t.status == TaskStatus.failed);
    notifyListeners();
  }

  Future<void> startAll({
    required String outputDir,
    required Function(ConversionTask completed) onTaskCompleted,
  }) async {
    if (_isConverting) return;
    _isConverting = true;
    _cancelRequested = false;
    notifyListeners();

    try {
      for (int i = 0; i < _tasks.length; i++) {
        if (_cancelRequested) break;

        final task = _tasks[i];
        if (task.status == TaskStatus.completed) continue;

        updateTask(task.copyWith(
          status: TaskStatus.converting,
          progress: 0.0,
          errorMessage: null,
        ));

        try {
          final outputPath = await CommandBuilder.execute(
            task: _tasks[i],
            outputDir: outputDir,
            onProgress: (progress) {
              if ((progress - _tasks[i].progress).abs() >= 0.05 ||
                  progress >= 1.0) {
                updateTask(_tasks[i].copyWith(
                  status: TaskStatus.converting,
                  progress: progress,
                ));
              }
            },
          );

          final completed = _tasks[i].copyWith(
            status: TaskStatus.completed,
            progress: 1.0,
            outputPath: outputPath,
            completedAt: DateTime.now(),
          );
          updateTask(completed);
          onTaskCompleted(completed);
        } catch (e) {
          updateTask(_tasks[i].copyWith(
            status: TaskStatus.failed,
            errorMessage: e.toString(),
            completedAt: DateTime.now(),
          ));
        }
      }
    } finally {
      _isConverting = false;
      notifyListeners();
    }
  }

  void cancelConversion() {
    _cancelRequested = true;
    CommandBuilder.cancel();
  }
}
