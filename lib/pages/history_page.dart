/// HistoryPage - 历史记录页
///
/// 功能：
/// - 图片预览缩略图（输出文件）
/// - 文件大小显示
/// - 媒体丢失检测（红色感叹号图标）
/// - 点击图片 → 打开预览对比
/// - 长按卡片 → 原生"打开方式"选择器
/// - 左滑 → 删除（液态玻璃确认弹窗）
/// - 右滑 → 重新转换（加入转换队列）
library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:iconvert/models/history_model.dart';
import 'package:iconvert/models/conversion_model.dart';
import 'package:iconvert/models/conversion_task.dart';
import 'package:iconvert/dialogs/delete_confirm_dialog.dart';
import 'package:iconvert/dialogs/preview_dialog.dart';
import 'package:iconvert/dialogs/audio_preview_dialog.dart';
import 'package:iconvert/dialogs/video_preview_dialog.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // 缓存文件存在状态和大小（避免每次 build 都检查）
  final Map<String, bool> _fileExists = {};
  final Map<String, int> _fileSizes = {};

  @override
  void initState() {
    super.initState();
    _checkFiles();
  }

  Future<void> _checkFiles() async {
    final history = context.read<HistoryModel>();
    for (final task in history.history) {
      if (task.outputPath != null) {
        final file = File(task.outputPath!);
        final exists = await file.exists();
        int? size;
        if (exists) {
          try {
            size = await file.length();
          } catch (e) {
            size = null;
          }
        }
        if (mounted) {
          setState(() {
            _fileExists[task.id] = exists;
            if (size != null) _fileSizes[task.id] = size;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('历史记录')),
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
                fileExists: _fileExists[model.history[index].id] ?? true,
                fileSize: _fileSizes[model.history[index].id],
                onTap: () => _openPreview(model.history[index]),
                onLongPress: () => _openWith(model.history[index]),
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
          Icon(CupertinoIcons.clock, size: 64, color: CupertinoColors.systemGrey),
          SizedBox(height: 16),
          Text('暂无历史记录', style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey)),
        ],
      ),
    );
  }

  void _openPreview(ConversionTask task) {
    final exists = _fileExists[task.id] ?? false;
    if (!exists) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('媒体丢失'),
          content: const Text('输出文件已被删除或移动，无法预览'),
          actions: [
            CupertinoDialogAction(
              child: const Text('好'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
      return;
    }
    // 根据媒体类型选择预览方式
    if (task.type == MediaFileType.image) {
      // 图片用 PreviewDialog 对比预览
      showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => PreviewDialog(task: task),
      );
    } else if (task.type == MediaFileType.audio) {
      // 音频用波形预览弹窗
      showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => AudioPreviewDialog(task: task),
      );
    } else {
      // 视频用缩略图大图预览
      showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => VideoPreviewDialog(task: task),
      );
    }
  }

  Future<void> _openWith(ConversionTask task) async {
    final exists = _fileExists[task.id] ?? false;
    if (!exists || task.outputPath == null) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('媒体丢失'),
          content: const Text('输出文件已被删除或移动'),
          actions: [
            CupertinoDialogAction(
              child: const Text('好'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
      return;
    }
    // 用 open_filex 打开文件，系统会弹出"打开方式"选择器
    // open_filex 在 Android 上会触发 ACTION_VIEW Intent
    // 如果系统有多个应用可打开，会自动弹出选择器
    final result = await OpenFilex.open(task.outputPath!);
    if (result.type != ResultType.done) {
      if (mounted) {
        showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            content: Text('无法打开文件: ${result.message}'),
            actions: [
              CupertinoDialogAction(
                child: const Text('好'),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      }
    }
  }
}

/// 历史卡片
class _HistoryCard extends StatelessWidget {
  final ConversionTask task;
  final bool fileExists;
  final int? fileSize;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _HistoryCard({
    required this.task,
    required this.fileExists,
    required this.fileSize,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(task.id),
      // 手指向右滑（startToEnd）：重新转换 → 蓝色背景靠左
      background: _buildSwipeBackground(
        const Color(0xFF007AFF),
        CupertinoIcons.arrow_clockwise,
        '重新转换',
        Alignment.centerLeft,
      ),
      // 手指向左滑（endToStart）：删除 → 红色背景靠右
      secondaryBackground: _buildSwipeBackground(
        CupertinoColors.destructiveRed,
        CupertinoIcons.delete,
        '删除',
        Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // 手指向右滑 → 重新转换
          await _reConvert(context);
          return false;
        } else {
          // 手指向左滑 → 删除确认
          final action = await DeleteConfirmDialog.show(
            context,
            fileName: task.originalName,
          );
          if (action == DeleteAction.removeRecordOnly) {
            await context.read<HistoryModel>().removeRecord(task.id);
            return false;
          }
          if (action == DeleteAction.removeBoth) {
            await context.read<HistoryModel>().removeRecordAndFile(task.id);
            return false;
          }
          return false;
        }
      },
      child: _CardGestureHandler(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // 缩略图（手势由父 GestureDetector 统一处理）
              _buildThumbnail(),
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
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    // 格式转换标识：原格式 → 新格式
                    Row(
                      children: [
                        _formatTag(_inputFormat(task), isInput: true),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(CupertinoIcons.arrow_right, size: 12, color: CupertinoColors.systemGrey),
                        ),
                        _formatTag(task.outputFormat.toUpperCase()),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (!fileExists)
                      const Text(
                        '媒体丢失',
                        style: TextStyle(fontSize: 11, color: CupertinoColors.destructiveRed, fontWeight: FontWeight.w500),
                      )
                    else if (task.outputPath != null)
                      Text(
                        task.outputPath!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _formatTime(task.completedAt ?? task.createdAt),
                          style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey2),
                        ),
                        if (fileSize != null && fileExists) ...[
                          const SizedBox(width: 8),
                          Text(
                            '· ${_formatSize(fileSize!)}',
                            style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey2),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 状态图标
              if (!fileExists)
                const Icon(CupertinoIcons.exclamationmark_circle_fill, color: CupertinoColors.destructiveRed, size: 24)
              else
                const Icon(CupertinoIcons.checkmark_circle_fill, color: CupertinoColors.activeGreen, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (!fileExists || task.outputPath == null) {
      // 媒体丢失：圆形红色感叹号
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: CupertinoColors.destructiveRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          CupertinoIcons.exclamationmark_circle_fill,
          color: CupertinoColors.destructiveRed,
          size: 28,
        ),
      );
    }
    // 文件存在：显示缩略图（带预览提示图标）
    final file = File(task.outputPath!);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Image.file(
              file,
              fit: BoxFit.cover,
              cacheWidth: 96,
              cacheHeight: 96,
              errorBuilder: (_, __, ___) => Container(
                color: CupertinoColors.systemGrey5,
                child: const Icon(CupertinoIcons.photo, size: 24, color: CupertinoColors.systemGrey),
              ),
            ),
          ),
        ),
        // 右下角预览图标（提示可点击预览）
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                bottomRight: Radius.circular(10),
              ),
            ),
            child: const Icon(
              CupertinoIcons.eye_fill,
              size: 10,
              color: CupertinoColors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeBackground(Color color, IconData icon, String label, Alignment alignment) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: CupertinoColors.white, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: CupertinoColors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  /// 获取输入文件格式
  String _inputFormat(ConversionTask task) {
    final dotIndex = task.originalName.lastIndexOf('.');
    if (dotIndex < 0) return '?';
    return task.originalName.substring(dotIndex + 1).toUpperCase();
  }

  /// 格式标签
  Widget _formatTag(String text, {bool isInput = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isInput
            ? CupertinoColors.systemGrey5
            : const Color(0xFF007AFF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isInput ? CupertinoColors.systemGrey : const Color(0xFF007AFF),
        ),
      ),
    );
  }

  /// 重新转换：加入转换队列
  Future<void> _reConvert(BuildContext context) async {
    final newTask = ConversionTask(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}_${task.originalName.hashCode.abs()}',
      inputPath: task.inputPath,
      originalName: task.originalName,
      type: task.type,
      outputFormat: task.outputFormat,
      width: task.width,
      height: task.height,
      quality: task.quality,
      fps: task.fps,
      loopCount: task.loopCount,
      paletteColors: task.paletteColors,
      keepTransparency: task.keepTransparency,
      backgroundColor: task.backgroundColor,
      svgScale: task.svgScale,
      createdAt: DateTime.now(),
    );

    // 检查源文件是否存在
    final inputFile = File(task.inputPath);
    if (!await inputFile.exists()) {
      if (context.mounted) {
        showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('无法重新转换'),
            content: const Text('源文件已被删除或移动'),
            actions: [
              CupertinoDialogAction(
                child: const Text('好'),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 加入转换队列（缩略图由 home_page 监听新任务自动生成）
    context.read<ConversionModel>().addTask(newTask);

    // 提示
    if (context.mounted) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          content: Text('已加入转换队列: ${task.originalName}'),
          actions: [
            CupertinoDialogAction(
              child: const Text('好'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
    }
  }

  String _formatTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}

/// 自定义手势处理器
/// 用 Listener + 计时器实现点击和长按，避免与 Dismissible 的手势竞争
class _CardGestureHandler extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  const _CardGestureHandler({
    this.onTap,
    this.onLongPress,
    required this.child,
  });

  @override
  State<_CardGestureHandler> createState() => _CardGestureHandlerState();
}

class _CardGestureHandlerState extends State<_CardGestureHandler> {
  Offset? _downPosition;
  DateTime? _downTime;
  bool _longPressTriggered = false;
  static const _longPressDuration = Duration(milliseconds: 500);
  static const _longPressMoveThreshold = 10.0;

  void _startLongPressTimer() {
    Future.delayed(_longPressDuration, () {
      if (_downPosition != null && !_longPressTriggered && mounted) {
        _longPressTriggered = true;
        widget.onLongPress?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _downPosition = event.position;
        _downTime = DateTime.now();
        _longPressTriggered = false;
        _startLongPressTimer();
      },
      onPointerMove: (event) {
        if (_downPosition != null) {
          final distance = (event.position - _downPosition!).distance;
          if (distance > _longPressMoveThreshold) {
            // 手指移动超过阈值，取消长按
            _downPosition = null;
            _longPressTriggered = true; // 阻止长按触发
          }
        }
      },
      onPointerUp: (event) {
        if (_downPosition != null && !_longPressTriggered) {
          // 没触发长按，执行点击
          widget.onTap?.call();
        }
        _downPosition = null;
      },
      child: widget.child,
    );
  }
}
