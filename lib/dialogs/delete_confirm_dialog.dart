/// DeleteConfirmDialog - 删除确认弹窗（液态玻璃）
///
/// 设计（规划 4.8）：
/// ┌─────────────────────────┐
/// │        删除文件？        │
/// │       (文件名预览)       │
/// ├─────────────────────────┤
/// │          取消           │
/// ├─────────────────────────┤
/// │      仅删除历史记录      │
/// ├─────────────────────────┤
/// │   删除文件和历史记录 (红) │
/// └─────────────────────────┘
///
/// - 使用 GlassContainer sigma=15
/// - 不能点击背景关闭，只能点取消或返回键
library;

import 'package:flutter/cupertino.dart';
import 'package:iconvert/widgets/glass_container.dart';

enum DeleteAction {
  cancel,
  removeRecordOnly,
  removeBoth,
}

class DeleteConfirmDialog extends StatelessWidget {
  final String fileName;

  const DeleteConfirmDialog({super.key, required this.fileName});

  /// 显示弹窗，返回用户选择的动作（默认 cancel）
  static Future<DeleteAction> show(
    BuildContext context, {
    required String fileName,
  }) async {
    final result = await showCupertinoModalPopup<DeleteAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteConfirmDialog(fileName: fileName),
    );
    return result ?? DeleteAction.cancel;
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      sigma: 15,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              '删除文件？',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // 文件名
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          _separator(),
          _actionTile(
            text: '取消',
            color: const Color(0xFF007AFF),
            onTap: () => Navigator.of(context).pop(DeleteAction.cancel),
          ),
          _separator(),
          _actionTile(
            text: '仅删除历史记录',
            color: const Color(0xFF007AFF),
            onTap: () =>
                Navigator.of(context).pop(DeleteAction.removeRecordOnly),
          ),
          _separator(),
          _actionTile(
            text: '删除文件和历史记录',
            color: CupertinoColors.destructiveRed,
            onTap: () => Navigator.of(context).pop(DeleteAction.removeBoth),
          ),
        ],
      ),
    );
  }

  /// 自定义分隔线（Cupertino 没有 Divider 类）
  Widget _separator() {
    return Container(
      height: 0.5,
      color: CupertinoColors.separator.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _actionTile({
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 14),
      minimumSize: const Size(double.infinity, 0),
      onPressed: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
