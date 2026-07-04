/// EditDialog - 编辑参数弹窗（动态 BottomSheet）
///
/// 根据目标格式特性动态显示不同选项：
/// - 有损格式（JPEG/WebP/HEIC）：质量滑块 + 预估大小 + 尺寸缩放
/// - 动图格式（GIF）：帧率 + 循环次数 + 调色板颜色数
/// - 透明格式（PNG/WebP/GIF/SVG）：保留透明开关 + 背景色填充
/// - 矢量格式（SVG）：缩放倍数
library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:iconvert/models/conversion_model.dart';
import 'package:iconvert/models/conversion_task.dart';
import 'package:iconvert/dialogs/preview_dialog.dart';

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

  // 动图参数
  late double _fps;
  late double _loopCount;
  late double _paletteColors;

  // 透明参数
  late bool _keepTransparency;
  late int _backgroundColor;

  // SVG 参数
  late double _svgScale;

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
    'heic': 'HEIC', 'bmp': 'BMP', 'gif': 'GIF',
    'svg': 'SVG', 'ico': 'ICO',
  };

  Map<String, String> get _videoFormats => const {
    'mp4': 'MP4', 'mkv': 'MKV', 'webm': 'WebM',
    'mov': 'MOV', 'avi': 'AVI', 'flv': 'FLV',
  };

  @override
  Widget build(BuildContext context) {
    final formats = _isImage ? _imageFormats : _videoFormats;

    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: CupertinoColors.systemBackground.withValues(alpha: 0.95),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 标题区
                _buildHeader(),
                // 格式选择
                _buildFormatSelector(formats),
                // 动态参数区
                if (_isImage) _buildDynamicImageParams(),
                if (!_isImage) _buildVideoParams(),
                // 预览对比按钮（仅图片）
                if (_isImage) _buildPreviewButton(),
                // 按钮区
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.task.originalName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '当前参数: ${widget.task.paramSummary}',
            style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelector(Map<String, String> formats) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '输出格式',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 8),
          // 格式按钮网格（每行 4 个）
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: formats.entries.map((entry) {
              final selected = _outputFormat == entry.key;
              return GestureDetector(
                onTap: () => setState(() => _outputFormat = entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF007AFF)
                        : CupertinoColors.systemGrey5,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? CupertinoColors.white
                          : CupertinoColors.systemGrey,
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

  /// 动态图片参数区：根据格式特性显示不同选项
  Widget _buildDynamicImageParams() {
    // 临时构建一个 task 副本，用于查询特性
    final tempTask = widget.task.copyWith(outputFormat: _outputFormat);
    final traits = tempTask.imageTraits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 矢量格式（SVG）：缩放倍数
        if (traits.contains(ImageFormatTrait.vector))
          _buildSvgScaleSection(),

        // 2. 普通位图：分辨率输入
        if (!traits.contains(ImageFormatTrait.vector))
          _buildResolutionSection(),

        // 3. 有损格式：质量滑块 + 预估大小
        if (traits.contains(ImageFormatTrait.lossy))
          _buildQualitySection(),

        // 4. 动图格式：帧率 + 循环 + 调色板
        if (traits.contains(ImageFormatTrait.animation))
          _buildAnimationSection(),

        // 5. 透明格式：保留透明开关 + 背景色
        if (traits.contains(ImageFormatTrait.transparency))
          _buildTransparencySection(),
      ],
    );
  }

  Widget _buildSvgScaleSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '缩放倍数',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              Text(
                '${_svgScale.toStringAsFixed(1)}x',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF007AFF),
                ),
              ),
            ],
          ),
          CupertinoSlider(
            value: _svgScale,
            min: 0.5,
            max: 4.0,
            divisions: 7,
            onChanged: (v) => setState(() => _svgScale = v),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '分辨率（宽×高，留空=原始）',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.systemGrey,
            ),
          ),
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('×'),
              ),
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
          const SizedBox(height: 4),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '图片质量',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              Text(
                _quality.toInt().toString(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF007AFF),
                ),
              ),
            ],
          ),
          CupertinoSlider(
            value: _quality,
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: (v) => setState(() => _quality = v),
          ),
          // 预估大小（基于源文件大小和质量）
          FutureBuilder<int>(
            future: _estimateOutputSize(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final sizeKb = snapshot.data! ~/ 1024;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '预估输出大小: ${_formatSize(sizeKb)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 帧率
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '帧率 (FPS)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              Text(
                _fps.toInt().toString(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF007AFF),
                ),
              ),
            ],
          ),
          CupertinoSlider(
            value: _fps,
            min: 1,
            max: 30,
            divisions: 29,
            onChanged: (v) => setState(() => _fps = v),
          ),
          // 循环次数
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '循环次数 (0=无限)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              Text(
                _loopCount.toInt() == 0 ? '∞' : _loopCount.toInt().toString(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF007AFF),
                ),
              ),
            ],
          ),
          CupertinoSlider(
            value: _loopCount,
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (v) => setState(() => _loopCount = v),
          ),
          // 调色板颜色数
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '调色板颜色数',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              Text(
                _paletteColors.toInt().toString(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF007AFF),
                ),
              ),
            ],
          ),
          CupertinoSlider(
            value: _paletteColors,
            min: 2,
            max: 256,
            divisions: 254,
            onChanged: (v) => setState(() => _paletteColors = v),
          ),
        ],
      ),
    );
  }

  Widget _buildTransparencySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '保留透明背景',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              CupertinoSwitch(
                value: _keepTransparency,
                onChanged: (v) => setState(() => _keepTransparency = v),
              ),
            ],
          ),
          // 不保留透明时，显示背景色选择
          if (!_keepTransparency) ...[
            const SizedBox(height: 12),
            const Text(
              '背景填充色',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                0xFFFFFFFF,  // 白
                0xFF000000,  // 黑
                0xFFFFEB3B,  // 黄
                0xFF2196F3,  // 蓝
                0xFF4CAF50,  // 绿
                0xFFF44336,  // 红
              ].map((color) {
                final selected = _backgroundColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _backgroundColor = color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF007AFF)
                            : CupertinoColors.separator,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分辨率
          const Text(
            '分辨率（宽×高，留空=原始）',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.systemGrey,
            ),
          ),
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('×'),
              ),
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
          const SizedBox(height: 12),
          // 视频画质
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '视频画质',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              Text(
                _quality.toInt().toString(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF007AFF),
                ),
              ),
            ],
          ),
          CupertinoSlider(
            value: _quality,
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: (v) => setState(() => _quality = v),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(10),
        onPressed: _showPreview,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.eye, size: 18, color: Color(0xFF007AFF)),
            SizedBox(width: 8),
            Text(
              '预览对比',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF007AFF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
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
              child: const Text('确认'),
              onPressed: _onConfirm,
            ),
          ),
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
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey5,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
        ),
      ),
    );
  }

  /// 估算输出文件大小（基于源文件大小和质量）
  Future<int> _estimateOutputSize() async {
    try {
      final file = File(widget.task.inputPath);
      final srcSize = await file.length();
      // 简单估算：质量 100→1.0x，质量 50→0.5x，质量 1→0.1x
      final ratio = (_quality / 100).clamp(0.1, 1.0);
      // 不同格式有不同压缩比
      double formatMultiplier;
      switch (_outputFormat.toLowerCase()) {
        case 'jpg':
        case 'jpeg':
          formatMultiplier = 0.3;  // JPEG 高压缩
          break;
        case 'webp':
          formatMultiplier = 0.25;
          break;
        case 'heic':
        case 'heif':
          formatMultiplier = 0.15;  // HEIC 极高压缩
          break;
        case 'png':
          formatMultiplier = 0.7;  // PNG 无损
          break;
        case 'gif':
          formatMultiplier = 0.5;
          break;
        case 'bmp':
        case 'tiff':
        case 'ico':
          formatMultiplier = 1.5;  // 无压缩，可能更大
          break;
        default:
          formatMultiplier = 0.5;
      }
      return (srcSize * ratio * formatMultiplier).round();
    } catch (e) {
      return 0;
    }
  }

  String _formatSize(int kb) {
    if (kb < 1024) return '$kb KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  void _showPreview() {
    // 用当前选择的参数构建一个临时 task 用于预览
    final previewTask = widget.task.copyWith(
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
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => PreviewDialog(task: previewTask),
    );
  }

  void _onConfirm() {
    final width = int.tryParse(_widthCtrl.text.trim());
    final height = int.tryParse(_heightCtrl.text.trim());

    final updated = widget.task.copyWith(
      outputFormat: _outputFormat,
      width: width,
      height: height,
      quality: _quality.toInt(),
      fps: _fps.toInt(),
      loopCount: _loopCount.toInt(),
      paletteColors: _paletteColors.toInt(),
      keepTransparency: _keepTransparency,
      backgroundColor: _backgroundColor,
      svgScale: _svgScale,
    );

    context.read<ConversionModel>().updateTask(updated);
    Navigator.of(context).pop();
  }
}
