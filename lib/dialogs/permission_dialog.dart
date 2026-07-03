/// PermissionDialog - 权限引导弹窗（液态玻璃）
///
/// 设计（规划 4.9）：
/// - 标题"允许访问存储空间"
/// - 副文案说明用途
/// - 按钮"暂不""继续"
/// - GlassContainer sigma=15
library;

import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:iconvert/widgets/glass_container.dart';

class PermissionDialog extends StatelessWidget {
  const PermissionDialog({super.key});

  /// 检查存储权限是否已授予
  static Future<bool> checkStoragePermission() async {
    // Android 13+ 用 READ_MEDIA_IMAGES / READ_MEDIA_VIDEO
    // Android 10-12 用 READ_EXTERNAL_STORAGE
    // Android 9 及以下用 READ/WRITE_EXTERNAL_STORAGE

    if (await Permission.storage.isGranted) return true;
    if (await Permission.photos.isGranted && await Permission.videos.isGranted) {
      return true;
    }
    return false;
  }

  /// 请求存储权限
  static Future<bool> requestStoragePermission() async {
    // 先尝试新 API（Android 13+）
    final photos = await Permission.photos.request();
    final videos = await Permission.videos.request();
    if (photos.isGranted && videos.isGranted) return true;

    // 降级到 storage（Android 12 及以下）
    final storage = await Permission.storage.request();
    if (storage.isGranted) return true;

    // Android 11+ 所有文件访问
    if (await Permission.manageExternalStorage.isGranted) return true;
    final manage = await Permission.manageExternalStorage.request();
    return manage.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      sigma: 15,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图标
          Container(
            width: 56,
            height: 56,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.folder_badge_plus,
              size: 28,
              color: Color(0xFF007AFF),
            ),
          ),

          // 标题
          const Text(
            '允许访问存储空间',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // 副文案
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'iConvert 需要访问存储空间以读取您选择的文件，'
              '并将转换后的文件保存到指定位置。'
              '所有操作均在本地完成，不会上传任何数据。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.systemGrey,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 按钮区
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: CupertinoColors.systemGrey5,
                  borderRadius: BorderRadius.circular(10),
                  child: const Text(
                    '暂不',
                    style: TextStyle(
                      fontSize: 15,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  borderRadius: BorderRadius.circular(10),
                  child: const Text(
                    '继续',
                    style: TextStyle(fontSize: 15),
                  ),
                  onPressed: () async {
                    final granted = await requestStoragePermission();
                    if (context.mounted) {
                      Navigator.of(context).pop(granted);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
