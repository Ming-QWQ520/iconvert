/// PathSettingDialog - 输出路径设置弹窗（液态玻璃）
library;

import 'package:flutter/cupertino.dart';
import 'package:iconvert/widgets/glass_container.dart';
import 'package:iconvert/services/file_service.dart';
import 'package:iconvert/services/storage_service.dart';

class PathSettingDialog extends StatefulWidget {
  const PathSettingDialog({super.key});

  @override
  State<PathSettingDialog> createState() => _PathSettingDialogState();
}

class _PathSettingDialogState extends State<PathSettingDialog> {
  late TextEditingController _pathCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pathCtrl = TextEditingController(text: StorageService.defaultOutputDir);
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  Future<void> _browse() async {
    final path = await FileService.pickDirectory();
    if (path != null) {
      setState(() => _pathCtrl.text = path);
    }
  }

  Future<void> _confirm() async {
    final path = _pathCtrl.text.trim();
    if (path.isEmpty) {
      _showToast('请输入或选择路径');
      return;
    }

    setState(() => _saving = true);
    try {
      await StorageService.setOutputDir(path);
      // 确保目录存在
      await FileService.generateOutputPath(
        outputDir: path,
        originalName: 'test.tmp',
        outputFormat: 'tmp',
      );
      // 先关闭路径弹窗
      if (mounted) {
        Navigator.of(context).pop();
        // 然后再显示成功提示（用 root navigator，避免被路径弹窗拦截）
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          _showToast('已保存到: $path');
        }
      }
    } catch (e) {
      if (mounted) _showToast('保存失败: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showToast(String msg) {
    // 用 rootNavigator 显示，避免被路径弹窗的 navigator 干扰
    final overlay = CupertinoApp.rootOverlayKey.currentContext ?? context;
    showCupertinoDialog<void>(
      context: overlay,
      barrierDismissible: true,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      sigma: 15,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 图标
          Container(
            width: 56,
            height: 56,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.folder_fill_badge_plus,
              size: 28,
              color: Color(0xFF007AFF),
            ),
          ),

          // 标题
          const Text(
            '选择保存位置',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '转换后的文件将保存到此目录',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.systemGrey,
            ),
          ),

          const SizedBox(height: 20),

          // 路径输入框 + 浏览按钮
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _pathCtrl,
                  placeholder: '输出路径',
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: CupertinoColors.systemGrey5,
                borderRadius: BorderRadius.circular(8),
                onPressed: _browse,
                child: const Text(
                  '浏览',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          // 默认路径提示
          const Text(
            '默认: /storage/emulated/0/Download/iConvert',
            style: TextStyle(
              fontSize: 11,
              color: CupertinoColors.systemGrey2,
            ),
          ),

          const SizedBox(height: 20),

          // 按钮区
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: CupertinoColors.systemGrey5,
                  borderRadius: BorderRadius.circular(10),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 15,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: _saving ? null : _confirm,
                  child: _saving
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : const Text('确认', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
