/// PreviewDialog - 图片预览弹窗
///
/// 直接显示转换后的图片，支持双指缩放和拖动
library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:iconvert/models/conversion_task.dart';

class PreviewDialog extends StatefulWidget {
  final ConversionTask task;

  const PreviewDialog({super.key, required this.task});

  @override
  State<PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<PreviewDialog> {
  // 缩放和拖动状态
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _position = Offset.zero;
  Offset _previousPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: CupertinoColors.transparent,
        border: null,
        middle: Text('图片预览', style: TextStyle(color: CupertinoColors.white)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 文件信息
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: CupertinoColors.black,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.task.originalName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.task.paramSummary,
                    style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey),
                  ),
                ],
              ),
            ),
            // 图片显示区（支持双指缩放和拖动）
            Expanded(child: _buildImageViewer()),
            // 底部工具栏
            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageViewer() {
    final path = widget.task.outputPath;
    if (path == null) {
      return const Center(
        child: Text('无输出文件', style: TextStyle(color: CupertinoColors.systemGrey)),
      );
    }
    final file = File(path);
    if (!file.existsSync()) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.exclamationmark_circle_fill, size: 48, color: CupertinoColors.destructiveRed),
            SizedBox(height: 12),
            Text('文件不存在', style: TextStyle(color: CupertinoColors.systemGrey)),
          ],
        ),
      );
    }

    return GestureDetector(
      onScaleStart: (details) {
        _previousScale = _scale;
        _previousPosition = details.focalPoint;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_previousScale * details.scale).clamp(0.5, 5.0);
          if (_scale > 1.0) {
            _position += details.focalPoint - _previousPosition;
            _previousPosition = details.focalPoint;
          } else {
            _position = Offset.zero;
          }
        });
      },
      onScaleEnd: (details) {
        if (_scale < 1.0) {
          setState(() {
            _scale = 1.0;
            _position = Offset.zero;
          });
        }
      },
      // 双击恢复
      onDoubleTap: () {
        setState(() {
          _scale = 1.0;
          _position = Offset.zero;
        });
      },
      child: Center(
        child: Transform.translate(
          offset: _position,
          child: Transform.scale(
            scale: _scale,
            child: Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Text('图片加载失败', style: TextStyle(color: CupertinoColors.systemGrey)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: CupertinoColors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 缩小
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            color: CupertinoColors.systemGrey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            minSize: 36,
            onPressed: () {
              setState(() {
                _scale = (_scale - 0.2).clamp(0.5, 5.0);
                if (_scale <= 1.0) _position = Offset.zero;
              });
            },
            child: const Icon(CupertinoIcons.minus, color: CupertinoColors.white, size: 18),
          ),
          // 缩放比例
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(_scale * 100).toInt()}%',
              style: const TextStyle(fontSize: 13, color: CupertinoColors.white, fontWeight: FontWeight.w500),
            ),
          ),
          // 放大
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            color: CupertinoColors.systemGrey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            minSize: 36,
            onPressed: () {
              setState(() {
                _scale = (_scale + 0.2).clamp(0.5, 5.0);
              });
            },
            child: const Icon(CupertinoIcons.plus, color: CupertinoColors.white, size: 18),
          ),
          // 重置
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            color: CupertinoColors.systemGrey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            minSize: 36,
            onPressed: () {
              setState(() {
                _scale = 1.0;
                _position = Offset.zero;
              });
            },
            child: const Icon(CupertinoIcons.arrow_counterclockwise, color: CupertinoColors.white, size: 18),
          ),
        ],
      ),
    );
  }
}
