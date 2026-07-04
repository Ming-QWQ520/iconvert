/// BatchConvertDialog - 批量转换参数设置弹窗
///
/// 选择统一输出格式和参数后，批量创建转换任务
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:iconvert/models/conversion_task.dart';

class BatchConvertParams {
  final String outputFormat;
  final int quality;
  final int? width;
  final int? height;
  final int? fps;
  final int? loopCount;
  final int? paletteColors;
  final bool keepTransparency;
  final int? backgroundColor;
  // 音频参数
  final int? sampleRate;
  final int? bitDepth;
  final int? audioBitrate;
  final int? channels;
  final bool enable3DSurround;

  const BatchConvertParams({
    required this.outputFormat,
    required this.quality,
    this.width,
    this.height,
    this.fps,
    this.loopCount,
    this.paletteColors,
    this.keepTransparency = true,
    this.backgroundColor,
    this.sampleRate,
    this.bitDepth,
    this.audioBitrate,
    this.channels,
    this.enable3DSurround = false,
  });
}

class BatchConvertDialog extends StatefulWidget {
  final MediaFileType fileType;
  final String defaultOutputFormat;
  final int fileCount;

  const BatchConvertDialog({
    super.key,
    required this.fileType,
    required this.defaultOutputFormat,
    required this.fileCount,
  });

  @override
  State<BatchConvertDialog> createState() => _BatchConvertDialogState();
}

class _BatchConvertDialogState extends State<BatchConvertDialog> {
  late String _outputFormat;
  late double _quality;
  late final TextEditingController _widthCtrl;
  late final TextEditingController _heightCtrl;
  // 视频/动图参数
  late double _fps;
  // 音频参数
  late int _sampleRate;
  late int _bitDepth;
  late int _audioBitrate;
  late int _channels;
  late bool _enable3DSurround;

  @override
  void initState() {
    super.initState();
    _outputFormat = widget.defaultOutputFormat;
    _quality = 80;
    _fps = 0;  // 0=原始帧率
    _widthCtrl = TextEditingController();
    _heightCtrl = TextEditingController();
    _sampleRate = 44100;
    _bitDepth = 16;
    _audioBitrate = 320;
    _channels = 2;
    _enable3DSurround = false;
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Map<String, String> get _imageFormats => const {
    'jpg': 'JPEG', 'png': 'PNG', 'webp': 'WebP',
    'heic': 'HEIC', 'bmp': 'BMP', 'ico': 'ICO',
  };

  Map<String, String> get _videoFormats => const {
    'mp4': 'MP4', 'mov': 'MOV', 'avi': 'AVI', 'wmv': 'WMV',
    'mkv': 'MKV', 'flv': 'FLV', 'mpeg': 'MPEG', 'mpg': 'MPG',
    'webm': 'WebM', 'gif': 'GIF',
  };

  Map<String, String> get _audioFormats => const {
    'mp3': 'MP3', 'aac': 'AAC', 'wma': 'WMA', 'ogg': 'OGG',
    'flac': 'FLAC', 'wav': 'WAV', 'ape': 'APE',
  };

  @override
  Widget build(BuildContext context) {
    Map<String, String> formats;
    switch (widget.fileType) {
      case MediaFileType.image:
        formats = _imageFormats;
        break;
      case MediaFileType.audio:
        formats = _audioFormats;
        break;
      case MediaFileType.video:
        formats = _videoFormats;
        break;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: CupertinoColors.systemBackground,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 标题
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: CupertinoColors.separator, width: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '批量转换 ${widget.fileCount} 个文件',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text('选择统一输出格式和参数', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
                    ],
                  ),
                ),
                // 格式选择
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('输出格式', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: formats.entries.map((entry) {
                          final selected = _outputFormat == entry.key;
                          return GestureDetector(
                            onTap: () => setState(() => _outputFormat = entry.key),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected ? const Color(0xFF007AFF) : CupertinoColors.systemGrey5,
                                borderRadius: BorderRadius.circular(10),
                                border: selected ? null : Border.all(color: CupertinoColors.separator, width: 0.5),
                              ),
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: selected ? CupertinoColors.white : CupertinoColors.systemGrey,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                // 图片参数
                if (widget.fileType == MediaFileType.image) _buildImageParams(),
                // 视频参数
                if (widget.fileType == MediaFileType.video) _buildVideoParams(),
                // 音频参数
                if (widget.fileType == MediaFileType.audio) _buildAudioParams(),
                // 按钮
                Container(
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: CupertinoColors.separator, width: 0.5))),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          child: const Text('取消'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Container(width: 0.5, height: 44, color: CupertinoColors.separator),
                      Expanded(
                        child: CupertinoButton.filled(
                          child: const Text('开始转换'),
                          onPressed: _onConfirm,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageParams() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分辨率
          const Text('分辨率（留空=原始）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _widthCtrl,
                  placeholder: '宽',
                  keyboardType: TextInputType.number,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('×')),
              Expanded(
                child: CupertinoTextField(
                  controller: _heightCtrl,
                  placeholder: '高',
                  keyboardType: TextInputType.number,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 质量
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('图片质量', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(_quality.toInt().toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
            ],
          ),
          CupertinoSlider(value: _quality, min: 1, max: 100, divisions: 99, onChanged: (v) => setState(() => _quality = v)),
        ],
      ),
    );
  }

  Widget _buildVideoParams() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('分辨率（留空=原始）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _widthCtrl,
                  placeholder: '宽',
                  keyboardType: TextInputType.number,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('×')),
              Expanded(
                child: CupertinoTextField(
                  controller: _heightCtrl,
                  placeholder: '高',
                  keyboardType: TextInputType.number,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('视频画质', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(_quality.toInt().toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
            ],
          ),
          CupertinoSlider(value: _quality, min: 1, max: 100, divisions: 99, onChanged: (v) => setState(() => _quality = v)),
          const SizedBox(height: 16),
          // 视频帧率
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('帧率 (FPS, 0=原始)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(_fps.toInt() == 0 ? '原始' : _fps.toInt().toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
            ],
          ),
          CupertinoSlider(value: _fps, min: 0, max: 60, divisions: 60, onChanged: (v) => setState(() => _fps = v)),
        ],
      ),
    );
  }

