/// SettingsPage - 设置页
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:iconvert/services/storage_service.dart';
import 'package:iconvert/dialogs/path_setting_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _outputDir = StorageService.defaultOutputDir;

  @override
  void initState() {
    super.initState();
    _loadOutputDir();
  }

  Future<void> _loadOutputDir() async {
    final dir = await StorageService.getOutputDir();
    if (mounted) setState(() => _outputDir = dir);
  }

  Future<void> _editPath() async {
    await showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PathSettingDialog(),
    );
    await _loadOutputDir();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('设置')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 24),
          children: [
            // 通用设置组
            CupertinoFormSection.insetGrouped(
              header: const Text('通用'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('输出路径'),
                  subtitle: Text(
                    _outputDir,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _editPath,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 关于
            CupertinoFormSection.insetGrouped(
              header: const Text('关于'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('应用版本'),
                  additionalInfo: const Text('1.0.0'),
                ),
                CupertinoListTile.notched(
                  title: const Text('Flutter SDK'),
                  additionalInfo: const Text('3.44.1'),
                ),
                CupertinoListTile.notched(
                  title: const Text('转换引擎'),
                  additionalInfo: const Text('FFmpeg (LGPL)'),
                ),
                CupertinoListTile.notched(
                  title: const Text('开发者'),
                  additionalInfo: const Text('明 (Ming)'),
                ),
                CupertinoListTile.notched(
                  title: const Text('GitHub 仓库'),
                  additionalInfo: const Text('Ming-QWQ520'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () {
                    // 直接显示 GitHub URL 弹窗
                    _showGithubDialog();
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 说明卡片
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'iConvert · 全格式转换器',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• 支持 JPG/PNG/WebP/BMP/TIFF/GIF 等图片格式\n'
                    '• 支持 MP4/MKV/MOV/AVI/WebM/FLV/WMV/3GP 等视频格式\n'
                    '• 批量转换，后台队列执行\n'
                    '• 硬件编码优先，自动软件降级\n'
                    '• 所有处理均在本地完成，不上传任何数据',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 版权信息
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(12),
              child: const Column(
                children: [
                  Text(
                    'Made by 明 (Ming)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'github.com/Ming-QWQ520/iconvert',
                    style: TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGithubDialog() {
    const url = 'https://github.com/Ming-QWQ520/iconvert';
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('GitHub 仓库'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              const Text(
                url,
                style: TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(8),
                minSize: 0,
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: url));
                  // 复制成功提示（用 Scaffold 的方式不合适，直接关闭弹窗）
                  Navigator.of(ctx).pop();
                  _showToast('已复制到剪贴板');
                },
                child: const Text(
                  '复制链接',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
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
}
