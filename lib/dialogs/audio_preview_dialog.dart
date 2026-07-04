/// AudioPreviewDialog - 音频预览弹窗（波形 + 播放）
library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:iconvert/models/conversion_task.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;

class AudioPreviewDialog extends StatefulWidget {
  final ConversionTask task;

  const AudioPreviewDialog({super.key, required this.task});

  @override
  State<AudioPreviewDialog> createState() => _AudioPreviewDialogState();
}

class _AudioPreviewDialogState extends State<AudioPreviewDialog> {
  List<double> _waveform = [];
  bool _loading = true;
  bool _playing = false;
  double _playProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _generateWaveform();
  }

  /// 用 FFmpeg 解码音频为 PCM，计算波形
  Future<void> _generateWaveform() async {
    try {
      final tempDir = Directory.systemTemp;
      final waveformFile = File(p.join(
        tempDir.path,
        'waveform_${DateTime.now().millisecondsSinceEpoch}.pcm',
      ));

      // 用 FFmpeg 转为 8kHz 单声道 16-bit PCM（降采样减少数据量）
      final cmd = '-i "${widget.task.outputPath}" -ar 8000 -ac 1 -f s16le -y "${waveformFile.path}"';
      final session = await FFmpegKit.execute(cmd);
      final code = await session.getReturnCode();

      if (!ReturnCode.isSuccess(code)) {
        setState(() => _loading = false);
        return;
      }

      // 读取 PCM 数据，每 200 字节取一个峰值
      final bytes = await waveformFile.readAsBytes();
      final samples = <double>[];
      const blockSize = 200;
      for (int i = 0; i < bytes.length - 1; i += blockSize * 2) {
        int maxVal = 0;
        for (int j = 0; j < blockSize * 2 && i + j + 1 < bytes.length; j += 2) {
          // 16-bit signed little endian
          final sample = (bytes[i + j + 1] << 8) | bytes[i + j];
          final signed = sample > 32767 ? sample - 65536 : sample;
          if (signed.abs() > maxVal) maxVal = signed.abs();
        }
        samples.add(maxVal / 32768.0);
      }

      await waveformFile.delete();

      setState(() {
        _waveform = samples;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('音频预览'),
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
            // 波形显示
            Expanded(child: _buildWaveform()),
            // 播放控制
            _buildPlaybackControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveform() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(radius: 16),
            SizedBox(height: 12),
            Text('生成波形中...', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
          ],
        ),
      );
    }
    if (_waveform.isEmpty) {
      return const Center(
        child: Text('无法生成波形', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CustomPaint(
          painter: WaveformPainter(
            waveform: _waveform,
            progress: _playProgress,
            color: const Color(0xFF007AFF),
            backgroundColor: CupertinoColors.systemGrey4,
          ),
          child: const SizedBox(
            width: double.infinity,
            height: 120,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: CupertinoColors.separator, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF007AFF),
            borderRadius: BorderRadius.circular(30),
            child: Icon(
              _playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
              color: CupertinoColors.white,
              size: 24,
            ),
            onPressed: () {
              // 简化：仅切换状态（实际播放需要 audio_player 插件）
              setState(() => _playing = !_playing);
            },
          ),
        ],
      ),
    );
  }
}

/// 波形绘制器
class WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final double progress;
  final Color color;
  final Color backgroundColor;

  const WaveformPainter({
    required this.waveform,
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final barWidth = size.width / waveform.length;
    final midY = size.height / 2;

    for (int i = 0; i < waveform.length; i++) {
      final x = i * barWidth;
      final amp = waveform[i] * (size.height / 2);
      // 已播放部分用主色，未播放用背景色
      paint.color = (i / waveform.length) <= progress ? color : backgroundColor;
      canvas.drawLine(
        Offset(x, midY - amp),
        Offset(x, midY + amp),
        paint,
      );
    }

    // 播放进度指示线
    if (progress > 0) {
      final progressX = size.width * progress;
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(progressX, 0),
        Offset(progressX, size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.waveform != waveform;
  }
}
