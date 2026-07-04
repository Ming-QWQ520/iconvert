/// RemoveFromQueueDialog - 从队列移除确认弹窗（液态玻璃风格）
library;

import 'dart:ui';
import 'package:flutter/cupertino.dart';

class RemoveFromQueueDialog extends StatelessWidget {
  final String fileName;

  const RemoveFromQueueDialog({super.key, required this.fileName});

  static Future<bool> show(BuildContext context, {required String fileName}) async {
    final result = await showCupertinoModalPopup<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RemoveFromQueueDialog(fileName: fileName),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: CupertinoColors.separator.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 图标
                Container(
                  width: 56,
                  height: 56,
                  margin: const EdgeInsets.only(bottom: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: CupertinoColors.destructiveRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.delete,
                    size: 28,
                    color: CupertinoColors.destructiveRed,
                  ),
                ),
                // 标题
                const Text(
                  '移除队列',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                // 文件名
                Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
                ),
                const SizedBox(height: 4),
                const Text(
                  '此操作仅移除队列中的任务，不影响源文件',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: CupertinoColors.systemGrey2),
                ),
                const SizedBox(height: 24),
                // 按钮
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: CupertinoColors.systemGrey5,
                        borderRadius: BorderRadius.circular(10),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('取消', style: TextStyle(fontSize: 15, color: CupertinoColors.systemGrey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: CupertinoColors.destructiveRed,
                        borderRadius: BorderRadius.circular(10),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('移除', style: TextStyle(fontSize: 15, color: CupertinoColors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
