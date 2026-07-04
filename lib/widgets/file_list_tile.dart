/// FileListTile - 文件列表项卡片
///
/// 设计：
/// - 圆角 12，半透明背景（无模糊）
/// - 左部 200x200 缩略图（图片用 cacheWidth/cacheHeight）
/// - 右部文件名、格式标签、参数摘要
/// - 尾部状态图标
/// - 点击弹出编辑弹窗
library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:iconvert/models/conversion_model.dart';
import 'package:iconvert/models/conversion_task.dart';

class FileListTile extends StatelessWidget {
  final ConversionTask task;
  final String? thumbnailPath;
  final VoidCallback? onTap;

  const FileListTile({
    super.key,
    required this.task,
    this.thumbnailPath,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 使用 context.select 避免不必要的重建（规划要求 6.8.7）
    final status = context.select<ConversionModel, TaskStatus>(
      (model) => model.tasks.firstWhere((t) => t.id == task.id,
          orElse: () => task).status,
    );
    final progress = context.select<ConversionModel, double>(
      (model) => model.tasks.firstWhere((t) => t.id == task.id,
          orElse: () => task).progress,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          // 半透明静态背景（无模糊）
          color: CupertinoColors.systemBackground.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 缩略图 200x200（用 cacheWidth 优化内存）
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: _buildThumbnail(),
                ),
              ),

              const SizedBox(width: 12),

              // 文件信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.originalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 格式标签
                    Row(
                      children: [
                        _FormatTag(text: _inputFormat(), isInput: true),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            CupertinoIcons.arrow_right,
                            size: 12,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        _FormatTag(text: task.outputFormat.toUpperCase()),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 参数摘要
                    Text(
                      _paramSummary(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),

              // 状态图标 + 进度
              _StatusIndicator(status: status, progress: progress),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (thumbnailPath != null && File(thumbnailPath!).existsSync()) {
      return Image.file(
        File(thumbnailPath!),
        cacheWidth: 200,
        cacheHeight: 200,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: CupertinoColors.systemGrey5,
      child: Icon(
        task.type == MediaFileType.image
            ? CupertinoIcons.photo
            : CupertinoIcons.film,
        size: 32,
        color: CupertinoColors.systemGrey,
      ),
    );
  }

  String _inputFormat() {
    final dotIndex = task.originalName.lastIndexOf('.');
    if (dotIndex < 0) return '?';
    return task.originalName.substring(dotIndex + 1).toUpperCase();
  }

  String _paramSummary() {
    // 使用 ConversionTask 自带的 paramSummary（已支持各种格式特性）
    return task.paramSummary;
  }
}

/// 格式标签
class _FormatTag extends StatelessWidget {
  final String text;
  final bool isInput;

  const _FormatTag({required this.text, this.isInput = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isInput
            ? CupertinoColors.systemGrey5
            : const Color(0xFF007AFF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isInput
              ? CupertinoColors.systemGrey
              : const Color(0xFF007AFF),
        ),
      ),
    );
  }
}

/// 状态指示器
class _StatusIndicator extends StatelessWidget {
  final TaskStatus status;
  final double progress;

  const _StatusIndicator({required this.status, required this.progress});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case TaskStatus.waiting:
        return const Icon(
          CupertinoIcons.clock,
          color: CupertinoColors.systemGrey,
          size: 22,
        );
      case TaskStatus.converting:
        return SizedBox(
          width: 24,
          height: 24,
          child: CupertinoActivityIndicator.partiallyRevealed(
            progress: progress.clamp(0.1, 1.0),
          ),
        );
      case TaskStatus.completed:
        return const Icon(
          CupertinoIcons.checkmark_circle_fill,
          color: CupertinoColors.activeGreen,
          size: 22,
        );
      case TaskStatus.failed:
        return const Icon(
          CupertinoIcons.xmark_circle_fill,
          color: CupertinoColors.destructiveRed,
          size: 22,
        );
      case TaskStatus.canceled:
        return const Icon(
          CupertinoIcons.minus_circle,
          color: CupertinoColors.systemGrey,
          size: 22,
        );
    }
  }
}
