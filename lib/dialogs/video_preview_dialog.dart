/// VideoPreviewDialog - 视频预览弹窗（直接播放）
///
/// 用 video_player + chewie 实现视频内嵌播放
library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:open_filex/open_filex.dart';
import 'package:iconvert/models/conversion_task.dart';

class VideoPreviewDialog extends StatefulWidget {
  final ConversionTask task;

  const VideoPreviewDialog({super.key, required this.task});

  @override
  State<VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<VideoPreviewDialog> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _videoController = VideoPlayerController.file(File(widget.task.outputPath!));
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF007AFF),
          handleColor: const Color(0xFF007AFF),
          backgroundColor: CupertinoColors.systemGrey5,
          bufferedColor: const Color(0xFF007AFF).withValues(alpha: 0.3),
        ),
      );

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = '无法内嵌播放此格式（WebM 等），\n可以用系统播放器打开';
        });
      }
    }
  }

  /// 用系统播放器打开
  Future<void> _openWithSystemPlayer() async {
    await OpenFilex.open(widget.task.outputPath!);
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: CupertinoColors.transparent,
        border: null,
        middle: Text('视频播放', style: TextStyle(color: CupertinoColors.white)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 文件信息
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: CupertinoColors.black,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.task.originalName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CupertinoColors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.task.paramSummary,
                    style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                  ),
                ],
              ),
            ),
            // 视频播放器
            Expanded(
              child: _buildPlayer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(radius: 20, color: CupertinoColors.white),
            SizedBox(height: 16),
            Text('加载视频中...', style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey)),
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
              const Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: CupertinoColors.systemGrey),
              const SizedBox(height: 16),
              Text(
                _errorMsg!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                child: const Text('用系统播放器打开'),
                onPressed: _openWithSystemPlayer,
              ),
            ],
          ),
        ),
      );
    }

    if (_chewieController != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: Chewie(controller: _chewieController!),
        ),
      );
    }

    return const Center(
      child: Text('播放器初始化失败', style: TextStyle(color: CupertinoColors.systemGrey)),
    );
  }
}
