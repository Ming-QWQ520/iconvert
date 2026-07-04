/// EditDialog - 全屏编辑弹窗
///
/// 设计：
/// - 全屏弹窗（覆盖整个屏幕，包括状态栏区域）
/// - 状态栏透明，与页面合并
/// - 顶部：原图与输出效果对比预览（占大部分屏幕）
/// - 中部：格式选择 + 动态参数
/// - 底部：确认/取消按钮
library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:iconvert/models/conversion_model.dart';
import 'package:iconvert/models/conversion_task.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:iconvert/services/command_builder.dart';
import 'package:path/path.dart' as p;

class EditDialog extends StatefulWidget {
  final ConversionTask task;

  const EditDialog({super.key, required this.task});

  @override
  State<EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<EditDialog> {
  late String _outputFormat;
  late final TextEditingController _widthCtrl;
  late final TextEditingController _heightCtrl;
  late double _quality;
  late double _fps;
  late double _loopCount;
  late double _paletteColors;
  late bool _keepTransparency;
  late int _backgroundColor;
  late double _svgScale;

  // 预览状态
  String? _previewPath;
  bool _previewLoading = false;
  double _splitRatio = 0.5;

  @override
  void initState() {
    super.initState();
    _outputFormat = widget.task.outputFormat;
    _widthCtrl = TextEditingController(text: widget.task.width?.toString() ?? '');
    _heightCtrl = TextEditingController(text: widget.task.height?.toString() ?? '');
    _quality = widget.task.quality.toDouble();
    _fps = (widget.task.fps ?? 10).toDouble();
    _loopCount = (widget.task.loopCount ?? 0).toDouble();
    _paletteColors = (widget.task.paletteColors ?? 256).toDouble();
    _keepTransparency = widget.task.keepTransparency;
    _backgroundColor = widget.task.backgroundColor ?? 0xFFFFFFFF;
    _svgScale = widget.task.svgScale ?? 1.0;

    // 自动生成预览
    WidgetsBinding.instance.addPostFrameCallback((_) => _generatePreview());
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  bool get _isImage => widget.task.type == MediaFileType.image;

  Map<String, String> get _imageFormats => const {
    'jpg': 'JPEG', 'png': 'PNG', 'webp': 'WebP',
    'heic': 'HEIC', 'bmp': 'BMP', 'ico': 'ICO',
  };

  Map<String, String> get _videoFormats => const {
    'mp4': 'MP4', 'mkv': 'MKV', 'webm': 'WebM',
    'mov': 'MOV', 'avi': 'AVI', 'flv': 'FLV', 'gif': 'GIF',
  };

  Future<void> _generatePreview() async {
    if (!_isImage) return;
    setState(() => _previewLoading = true);

    try {
      final tempDir = Directory.systemTemp;
      final previewDir = Directory(p.join(tempDir.path, 'iconvert_previews'));
      if (!await previewDir.exists()) {
        await previewDir.create(recursive: true);
      }

      final previewTask = _buildCurrentTask().copyWith(
        width: _buildCurrentTask().width != null && _buildCurrentTask().width! > 1080
            ? 1080
            : _buildCurrentTask().width,
        height: _buildCurrentTask().height != null && _buildCurrentTask().height! > 1080
            ? 1080
            : _buildCurrentTask().height,
      );

      final previewPath = p.join(
        previewDir.path,
        'preview_${DateTime.now().millisecondsSinceEpoch}.${_outputFormat}',
      );

      final command = CommandBuilder.build(task: previewTask, outputPath: previewPath);
      final session = await FFmpegKit.execute(command);
      final code = await session.getReturnCode();

      if (ReturnCode.isSuccess(code) && await File(previewPath).exists()) {
        setState(() {
          _previewPath = previewPath;
          _previewLoading = false;
        });
      } else {
        setState(() => _previewLoading = false);
      }
    } catch (e) {
      setState(() => _previewLoading = false);
    }
  }

  ConversionTask _buildCurrentTask() {
    return widget.task.copyWith(
      outputFormat: _outputFormat,
      width: int.tryParse(_widthCtrl.text.trim()),
      height: int.tryParse(_heightCtrl.text.trim()),
      quality: _quality.toInt(),
      fps: _fps.toInt(),
      loopCount: _loopCount.toInt(),
      paletteColors: _paletteColors.toInt(),
      keepTransparency: _keepTransparency,
      backgroundColor: _backgroundColor,
      svgScale: _svgScale,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 全屏弹窗，状态栏透明
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: CupertinoColors.transparent,
      ),
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemBackground,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: CupertinoColors.systemBackground.withValues(alpha: 0.9),
          middle: const Text('编辑参数'),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Text('取消'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          trailing: CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: const Text('确认', style: TextStyle(fontSize: 14)),
            onPressed: _onConfirm,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // 1. 顶部预览对比（大尺寸）
              if (_isImage) _buildPreviewSection(),

              // 2. 格式选择
              _buildFormatSection(),

              // 3. 动态参数
              if (_isImage) _buildDynamicImageParams(),
              if (!_isImage) _buildVideoParams(),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部预览区（大尺寸，左右对比）
  Widget _buildPreviewSection() {
    return Container(
      height: 320,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (_previewLoading)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoActivityIndicator(radius: 20),
                    SizedBox(height: 12),
                    Text('生成预览中...', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
                  ],
                ),
              )
            else if (_previewPath != null)
              _buildSimplePreview()
            else
              const Center(
                child: Text('预览不可用', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
              ),

            // 刷新按钮
            Positioned(
              top: 12,
              right: 12,
              child: CupertinoButton(
                padding: const EdgeInsets.all(8),
                color: CupertinoColors.systemBackground.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                minSize: 36,
                onPressed: _previewLoading ? null : _generatePreview,
                child: const Icon(CupertinoIcons.arrow_clockwise, size: 18, color: Color(0xFF007AFF)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 简单预览（直接显示转换后的图片，不对比原图）
  Widget _buildSimplePreview() {
    return Positioned.fill(
      child: Image.file(
        File(_previewPath!),
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('预览图加载失败', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
        ),
      ),
    );
  }

  Widget _floatingLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF007AFF)),
      ),
    );
  }

  Widget _buildFormatSection() {
    final formats = _isImage ? _imageFormats : _videoFormats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                onTap: () {
                  setState(() => _outputFormat = entry.key);
                  _generatePreview();
                },
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
    );
  }

  Widget _buildDynamicImageParams() {
    final tempTask = widget.task.copyWith(outputFormat: _outputFormat);
    final traits = tempTask.imageTraits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (traits.contains(ImageFormatTrait.vector))
          _buildSvgScaleSection(),
        if (!traits.contains(ImageFormatTrait.vector))
          _buildResolutionSection(),
        if (traits.contains(ImageFormatTrait.lossy))
          _buildQualitySection(),
        if (traits.contains(ImageFormatTrait.animation))
          _buildAnimationSection(),
        if (traits.contains(ImageFormatTrait.transparency))
          _buildTransparencySection(),
      ],
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.separator.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSvgScaleSection() {
    return _buildSection(
      title: '缩放倍数',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('倍数', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
              Text('${_svgScale.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
            ],
          ),
          CupertinoSlider(value: _svgScale, min: 0.5, max: 4.0, divisions: 7, onChanged: (v) => setState(() => _svgScale = v)),
        ],
      ),
    );
  }

