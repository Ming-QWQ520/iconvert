/// SettingsPage - 设置页
///
/// 顶部说明卡片用液态玻璃质感，标题改为 "iConvert - 格式转换器"
/// GitHub 仓库点击 → 液态玻璃确认弹窗 → 跳转
/// 开发者行增加头像图标（Ming256x256.png）
library;

import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
import 'package:iconvert/services/storage_service.dart';
import 'package:iconvert/services/file_service.dart';
import 'package:iconvert/dialogs/path_setting_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _outputDir = StorageService.defaultOutputDir;
  FilePickerType _pickerType = FilePickerType.gallery;
  bool _mtManagerInstalled = false;
  bool _liquidGlass = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final dir = await StorageService.getOutputDir();
    final pickerType = await StorageService.getFilePickerType();
    final mtInstalled = await FileService.isMTManagerInstalled();
    final liquidGlass = await StorageService.isLiquidGlassEnabled();
    if (mounted) {
      setState(() {
        _outputDir = dir;
        _pickerType = pickerType;
        _mtManagerInstalled = mtInstalled;
        _liquidGlass = liquidGlass;
      });
    }
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

  /// 切换液态玻璃开关
  Future<void> _toggleLiquidGlass(bool value) async {
    if (value) {
      // 开启前提示性能警告
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('开启液态玻璃'),
          content: const Text('全 UI 使用液态玻璃效果可能影响性能，请谨慎考虑。'),
          actions: [
            CupertinoDialogAction(
              child: const Text('还是算了'),
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            CupertinoDialogAction(
              child: const Text('冲!'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await StorageService.setLiquidGlassEnabled(value);
    setState(() => _liquidGlass = value);
  }

  /// 清除缓存
  Future<void> _clearCache() async {
    // 清理临时文件
    await FileService.cleanupTempFiles();

    if (mounted) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          content: const Text('缓存已清除'),
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

  Future<void> _changePickerType(FilePickerType type) async {
    if (type == FilePickerType.mtManager && !_mtManagerInstalled) {
      // 提示用户未安装 MT 管理器
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          content: const Text('你好像没下MT管理器哦=￣ω￣='),
          actions: [
            CupertinoDialogAction(
              child: const Text('好'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
      return;
    }
    await StorageService.setFilePickerType(type);
    setState(() => _pickerType = type);
  }

  String get _pickerTypeLabel {
    switch (_pickerType) {
      case FilePickerType.gallery:
        return '系统相册（默认）';
      case FilePickerType.system:
        return '系统原生选择器';
      case FilePickerType.mtManager:
        return 'MT 管理器';
    }
  }

  Future<void> _showPickerTypeDialog() async {
    final selected = await showCupertinoModalPopup<FilePickerType>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择文件选择器'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(FilePickerType.gallery),
            child: const Text('系统相册（默认）'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(FilePickerType.system),
            child: const Text('系统原生选择器'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(FilePickerType.mtManager),
            child: const Text('MT 管理器'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected != null) {
      await _changePickerType(selected);
    }
  }

  /// GitHub 跳转：液态玻璃确认弹窗 → 点击"好"才跳转
  Future<void> _showGithubConfirm() async {
    await showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GlassConfirmDialog(
        title: '即将跳转',
        message: '即将打开浏览器跳转至 GitHub 仓库\nhttps://github.com/Ming-QWQ520/iconvert',
        confirmText: '好',
        cancelText: '取消',
        onConfirm: () async {
          Navigator.of(ctx).pop();
          await _launchGithub();
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Future<void> _launchGithub() async {
    const url = 'https://github.com/Ming-QWQ520/iconvert';
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            content: Text('无法打开浏览器: $e'),
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
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('设置'), backgroundColor: CupertinoColors.transparent, border: null),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 24),
          children: [
            // 液态玻璃质感说明卡片
            _buildGlassHeader(),

            const SizedBox(height: 24),

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
                    style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _editPath,
                ),
                CupertinoListTile.notched(
                  title: const Text('清除缓存'),
                  subtitle: const Text(
                    '清理临时文件和预览文件',
                    style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _clearCache,
                ),
                CupertinoListTile.notched(
                  title: const Text('全 UI 液态玻璃'),
                  subtitle: const Text(
                    '开启后所有界面使用液态玻璃效果',
                    style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                  ),
                  trailing: CupertinoSwitch(
                    value: _liquidGlass,
                    onChanged: _toggleLiquidGlass,
                  ),
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
                // 开发者行：左侧头像 + 名称
                CupertinoListTile.notched(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/ming_avatar.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: const Text('开发者'),
                  additionalInfo: const Text('明 (Ming)'),
                ),
                // GitHub 仓库：点击跳转
                CupertinoListTile.notched(
                  title: const Text('GitHub 仓库'),
                  additionalInfo: const Text('Ming-QWQ520'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _showGithubConfirm,
                ),
              ],
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
                    style: TextStyle(fontSize: 11, color: CupertinoColors.systemGrey2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 液态玻璃质感顶部说明卡片
  Widget _buildGlassHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: CupertinoColors.separator.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      CupertinoIcons.cube_box,
                      size: 22,
                      color: Color(0xFF007AFF),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'iConvert - 格式转换器',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '• 支持 JPEG/PNG/WebP/HEIC/BMP/ICO 等图片格式\n'
                  '• 支持 MP4/MKV/MOV/AVI/WebM/FLV/GIF 等视频格式\n'
                  '• 批量转换，后台队列执行\n'
                  '• 硬件编码优先，自动软件降级\n'
                  '• 所有处理均在本地完成，不上传任何数据',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 液态玻璃确认弹窗（用于 GitHub 跳转确认）
class _GlassConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _GlassConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: CupertinoColors.separator.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
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
                    CupertinoIcons.arrow_up_right_square,
                    size: 28,
                    color: Color(0xFF007AFF),
                  ),
                ),
                // 标题
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                // 消息
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey, height: 1.4),
                ),
                const SizedBox(height: 24),
                // 按钮
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: CupertinoColors.systemGrey5,
                        borderRadius: BorderRadius.circular(10),
                        onPressed: onCancel,
                        child: Text(
                          cancelText,
                          style: const TextStyle(fontSize: 15, color: CupertinoColors.systemGrey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        borderRadius: BorderRadius.circular(10),
                        onPressed: onConfirm,
                        child: Text(confirmText, style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
