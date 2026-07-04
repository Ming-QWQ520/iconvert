/// HistoryPage - 历史记录页
///
/// 功能：
/// - 批量选择删除（左上角全选按钮）
/// - 图片预览缩略图、文件大小、媒体丢失检测
/// - 长按调起原生"打开方式"选择器
/// - 左滑删除、右滑重新转换
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
  final Map<String, bool> _fileExists = {};
  final Map<String, int> _fileSizes = {};
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

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
          try { size = await file.length(); } catch (_) {}
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

  void _enterSelectionMode() {
    setState(() => _selectionMode = true);
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    final history = context.read<HistoryModel>();
    setState(() {
      if (_selectedIds.length == history.history.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.clear();
        for (final task in history.history) {
          _selectedIds.add(task.id);
        }
      }
    });
  }

  Future<void> _deleteSelected() async {
    final history = context.read<HistoryModel>();
    final action = await DeleteConfirmDialog.show(
      context,
      fileName: '${_selectedIds.length} 个文件',
    );
    if (action == DeleteAction.removeRecordOnly) {
      for (final id in _selectedIds) {
        await history.removeRecord(id);
      }
      _exitSelectionMode();
    } else if (action == DeleteAction.removeBoth) {
      for (final id in _selectedIds) {
        await history.removeRecordAndFile(id);
      }
      _exitSelectionMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_selectionMode ? '已选 ${_selectedIds.length} 项' : '历史记录'),
        backgroundColor: CupertinoColors.transparent,
        border: null,
        leading: _selectionMode
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Text('取消'),
                onPressed: _exitSelectionMode,
              )
            : CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Text('全选'),
                onPressed: () {
                  _enterSelectionMode();
                  _toggleSelectAll();
                },
              ),
        trailing: _selectionMode
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text(
                      _selectedIds.length == context.read<HistoryModel>().history.length && _selectedIds.isNotEmpty
                          ? '取消全选'
                          : '全选',
                      style: const TextStyle(color: Color(0xFF007AFF)),
                    ),
                    onPressed: _toggleSelectAll,
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('删除', style: TextStyle(color: CupertinoColors.destructiveRed)),
                    onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                  ),
                ],
              )
            : null,
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
              itemBuilder: (context, index) {
                final task = model.history[index];
                final isSelected = _selectedIds.contains(task.id);
                return _HistoryCard(
                  task: task,
                  fileExists: _fileExists[task.id] ?? true,
                  fileSize: _fileSizes[task.id],
                  selectionMode: _selectionMode,
                  selected: isSelected,
                  onTap: () {
                    if (_selectionMode) {
                      _toggleSelect(task.id);
                    } else {
                      _openPreview(task);
                    }
                  },
                  onLongPress: () {
                    if (!_selectionMode) {
                      _enterSelectionMode();
                      _toggleSelect(task.id);
                    }
                  },
                );
              },
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
    if (task.type == MediaFileType.image) {
      showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => PreviewDialog(task: task),
      );
    } else if (task.type == MediaFileType.audio) {
      showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => AudioPreviewDialog(task: task),
      );
    } else {
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
    await OpenFilex.open(task.outputPath!);
  }
}

