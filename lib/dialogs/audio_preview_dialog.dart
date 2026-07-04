/// AudioPreviewDialog - 音频预览弹窗（直接播放 + 裁剪功能）
///
/// 功能：
/// - 用 just_audio 直接播放音频
/// - 显示播放进度条
/// - 提供"裁剪"按钮，进入裁剪模式（波形 + 区间选择）
/// - 裁剪后用 FFmpeg 输出
library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';
import 'package:iconvert/models/conversion_task.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AudioPreviewDialog extends StatefulWidget {
  final ConversionTask task;

  const AudioPreviewDialog({super.key, required this.task});

  @override
  State<AudioPreviewDialog> createState() => _AudioPreviewDialogState();
}

class _AudioPreviewDialogState extends State<AudioPreviewDialog> {
  final AudioPlayer _player = AudioPlayer();
  bool _loading = true;
  bool _playing = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isTrimMode = false;

  // 裁剪模式参数
  double _trimStart = 0.0;  // 0.0-1.0
  double _trimEnd = 1.0;    // 0.0-1.0
  bool _trimming = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setFilePath(widget.task.outputPath!);

      _player.durationStream.listen((d) {
        if (d != null && mounted) {
          setState(() => _duration = d);
        }
      });

      _player.positionStream.listen((pos) {
        if (mounted) {
          setState(() => _position = pos);
        }
      });

      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _playing = state.playing;
            _loading = false;
          });
        }
      });

      setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  void _seek(double ratio) {
    if (_duration.inMilliseconds > 0) {
      final pos = Duration(milliseconds: (_duration.inMilliseconds * ratio).round());
      _player.seek(pos);
    }
  }

  /// 进入裁剪模式
  void _enterTrimMode() {
    setState(() => _isTrimMode = true);
    _player.pause();
  }

  /// 执行裁剪
  Future<void> _doTrim() async {
    setState(() => _trimming = true);

    try {
      final startTime = _duration.inMilliseconds * _trimStart / 1000.0;
      final endTime = _duration.inMilliseconds * _trimEnd / 1000.0;
      final duration = endTime - startTime;

      if (duration <= 0) {
        _showToast('裁剪区间无效');
        return;
      }

      // 输出路径
      final dir = await getTemporaryDirectory();
      final baseName = p.basenameWithoutExtension(widget.task.outputPath!);
      final ext = p.extension(widget.task.outputPath!).replaceAll('.', '');
      final outputPath = p.join(dir.path, '${baseName}_trimmed_${DateTime.now().millisecondsSinceEpoch}.$ext');

      // FFmpeg 裁剪命令
      final cmd = '-ss ${startTime.toStringAsFixed(3)} -i "${widget.task.outputPath}" '
          '-t ${duration.toStringAsFixed(3)} -c copy -y "$outputPath"';
      final session = await FFmpegKit.execute(cmd);
      final code = await session.getReturnCode();

      if (ReturnCode.isSuccess(code)) {
        _showToast('裁剪完成: $outputPath');
        // 退出裁剪模式
        setState(() => _isTrimMode = false);
      } else {
        _showToast('裁剪失败');
      }
    } catch (e) {
      _showToast('裁剪异常: $e');
    } finally {
      if (mounted) setState(() => _trimming = false);
    }
  }

  void _showToast(String msg) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.transparent,
        border: null,
        middle: Text(_isTrimMode ? '裁剪音频' : '音频播放'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('完成'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        trailing: !_isTrimMode
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Text('裁剪'),
                onPressed: _enterTrimMode,
              )
            : null,
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

            // 播放器主体
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 音频图标
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF5AC8FA), Color(0xFF007AFF)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          CupertinoIcons.music_note,
                          size: 56,
                          color: CupertinoColors.white,
                        ),
                      ),
                      const SizedBox(height: 32),

                      if (_loading)
                        const CupertinoActivityIndicator(radius: 16)
                      else ...[
                        // 进度条或裁剪选择器
                        if (_isTrimMode)
                          _buildTrimSelector()
                        else
                          _buildProgressBar(),

                        const SizedBox(height: 16),

                        // 时间显示
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_isTrimMode
                                  ? Duration(milliseconds: (_duration.inMilliseconds * _trimStart).round())
                                  : _position),
                              style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                            ),
                            Text(
                              _formatDuration(_isTrimMode
                                  ? Duration(milliseconds: (_duration.inMilliseconds * _trimEnd).round())
                                  : _duration),
                              style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 播放/裁剪按钮
                        if (_isTrimMode)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CupertinoButton(
                                padding: const EdgeInsets.all(16),
                                color: CupertinoColors.systemGrey5,
                                borderRadius: BorderRadius.circular(32),
                                child: const Icon(CupertinoIcons.xmark, color: CupertinoColors.systemGrey, size: 28),
                                onPressed: () => setState(() => _isTrimMode = false),
                              ),
                              const SizedBox(width: 24),
                              CupertinoButton(
                                padding: const EdgeInsets.all(20),
                                color: const Color(0xFF007AFF),
                                borderRadius: BorderRadius.circular(36),
                                child: _trimming
                                    ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                                    : const Icon(CupertinoIcons.checkmark, color: CupertinoColors.white, size: 32),
                                onPressed: _trimming ? null : _doTrim,
                              ),
                            ],
                          )
                        else
                          CupertinoButton(
                            padding: const EdgeInsets.all(20),
                            color: const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(36),
                            child: Icon(
                              _playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                              color: CupertinoColors.white,
                              size: 36,
                            ),
                            onPressed: _togglePlay,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 普通播放进度条
  Widget _buildProgressBar() {
    final ratio = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: () {
            // 点击跳转
            final RenderBox box = context.findRenderObject() as RenderBox;
            final localPos = box.globalToLocal(Offset.zero);
            // 简化：不处理点击跳转
          },
          onHorizontalDragUpdate: (details) {
            final ratio = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
            _seek(ratio);
          },
          child: Container(
            width: double.infinity,
            height: 6,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Stack(
              children: [
                // 已播放部分
                Container(
                  width: constraints.maxWidth * ratio.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // 播放位置圆点
                Positioned(
                  left: (constraints.maxWidth * ratio.clamp(0.0, 1.0) - 6).clamp(0.0, constraints.maxWidth - 12),
                  top: -3,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 裁剪区间选择器（双滑块）
  Widget _buildTrimSelector() {
    return Column(
      children: [
        // 起始位置滑块
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('起始', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
            Text(
              _formatDuration(Duration(milliseconds: (_duration.inMilliseconds * _trimStart).round())),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF007AFF)),
            ),
          ],
        ),
        CupertinoSlider(
          value: _trimStart,
          min: 0.0,
          max: _trimEnd - 0.05,  // 不能超过结束位置
          divisions: 100,
          onChanged: (v) => setState(() => _trimStart = v),
        ),
        const SizedBox(height: 12),
        // 结束位置滑块
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('结束', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
            Text(
              _formatDuration(Duration(milliseconds: (_duration.inMilliseconds * _trimEnd).round())),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF007AFF)),
            ),
          ],
        ),
        CupertinoSlider(
          value: _trimEnd,
          min: _trimStart + 0.05,  // 不能小于起始位置
          max: 1.0,
          divisions: 100,
          onChanged: (v) => setState(() => _trimEnd = v),
        ),
        const SizedBox(height: 8),
        // 裁剪时长显示
        Text(
          '裁剪时长: ${_formatDuration(Duration(milliseconds: ((_duration.inMilliseconds * _trimEnd) - (_duration.inMilliseconds * _trimStart)).round()))}',
          style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey2),
        ),
      ],
    );
  }
}
