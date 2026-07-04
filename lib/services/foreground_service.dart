/// ForegroundService - 前台服务封装
///
/// 使用 flutter_foreground_task 实现后台转码时的通知栏进度显示。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'iconvert_conversion',
        channelName: 'iConvert 转换进度',
        channelDescription: '显示当前文件转换进度',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        showWhen: false,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 500,
        autoRunOnBoot: false,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start({required int total}) async {
    try {
      if (!await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.startService(
          notificationTitle: 'iConvert 正在转换',
          notificationText: '共 $total 个任务，准备中...',
        );
      }
    } catch (e) {
      debugPrint('启动前台服务失败: $e');
    }
  }

  /// 更新通知：显示当前任务进度（带进度条）
  /// [currentProgress] 当前任务进度 0.0-1.0
  /// [completedCount] 已完成任务数
  /// [total] 总任务数
  /// [currentFileName] 当前任务文件名
  /// [successCount] 成功数
  /// [failedCount] 失败数
  static Future<void> updateProgress({
    required double currentProgress,
    required int completedCount,
    required int total,
    required String currentFileName,
    required int successCount,
    required int failedCount,
  }) async {
    try {
      final remaining = total - completedCount - 1;  // 当前任务剩余 = 总数 - 已完成 - 1（当前在跑）
      final percent = (currentProgress * 100).toInt();
      final text = '$currentFileName $percent% · 剩余 $remaining 个';
      FlutterForegroundTask.updateService(
        notificationText: text,
        notificationProgress: notificationProgress(percent, total * 100, (completedCount * 100 + percent)),
      );
    } catch (e) {
      debugPrint('更新通知进度失败: $e');
    }
  }

  /// 单个任务完成时更新通知
  static Future<void> updateTaskDone({
    required int completedCount,
    required int total,
    required String fileName,
    required int successCount,
    required int failedCount,
  }) async {
    try {
      final remaining = total - completedCount;
      String text;
      if (remaining > 0) {
        text = '已完成: $fileName · 剩余 $remaining 个 · 成功 $successCount 失败 $failedCount';
      } else {
        text = '全部完成 · 共 $total 个 · 成功 $successCount 失败 $failedCount';
      }
      FlutterForegroundTask.updateService(
        notificationText: text,
        notificationProgress: notificationProgress(100, 100, 100),
      );
    } catch (e) {
      debugPrint('更新通知失败: $e');
    }
  }

  /// 完成总结通知
  static Future<void> showSummary({
    required int total,
    required int successCount,
    required int failedCount,
  }) async {
    try {
      FlutterForegroundTask.updateService(
        notificationText: '全部完成 · 共 $total 个 · 成功 $successCount 失败 $failedCount',
        notificationProgress: null,
      );
    } catch (e) {
      debugPrint('更新通知失败: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('停止前台服务失败: $e');
    }
  }

  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }

  /// 构造通知进度对象
  static NotificationProgress? notificationProgress(int percent, int max, int current) {
    // 如果 percent >= 100 则不显示进度条
    if (percent >= 100) return null;
    return NotificationProgress(
      max: max,
      current: current,
      indeterminate: false,
    );
  }
}