/// 历史卡片
class _HistoryCard extends StatelessWidget {
  final ConversionTask task;
  final bool fileExists;
  final int? fileSize;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _HistoryCard({
    required this.task,
    required this.fileExists,
    required this.fileSize,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // 选择模式：不显示 Dismissible，只显示选择框
    if (selectionMode) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                : CupertinoColors.systemBackground.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: const Color(0xFF007AFF), width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              _buildCheckbox(),
              const SizedBox(width: 12),
              _buildThumbnail(),
              const SizedBox(width: 12),
              Expanded(child: _buildInfo()),
              _buildStatusIcon(),
            ],
          ),
        ),
      );
    }

    return Dismissible(
      key: ValueKey(task.id),
      background: _buildSwipeBackground(
        const Color(0xFF007AFF), CupertinoIcons.arrow_clockwise, '重新转换', Alignment.centerLeft,
      ),
      secondaryBackground: _buildSwipeBackground(
        CupertinoColors.destructiveRed, CupertinoIcons.delete, '删除', Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _reConvert(context);
          return false;
        } else {
          final action = await DeleteConfirmDialog.show(context, fileName: task.originalName);
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
              _buildThumbnail(),
              const SizedBox(width: 12),
              Expanded(child: _buildInfo()),
              _buildStatusIcon(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF007AFF) : CupertinoColors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? const Color(0xFF007AFF) : CupertinoColors.systemGrey,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(CupertinoIcons.checkmark, color: CupertinoColors.white, size: 16)
          : null,
    );
  }

  Widget _buildThumbnail() {
    if (!fileExists || task.outputPath == null) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: CupertinoColors.destructiveRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(CupertinoIcons.exclamationmark_circle_fill, color: CupertinoColors.destructiveRed, size: 28),
      );
    }
    // 图片：直接用输出文件作为缩略图
    if (task.type == MediaFileType.image) {
      final file = File(task.outputPath!);
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Image.file(file, fit: BoxFit.cover, cacheWidth: 96, cacheHeight: 96,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          ),
        ),
      );
    }
    // 视频/音频：用图标占位
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    IconData icon;
    switch (task.type) {
      case MediaFileType.image: icon = CupertinoIcons.photo; break;
      case MediaFileType.audio: icon = CupertinoIcons.music_note; break;
      case MediaFileType.video: icon = CupertinoIcons.film; break;
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 24, color: const Color(0xFF007AFF)),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.originalName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            _formatTag(_inputFormat(), isInput: true),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(CupertinoIcons.arrow_right, size: 12, color: CupertinoColors.systemGrey),
            ),
            _formatTag(task.outputFormat.toUpperCase()),
          ],
        ),
        const SizedBox(height: 2),
        if (!fileExists)
          const Text('媒体丢失', style: TextStyle(fontSize: 11, color: CupertinoColors.destructiveRed, fontWeight: FontWeight.w500))
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
              Text('· ${_formatSize(fileSize!)}', style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey2)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStatusIcon() {
    if (!fileExists) {
      return const Icon(CupertinoIcons.exclamationmark_circle_fill, color: CupertinoColors.destructiveRed, size: 24);
    }
    return const Icon(CupertinoIcons.checkmark_circle_fill, color: CupertinoColors.activeGreen, size: 20);
  }

  Widget _buildSwipeBackground(Color color, IconData icon, String label, Alignment alignment) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
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

  String _inputFormat() {
    final dotIndex = task.originalName.lastIndexOf('.');
    if (dotIndex < 0) return '?';
    return task.originalName.substring(dotIndex + 1).toUpperCase();
  }

  Widget _formatTag(String text, {bool isInput = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isInput ? CupertinoColors.systemGrey5 : const Color(0xFF007AFF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
        color: isInput ? CupertinoColors.systemGrey : const Color(0xFF007AFF))),
    );
  }

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
      sampleRate: task.sampleRate,
      bitDepth: task.bitDepth,
      audioBitrate: task.audioBitrate,
      channels: task.channels,
      enable3DSurround: task.enable3DSurround,
      createdAt: DateTime.now(),
    );
    final inputFile = File(task.inputPath);
    if (!await inputFile.exists()) {
      if (context.mounted) {
        showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('无法重新转换'),
            content: const Text('源文件已被删除或移动'),
            actions: [CupertinoDialogAction(child: const Text('好'), onPressed: () => Navigator.of(ctx).pop())],
          ),
        );
      }
      return;
    }
    context.read<ConversionModel>().addTask(newTask);
    if (context.mounted) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          content: Text('已加入转换队列: ${task.originalName}'),
          actions: [CupertinoDialogAction(child: const Text('好'), onPressed: () => Navigator.of(ctx).pop())],
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

/// 自定义手势处理器（避免 Dismissible 手势竞争）
class _CardGestureHandler extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  const _CardGestureHandler({this.onTap, this.onLongPress, required this.child});

  @override
  State<_CardGestureHandler> createState() => _CardGestureHandlerState();
}

class _CardGestureHandlerState extends State<_CardGestureHandler> {
  Offset? _downPosition;
  bool _longPressTriggered = false;
  static const _longPressDuration = Duration(milliseconds: 500);
  static const _moveThreshold = 10.0;

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
        _longPressTriggered = false;
        _startLongPressTimer();
      },
      onPointerMove: (event) {
        if (_downPosition != null) {
          if ((event.position - _downPosition!).distance > _moveThreshold) {
            _downPosition = null;
            _longPressTriggered = true;
          }
        }
      },
      onPointerUp: (event) {
        if (_downPosition != null && !_longPressTriggered) {
          widget.onTap?.call();
        }
        _downPosition = null;
      },
      child: widget.child,
    );
  }
}
