/// ForegroundService - 前台服务封装
///
/// 使用 flutter_foreground_task 实现后台转码时的通知栏进度显示。
/// 注意：调用方需用 WithForegroundTask widget 包裹页面。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundService {
  static bool _initialized = false;

  /// 初始化（在 main() 中调用）
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

  /// 启动前台服务
  static Future<void> start({required int total}) async {
    try {
      // isRunningService 在 flutter_foreground_task 6.x 是 Future<bool> 属性，不是方法
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

  /// 更新通知文本
  static Future<void> updateNotification({
    required int completed,
    required int total,
    String? currentFileName,
  }) async {
    try {
      final text = currentFileName != null
          ? '$currentFileName ($completed/$total)'
          : '进度: $completed/$total';
      FlutterForegroundTask.updateService(
        notificationText: text,
      );
    } catch (e) {
      debugPrint('更新通知失败: $e');
    }
  }

  /// 停止前台服务
  static Future<void> stop() async {
    try {
      await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('停止前台服务失败: $e');
    }
  }

  /// 是否在运行
  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }
}
