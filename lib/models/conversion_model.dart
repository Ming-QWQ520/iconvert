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

  /// 启动全部转换（串行执行）
  /// onTaskCompleted: 任务完成后的回调（已加入历史记录）
  /// onTaskAutoRemoved: 任务从列表自动移除后的回调（用于刷新 UI）
  Future<void> startAll({
    required String outputDir,
    required Function(ConversionTask completed) onTaskCompleted,
    Function(ConversionTask task, double progress)? onProgress,
    Function(ConversionTask failed)? onTaskFailed,
  }) async {
    if (_isConverting) return;
    _isConverting = true;
    _cancelRequested = false;
    notifyListeners();

    try {
      // 复制一份任务 ID 列表，因为转换过程中 _tasks 会被修改
      final taskIds = _tasks
          .where((t) => t.status != TaskStatus.completed)
          .map((t) => t.id)
          .toList();

      for (final taskId in taskIds) {
        if (_cancelRequested) break;

        // 查找当前任务（列表可能已变化）
        final taskIdx = _tasks.indexWhere((t) => t.id == taskId);
        if (taskIdx < 0) continue;  // 已被移除
        final task = _tasks[taskIdx];
        if (task.status == TaskStatus.completed) continue;

        // 标记为转换中
        updateTask(task.copyWith(
          status: TaskStatus.converting,
          progress: 0.0,
          errorMessage: null,
        ));

        try {
          final outputPath = await CommandBuilder.execute(
            task: _tasks[taskIdx],
            outputDir: outputDir,
            onProgress: (progress) {
              final current = _tasks.indexWhere((t) => t.id == taskId);
              if (current < 0) return;
              if ((progress - _tasks[current].progress).abs() >= 0.05 ||
                  progress >= 1.0) {
                updateTask(_tasks[current].copyWith(
                  status: TaskStatus.converting,
                  progress: progress,
                ));
                // 通知外部（用于通知栏进度更新）
                if (onProgress != null) {
                  onProgress(_tasks[current], progress);
                }
              }
            },
          );

          final completed = _tasks[taskIdx].copyWith(
            status: TaskStatus.completed,
            progress: 1.0,
            outputPath: outputPath,
            completedAt: DateTime.now(),
          );

          // 先回调（加入历史记录）
          onTaskCompleted(completed);

          // 短暂延迟让用户看到"已完成"状态，然后自动从列表移除
          await Future.delayed(const Duration(milliseconds: 800));
          // 自动移除（只删记录，不删文件）
          _tasks.removeWhere((t) => t.id == taskId);
          notifyListeners();
        } catch (e) {
          final current = _tasks.indexWhere((t) => t.id == taskId);
          if (current >= 0) {
            final failedTask = _tasks[current].copyWith(
              status: TaskStatus.failed,
              errorMessage: e.toString(),
              completedAt: DateTime.now(),
            );
            updateTask(failedTask);
            // 回调通知失败
            if (onTaskFailed != null) {
              onTaskFailed(failedTask);
            }
            // 失败任务也自动移除（避免列表堆积）
            await Future.delayed(const Duration(seconds: 2));
            _tasks.removeWhere((t) => t.id == taskId);
            notifyListeners();
          }
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
