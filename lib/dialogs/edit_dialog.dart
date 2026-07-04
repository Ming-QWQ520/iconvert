/// EditDialog - 编辑参数弹窗
///
/// 设计：
/// - showCupertinoModalPopup 触发
/// - 普通半透明容器（不是液态玻璃）
/// - 圆角 14，背景色 systemBackground.withOpacity(0.9)
/// - 内部：格式选择 CupertinoSlidingSegmentedControl，宽高输入，清晰度 CupertinoSlider
/// - 底部 CupertinoButton.filled 确认
library;

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:iconvert/models/conversion_model.dart';
import 'package:iconvert/models/conversion_task.dart';

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

  @override
  void initState() {
    super.initState();
    _outputFormat = widget.task.outputFormat;
    _widthCtrl = TextEditingController(
      text: widget.task.width?.toString() ?? '',
    );
    _heightCtrl = TextEditingController(
      text: widget.task.height?.toString() ?? '',
    );
    _quality = widget.task.quality.toDouble();
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isImage = widget.task.type == MediaFileType.image;
    final formats = isImage
        ? const {'jpg': 'JPG', 'png': 'PNG', 'webp': 'WebP', 'bmp': 'BMP', 'tiff': 'TIFF'}
        : const {'mp4': 'MP4', 'mkv': 'MKV', 'webm': 'WebM', 'mov': 'MOV', 'avi': 'AVI', 'flv': 'FLV'};

    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: CupertinoColors.systemBackground.withOpacity(0.9),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 标题
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.separator,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.task.originalName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '设置转换参数',
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                ),

                // 格式选择
                Padding(
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
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoSlidingSegmentedControl<String>(
                          groupValue: _outputFormat,
                          children: {
                            for (final entry in formats.entries)
                              entry.key: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                child: Text(entry.value),
                              ),
                          },
                          onValueChanged: (value) {
                            if (value != null) {
                              setState(() => _outputFormat = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // 分辨率
                Padding(
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
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
                ),

                // 清晰度滑块
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isImage ? '图片清晰度' : '视频画质',
                            style: const TextStyle(
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
                ),

                // 按钮区
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: CupertinoColors.separator,
                        width: 0.5,
                      ),
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
                      Container(
                        width: 0.5,
                        height: 44,
                        color: CupertinoColors.separator,
                      ),
                      Expanded(
                        child: CupertinoButton.filled(
                          child: const Text('确认'),
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

  void _onConfirm() {
    final width = int.tryParse(_widthCtrl.text.trim());
    final height = int.tryParse(_heightCtrl.text.trim());

    final updated = widget.task.copyWith(
      outputFormat: _outputFormat,
      width: width,
      height: height,
      quality: _quality.toInt(),
    );

    context.read<ConversionModel>().updateTask(updated);
    Navigator.of(context).pop();
  }
}
