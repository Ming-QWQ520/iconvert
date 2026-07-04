/// PreviewDialog - 预览对比弹窗
///
/// 左右滑动对比原图与输出效果：
/// - 左半屏：原图
/// - 右半屏：按当前参数实时转换后的预览（异步生成）
/// - 中间分隔线可拖动
library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:iconvert/models/conversion_task.dart';
import 'package:iconvert/services/command_builder.dart';
import 'package:iconvert/services/file_service.dart';
import 'package:path/path.dart' as p;

class PreviewDialog extends StatefulWidget {
  final ConversionTask task;

  const PreviewDialog({super.key, required this.task});

  @override
  State<PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<PreviewDialog> {
  double _splitRatio = 0.5;  // 分隔线位置（0.0=全原图，1.0=全输出）
  String? _previewPath;
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _generatePreview();
  }

  /// 生成预览图（用当前参数实际跑一次 FFmpeg，输出到临时目录）
  Future<void> _generatePreview() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final tempDir = Directory.systemTemp;
      final previewDir = Directory(p.join(tempDir.path, 'iconvert_previews'));
      if (!await previewDir.exists()) {
        await previewDir.create(recursive: true);
      }

      // 限制预览图尺寸（避免大文件转换慢）
      final previewTask = widget.task.copyWith(
        width: widget.task.width != null && widget.task.width! > 1080 ? 1080 : widget.task.width,
        height: widget.task.height != null && widget.task.height! > 1080 ? 1080 : widget.task.height,
      );

      final previewPath = p.join(
        previewDir.path,
        'preview_${DateTime.now().millisecondsSinceEpoch}.${widget.task.outputFormat}',
      );

      // 构建命令（直接用 CommandBuilder 的 build 静态方法）
      final command = CommandBuilder.build(
        task: previewTask,
        outputPath: previewPath,
      );

      debugPrint('预览命令: ffmpeg $command');
      final session = await FFmpegKit.execute(command);
      final code = await session.getReturnCode();

      if (ReturnCode.isSuccess(code) && await File(previewPath).exists()) {
        setState(() {
          _previewPath = previewPath;
          _loading = false;
        });
      } else {
        final logs = await session.getAllLogsAsString() ?? '';
        setState(() {
          _errorMsg = '预览生成失败: ${logs.length > 100 ? logs.substring(logs.length - 100) : logs}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = '预览生成异常: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('预览对比'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('完成'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 提示信息
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF2F2F7),
              child: const Row(
                children: [
                  Icon(CupertinoIcons.info, size: 14, color: CupertinoColors.systemGrey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '左右拖动分隔线对比原图与输出效果',
                      style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                    ),
                  ),
                ],
              ),
            ),

            // 对比区
            Expanded(child: _buildCompareArea()),

            // 参数摘要
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: CupertinoColors.separator, width: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _labelChip('原图', CupertinoColors.systemGrey),
                      const SizedBox(width: 12),
                      _labelChip(
                        '输出: ${widget.task.outputFormat.toUpperCase()}',
                        const Color(0xFF007AFF),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.task.paramSummary,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _labelChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCompareArea() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(radius: 16),
            SizedBox(height: 16),
            Text(
              '正在生成预览...',
              style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
            ),
          ],
        ),
      );
    }

    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 48,
                color: CupertinoColors.destructiveRed,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMsg!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                child: const Text('重试'),
                onPressed: _generatePreview,
              ),
            ],
          ),
        ),
      );
    }

    // 左右对比布局
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final splitX = width * _splitRatio;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _splitRatio = (details.localPosition.dx / width).clamp(0.05, 0.95);
            });
          },
          child: Stack(
            children: [
              // 底层：输出图（右侧）
              Positioned.fill(
                child: _previewPath != null
                    ? Image.file(
                        File(_previewPath!),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _placeholder('输出图加载失败'),
                      )
                    : _placeholder('无预览'),
              ),

              // 上层：原图（左侧，用 ClipRect 裁剪）
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: splitX,
                child: ClipRect(
                  child: Image.file(
                    File(widget.task.inputPath),
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    errorBuilder: (_, __, ___) => _placeholder('原图加载失败'),
                  ),
                ),
              ),

              // 分隔线 + 拖动手柄
              Positioned(
                left: splitX - 1.5,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  color: const Color(0xFF007AFF),
                ),
              ),
              Positioned(
                left: splitX - 18,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.arrow_swap,
                      color: CupertinoColors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),

              // 左右标签
              Positioned(
                top: 12,
                left: 12,
                child: _floatingLabel('原图', CupertinoColors.systemGrey),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _floatingLabel(
                  '输出 ${widget.task.outputFormat.toUpperCase()}',
                  const Color(0xFF007AFF),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _floatingLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _placeholder(String msg) {
    return Container(
      color: CupertinoColors.systemGrey6,
      child: Center(
        child: Text(
          msg,
          style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
        ),
      ),
    );
  }
}
