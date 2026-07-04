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
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 1000,
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
          notificationText: '共 $total 个任务',
        );
      }
    } catch (e) {
      debugPrint('启动前台服务失败: $e');
    }
  }

  /// 更新通知文本（显示成功/失败计数）
  static Future<void> updateNotification({
    required int completed,
    required int total,
    required int success,
    required int failed,
    String? currentFileName,
  }) async {
    try {
      String text;
      if (completed >= total) {
        // 全部完成
        text = '完成: $total 个 / 成功 $success / 失败 $failed';
      } else {
        // 进行中
        final progress = '$completed/$total';
        text = currentFileName != null
            ? '正在转换: $currentFileName ($progress) 成功 $success 失败 $failed'
            : '进度: $progress 成功 $success 失败 $failed';
      }
      FlutterForegroundTask.updateService(notificationText: text);
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
}
