/// VideoPreviewDialog - 视频预览弹窗（缩略图大图）
library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:iconvert/models/conversion_task.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;

class VideoPreviewDialog extends StatefulWidget {
  final ConversionTask task;

  const VideoPreviewDialog({super.key, required this.task});

  @override
  State<VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<VideoPreviewDialog> {
  String? _thumbnailPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      final tempDir = Directory.systemTemp;
      final thumbDir = Directory(p.join(tempDir.path, 'iconvert_thumbs'));
      if (!await thumbDir.exists()) {
        await thumbDir.create(recursive: true);
      }
      final thumbPath = p.join(
        thumbDir.path,
        'video_preview_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // 抽取视频第 1 秒画面
      final cmd = '-ss 1 -i "${widget.task.outputPath}" -frames:v 1 '
          '-vf "scale=720:-2" -q:v 3 "$thumbPath" -y';
      final session = await FFmpegKit.execute(cmd);
      final code = await session.getReturnCode();

      if (ReturnCode.isSuccess(code) && await File(thumbPath).exists()) {
        setState(() {
          _thumbnailPath = thumbPath;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('视频预览'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('完成'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 文件信息
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    widget.task.originalName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.task.paramSummary,
                    style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                  ),
                ],
              ),
            ),
            // 缩略图大图
            Expanded(child: _buildThumbnail()),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(radius: 16),
            SizedBox(height: 12),
            Text('生成缩略图中...', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
          ],
        ),
      );
    }
    if (_thumbnailPath == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.film, size: 64, color: CupertinoColors.systemGrey),
            SizedBox(height: 16),
            Text('无法生成缩略图', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            File(_thumbnailPath!),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('缩略图加载失败', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
            ),
          ),
        ),
      ),
    );
  }
}