  Widget _buildResolutionSection() {
    return _buildSection(
      title: '分辨率',
      child: Column(
        children: [
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
          const SizedBox(height: 8),
          Row(
            children: [
              _quickSizeChip('720p', 1280, 720),
              const SizedBox(width: 8),
              _quickSizeChip('1080p', 1920, 1080),
              const SizedBox(width: 8),
              _quickSizeChip('清空', null, null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualitySection() {
    return _buildSection(
      title: '图片质量',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('质量', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
              Text(_quality.toInt().toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
            ],
          ),
          CupertinoSlider(value: _quality, min: 1, max: 100, divisions: 99, onChanged: (v) => setState(() => _quality = v)),
          FutureBuilder<int>(
            future: _estimateOutputSize(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data! > 0) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('预估输出: ${_formatSize(snapshot.data!)}', style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey2)),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnimationSection() {
    return _buildSection(
      title: '动图参数',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('帧率 (FPS)', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
              Text(_fps.toInt().toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
            ],
          ),
          CupertinoSlider(value: _fps, min: 1, max: 30, divisions: 29, onChanged: (v) => setState(() => _fps = v)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('循环 (0=无限)', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
              Text(_loopCount.toInt() == 0 ? '∞' : _loopCount.toInt().toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
            ],
          ),
          CupertinoSlider(value: _loopCount, min: 0, max: 10, divisions: 10, onChanged: (v) => setState(() => _loopCount = v)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('调色板颜色数', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
              Text(_paletteColors.toInt().toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
            ],
          ),
          CupertinoSlider(value: _paletteColors, min: 2, max: 256, divisions: 254, onChanged: (v) => setState(() => _paletteColors = v)),
        ],
      ),
    );
  }

  Widget _buildTransparencySection() {
    return _buildSection(
      title: '透明度',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('保留透明背景', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
              CupertinoSwitch(
                value: _keepTransparency,
                onChanged: (v) {
                  setState(() => _keepTransparency = v);
                  _generatePreview();
                },
              ),
            ],
          ),
          if (!_keepTransparency) ...[
            const SizedBox(height: 12),
            const Text('背景填充色', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [0xFFFFFFFF, 0xFF000000, 0xFFFFEB3B, 0xFF2196F3, 0xFF4CAF50, 0xFFF44336].map((color) {
                final selected = _backgroundColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() => _backgroundColor = color);
                    _generatePreview();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? const Color(0xFF007AFF) : CupertinoColors.separator,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoParams() {
    return _buildSection(
      title: '视频参数',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('画质', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
              Text(_quality.toInt().toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
            ],
          ),
          CupertinoSlider(value: _quality, min: 1, max: 100, divisions: 99, onChanged: (v) => setState(() => _quality = v)),
          if (_outputFormat == 'gif') ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('帧率 (FPS)', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
                Text(_fps.toInt().toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
              ],
            ),
            CupertinoSlider(value: _fps, min: 1, max: 30, divisions: 29, onChanged: (v) => setState(() => _fps = v)),
          ],
        ],
      ),
    );
  }

  Widget _quickSizeChip(String label, int? width, int? height) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _widthCtrl.text = width?.toString() ?? '';
          _heightCtrl.text = height?.toString() ?? '';
        });
        _generatePreview();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey5,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
      ),
    );
  }

  Future<int> _estimateOutputSize() async {
    try {
      final file = File(widget.task.inputPath);
      final srcSize = await file.length();
      final ratio = (_quality / 100).clamp(0.1, 1.0);
      double formatMultiplier;
      switch (_outputFormat.toLowerCase()) {
        case 'jpg': case 'jpeg': formatMultiplier = 0.3; break;
        case 'webp': formatMultiplier = 0.25; break;
        case 'heic': case 'heif': formatMultiplier = 0.15; break;
        case 'png': formatMultiplier = 0.7; break;
        case 'bmp': case 'ico': formatMultiplier = 1.5; break;
        default: formatMultiplier = 0.5;
      }
      return (srcSize * ratio * formatMultiplier).round();
    } catch (e) {
      return 0;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  void _onConfirm() {
    final updated = _buildCurrentTask();
    context.read<ConversionModel>().updateTask(updated);
    Navigator.of(context).pop();
  }
}