  Widget _buildAudioParams() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 采样率
          const Text('采样率', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          CupertinoSlidingSegmentedControl<int>(
            groupValue: _sampleRate,
            children: const {
              22050: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('22.05kHz')),
              44100: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('44.1kHz')),
              48000: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('48kHz')),
              96000: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('96kHz')),
            },
            onValueChanged: (v) { if (v != null) setState(() => _sampleRate = v); },
          ),
          const SizedBox(height: 16),
          // 量化位数
          const Text('量化位数', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          CupertinoSlidingSegmentedControl<int>(
            groupValue: _bitDepth,
            children: const {
              16: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('16-bit')),
              24: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('24-bit')),
              32: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('32-bit')),
            },
            onValueChanged: (v) { if (v != null) setState(() => _bitDepth = v); },
          ),
          const SizedBox(height: 16),
          // 比特率
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('比特率', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text('$_audioBitrate kbps', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
            ],
          ),
          CupertinoSlider(
            value: _audioBitrate.toDouble(),
            min: 64, max: 320, divisions: (320 - 64) ~/ 32,
            onChanged: (v) => setState(() => _audioBitrate = v.round()),
          ),
          const SizedBox(height: 16),
          // 声道
          const Text('声道', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          CupertinoSlidingSegmentedControl<int>(
            groupValue: _channels,
            children: const {
              1: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('单声道')),
              2: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('立体声')),
            },
            onValueChanged: (v) { if (v != null) setState(() => _channels = v); },
          ),
          const SizedBox(height: 16),
          // 3D 环绕
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _enable3DSurround
                  ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                  : CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _enable3DSurround ? const Color(0xFF007AFF) : CupertinoColors.separator,
                width: _enable3DSurround ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(CupertinoIcons.waveform_circle, size: 18, color: _enable3DSurround ? const Color(0xFF007AFF) : CupertinoColors.systemGrey),
                        const SizedBox(width: 6),
                        Text('3D 环绕', style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: _enable3DSurround ? const Color(0xFF007AFF) : CupertinoColors.systemGrey,
                        )),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('左右声道循环变大变小，营造空间感', style: TextStyle(fontSize: 11, color: CupertinoColors.systemGrey2)),
                  ],
                ),
                CupertinoSwitch(
                  value: _enable3DSurround,
                  onChanged: (v) => setState(() => _enable3DSurround = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onConfirm() {
    final params = BatchConvertParams(
      outputFormat: _outputFormat,
      quality: _quality.toInt(),
      width: int.tryParse(_widthCtrl.text.trim()),
      height: int.tryParse(_heightCtrl.text.trim()),
      fps: widget.fileType == MediaFileType.video ? (_fps.toInt() == 0 ? null : _fps.toInt()) : null,
      sampleRate: widget.fileType == MediaFileType.audio ? _sampleRate : null,
      bitDepth: widget.fileType == MediaFileType.audio ? _bitDepth : null,
      audioBitrate: widget.fileType == MediaFileType.audio ? _audioBitrate : null,
      channels: widget.fileType == MediaFileType.audio ? _channels : null,
      enable3DSurround: widget.fileType == MediaFileType.audio ? _enable3DSurround : false,
    );
    Navigator.of(context).pop(params);
  }
}
