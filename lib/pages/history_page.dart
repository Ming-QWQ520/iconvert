/// HistoryPage - 历史记录页
///
/// 设计（规划 4.11）：
/// - 与主列表布局一致
/// - 卡片显示输出路径和时间
/// - 左滑删除触发液态玻璃确认弹窗
library;

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:iconvert/models/history_model.dart';
import 'package:iconvert/models/conversion_task.dart';
import 'package:iconvert/dialogs/delete_confirm_dialog.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('历史记录'),
      ),
      child: SafeArea(
        child: Consumer<HistoryModel>(
          builder: (context, model, _) {
            if (model.history.isEmpty) {
              return _buildEmpty();
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: model.history.length,
              itemBuilder: (context, index) => _HistoryCard(
                task: model.history[index],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.clock,
            size: 64,
            color: CupertinoColors.systemGrey,
          ),
          SizedBox(height: 16),
          Text(
            '暂无历史记录',
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ConversionTask task;

  const _HistoryCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: CupertinoColors.destructiveRed,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          CupertinoIcons.delete,
          color: CupertinoColors.white,
        ),
      ),
      // 关键：左滑不直接删，先弹液态玻璃确认
      confirmDismiss: (_) async {
        final action = await DeleteConfirmDialog.show(
          context,
          fileName: task.originalName,
        );
        if (action == DeleteAction.removeRecordOnly) {
          await context.read<HistoryModel>().removeRecord(task.id);
          return false;  // 自己已处理
        }
        if (action == DeleteAction.removeBoth) {
          await context.read<HistoryModel>().removeRecordAndFile(task.id);
          return false;
        }
        return false;  // 取消
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 类型图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: task.type == MediaFileType.image
                    ? const Color(0xFF34C759).withOpacity(0.1)
                    : const Color(0xFFFF9500).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                task.type == MediaFileType.image
                    ? CupertinoIcons.photo
                    : CupertinoIcons.film,
                color: task.type == MediaFileType.image
                    ? const Color(0xFF34C759)
                    : const Color(0xFFFF9500),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.originalName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task.outputPath ?? '(未知路径)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(task.completedAt ?? task.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.checkmark_circle_fill,
              color: CupertinoColors.activeGreen,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
