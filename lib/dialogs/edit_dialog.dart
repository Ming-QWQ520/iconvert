/// EditDialog - 编辑参数弹窗（内嵌实时预览）
///
/// 布局：
/// - 顶部：实时预览区（左右拖动分隔线对比原图与输出效果，自动生成）
/// - 中部：格式选择（网格按钮）
/// - 下部：动态参数（按格式特性显示）
/// - 底部：确认/取消
library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
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
  String? _previewError;
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

  /// 图片输出格式（移除 GIF，因为图片转 GIF 不需要；移除 SVG，因为 FFmpeg 不支持写 SVG）
  Map<String, String> get _imageFormats => const {
    'jpg': 'JPEG', 'png': 'PNG', 'webp': 'WebP',
    'heic': 'HEIC', 'bmp': 'BMP', 'ico': 'ICO',
  };

  /// 视频输出格式（增加 GIF 用于视频转 GIF 动图）
  Map<String, String> get _videoFormats => const {
    'mp4': 'MP4', 'mkv': 'MKV', 'webm': 'WebM',
    'mov': 'MOV', 'avi': 'AVI', 'flv': 'FLV', 'gif': 'GIF',
  };

  /// 生成预览图
  Future<void> _generatePreview() async {
    if (!_isImage) return;  // 视频不生成预览

    setState(() {
      _previewLoading = true;
      _previewError = null;
    });

    try {
      final tempDir = Directory.systemTemp;
      final previewDir = Directory(p.join(tempDir.path, 'iconvert_previews'));
      if (!await previewDir.exists()) {
        await previewDir.create(recursive: true);
      }

      // 用当前参数构建临时 task（限制预览图尺寸避免大文件）
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

      final command = CommandBuilder.build(
        task: previewTask,
        outputPath: previewPath,
      );

      final session = await FFmpegKit.execute(command);
      final code = await session.getReturnCode();

      if (ReturnCode.isSuccess(code) && await File(previewPath).exists()) {
        setState(() {
          _previewPath = previewPath;
          _previewLoading = false;
        });
      } else {
        final logs = await session.getAllLogsAsString() ?? '';
        setState(() {
          _previewError = '预览失败';
          _previewLoading = false;
        });
        debugPrint('预览失败: ${logs.length > 200 ? logs.substring(logs.length - 200) : logs}');
      }
    } catch (e) {
      setState(() {
        _previewError = '预览异常';
        _previewLoading = false;
      });
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
                // 顶部：实时预览区（仅图片）
                if (_isImage) _buildPreviewArea(),

                // 格式选择
                _buildFormatSelector(formats),

                // 动态参数区
                if (_isImage) _buildDynamicImageParams(),
                if (!_isImage) _buildVideoParams(),

                // 底部按钮
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 实时预览区（左右对比）
  Widget _buildPreviewArea() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
      child: Stack(
        children: [
          // 预览内容
          if (_previewLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoActivityIndicator(radius: 16),
                  SizedBox(height: 8),
                  Text('生成预览中...', style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
                ],
              ),
            )
          else if (_previewError != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.exclamationmark_circle, size: 32, color: CupertinoColors.systemGrey),
                  const SizedBox(height: 8),
                  Text(_previewError!, style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
                ],
              ),
            )
          else if (_previewPath != null)
            _buildCompareView()
          else
            const Center(
              child: Text('预览不可用', style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
            ),

          // 右上角刷新按钮
          Positioned(
            top: 8,
            right: 8,
            child: CupertinoButton(
              padding: const EdgeInsets.all(6),
              color: CupertinoColors.systemBackground.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              minSize: 32,
              onPressed: _previewLoading ? null : _generatePreview,
              child: const Icon(
                CupertinoIcons.arrow_clockwise,
                size: 16,
                color: Color(0xFF007AFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 左右对比视图
  /// 原图和输出图都固定在中央（BoxFit.contain + center），
  /// 用 ClipRect 裁剪原图左半部分（分隔线左侧显示原图，右侧显示输出图）
  Widget _buildCompareView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final splitX = width * _splitRatio;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _splitRatio = (details.localPosition.dx / width).clamp(0.05, 0.95);
            });
          },
          child: Stack(
            children: [
              // 底层：输出图（满铺固定，contain + center）
              Positioned.fill(
                child: Image.file(
                  File(_previewPath!),
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('输出图加载失败', style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
                  ),
                ),
              ),
              // 上层：原图（同样满铺固定 contain + center），但用 ClipRect 裁剪只显示分隔线左侧
              Positioned(
                left: 0,
                top: 0,
                width: splitX,
                height: height,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: splitX / width,
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: Image.file(
                        File(widget.task.inputPath),
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('原图加载失败', style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 分隔线
              Positioned(
                left: splitX - 1.5,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: const Color(0xFF007AFF)),
              ),
              // 拖动手柄
              Positioned(
                left: splitX - 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(CupertinoIcons.arrow_swap, color: CupertinoColors.white, size: 16),
                  ),
                ),
              ),
              // 标签
              Positioned(
                top: 8,
                left: 8,
                child: _floatingLabel('原图'),
              ),
              Positioned(
                top: 8,
                right: 50,
                child: _floatingLabel(_outputFormat.toUpperCase()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _floatingLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF007AFF)),
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
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CupertinoColors.systemGrey),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: formats.entries.map((entry) {
              final selected = _outputFormat == entry.key;
              return GestureDetector(
                onTap: () {
                  setState(() => _outputFormat = entry.key);
                  _generatePreview();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF007AFF) : CupertinoColors.systemGrey5,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 13,
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

  Widget _buildSvgScaleSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('缩放倍数', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CupertinoColors.systemGrey)),
              Text('${_svgScale.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
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
          const Text('分辨率（宽×高，留空=原始）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CupertinoColors.systemGrey)),
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
              const Text('图片质量', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CupertinoColors.systemGrey)),
              Text(_quality.toInt().toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
            ],
         ),
          CupertinoSlider(
            value: _quality,
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: (v) => setState(() => _quality = v),
          ),
          FutureBuilder<int>(
            future: _estimateOutputSize(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data! > 0) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('预估输出: ${_formatSize(snapshot.data!)}', style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey2)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('帧率 (FPS)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CupertinoColors.systemGrey)),
              Text(_fps.toInt().toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
            ],
          ),
          CupertinoSlider(value: _fps, min: 1, max: 30, divisions: 29, onChanged: (v) => setState(() => _fps = v)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('循环次数 (0=无限)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CupertinoColors.systemGrey)),
              Text(_loopCount.toInt() == 0 ? '∞' : _loopCount.toInt().toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
            ],
          ),
          CupertinoSlider(value: _loopCount, min: 0, max: 10, divisions: 10, onChanged: (v) => setState(() => _loopCount = v)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('调色板颜色数', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CupertinoColors.systemGrey)),
              Text(_paletteColors.toInt().toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
            ],
          ),
          CupertinoSlider(value: _paletteColors, min: 2, max: 256, divisions: 254, onChanged: (v) => setState(() => _paletteColors = v)),
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
              const Text('保留透明背景', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CupertinoColors.systemGrey)),
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
            const Text('背景填充色', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CupertinoColors.systemGrey)),
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
                    width: 36,
                    height: 36,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('分辨率（宽×高，留空=原始）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CupertinoColors.systemGrey)),
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('视频画质', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CupertinoColors.systemGrey)),
              Text(_quality.toInt().toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
            ],
          ),
          CupertinoSlider(value: _quality, min: 1, max: 100, divisions: 99, onChanged: (v) => setState(() => _quality = v)),
          // GIF 视频参数
          if (_outputFormat == 'gif') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('帧率 (FPS)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CupertinoColors.systemGrey)),
                Text(_fps.toInt().toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
              ],
            ),
            CupertinoSlider(value: _fps, min: 1, max: 30, divisions: 29, onChanged: (v) => setState(() => _fps = v)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('循环 (0=无限)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CupertinoColors.systemGrey)),
                Text(_loopCount.toInt() == 0 ? '∞' : _loopCount.toInt().toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
              ],
            ),
            CupertinoSlider(value: _loopCount, min: 0, max: 10, divisions: 10, onChanged: (v) => setState(() => _loopCount = v)),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: CupertinoColors.separator, width: 0.5)),
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
        _generatePreview();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        case 'gif': formatMultiplier = 0.5; break;
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
