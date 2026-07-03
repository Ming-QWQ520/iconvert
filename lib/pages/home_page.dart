/// HomePage - 主界面
///
/// 布局：
/// - CupertinoPageScaffold + CupertinoNavigationBar
///   - 标题: "格式工厂"
///   - 右侧: "全部开始" 按钮
///   - 左侧: 设置齿轮
/// - 文件列表（空状态显示引导卡片）
/// - 右下角悬浮按钮（圆形加号）
/// - 导航栏下方全局进度条（仅转换时显示）
///
/// 首次启动：
/// - 检测权限和输出路径，缺失则弹出液态玻璃向导
library;

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:iconvert/models/conversion_model.dart';
import 'package:iconvert/models/conversion_task.dart';
import 'package:iconvert/models/history_model.dart';
import 'package:iconvert/pages/history_page.dart';
import 'package:iconvert/pages/settings_page.dart';
import 'package:iconvert/services/file_service.dart';
import 'package:iconvert/services/storage_service.dart';
import 'package:iconvert/widgets/file_list_tile.dart';
import 'package:iconvert/dialogs/edit_dialog.dart';
import 'package:iconvert/dialogs/permission_dialog.dart';
import 'package:iconvert/dialogs/path_setting_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Map<String, String> _thumbnailPaths = {};  // taskId -> thumbnailPath
  bool _wizardChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstRunWizard();
    });
  }

  /// 首次设置向导：检测权限和输出路径
  Future<void> _checkFirstRunWizard() async {
    if (_wizardChecked) return;
    _wizardChecked = true;

    final hasPermission = await PermissionDialog.checkStoragePermission();
    if (!hasPermission && mounted) {
      await _showPermissionWizard();
      // 用户处理完权限后再检查路径
    }

    if (!mounted) return;
    final outputDir = await StorageService.getOutputDir();
    if (outputDir == StorageService.defaultOutputDir && mounted) {
      await _showPathWizard();
    }
  }

  Future<void> _showPermissionWizard() async {
    final granted = await showCupertinoModalPopup<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PermissionDialog(),
    );
    if (granted == true && mounted) {
      // 权限获取后继续
    }
  }

  Future<void> _showPathWizard() async {
    await showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PathSettingDialog(),
    );
  }

  /// 选择文件
  Future<void> _pickFiles() async {
    final files = await FileService.pickFiles();
    if (files.isEmpty) return;

    final model = context.read<ConversionModel>();
    final List<ConversionTask> newTasks = [];

    for (final file in files) {
      try {
        final tempPath = await FileService.copyToTempInput(file);
        final type = FileService.inferType(file.name);
        // 默认输出格式
        final defaultOutput = type == MediaFileType.image ? 'jpg' : 'mp4';

        final task = ConversionTask(
          id: 'task_${DateTime.now().millisecondsSinceEpoch}_${file.name.hashCode.abs()}',
          inputPath: tempPath,
          originalName: file.name,
          type: type,
          outputFormat: defaultOutput,
          quality: 80,
          createdAt: DateTime.now(),
        );
        newTasks.add(task);

        // 后台生成缩略图
        _generateThumbnail(task);
      } catch (e) {
        // 单个文件失败不影响其他
        debugPrint('添加任务失败 ${file.name}: $e');
      }
    }

    if (newTasks.isNotEmpty) {
      model.addAll(newTasks);
    }
  }

  Future<void> _generateThumbnail(ConversionTask task) async {
    final thumbPath = await FileService.generateThumbnail(
      inputPath: task.inputPath,
      type: task.type,
    );
    if (thumbPath != null && mounted) {
      setState(() {
        _thumbnailPaths[task.id] = thumbPath;
      });
    }
  }

  /// 启动全部转换
  Future<void> _startAll() async {
    final model = context.read<ConversionModel>();
    final history = context.read<HistoryModel>();
    final outputDir = await StorageService.getOutputDir();

    // 启动前台服务通知
    await _startForegroundNotification(model.tasks.length);

    await model.startAll(
      outputDir: outputDir,
      onTaskCompleted: (task) async {
        await history.add(task);
        await _updateForegroundNotification(
          completed: model.completedCount,
          total: model.tasks.length,
        );
      },
    );

    // 完成 3 秒后停止前台服务
    await _stopForegroundNotification();
  }

  Future<void> _startForegroundNotification(int total) async {
    // 简化实现：前台服务封装在另一个服务，这里仅占位
    // 实际项目可调用 FlutterForegroundTask.startService()
    debugPrint('启动前台服务: 共 $total 个任务');
  }

  Future<void> _updateForegroundNotification({
    required int completed,
    required int total,
  }) async {
    debugPrint('前台服务进度: $completed / $total');
  }

  Future<void> _stopForegroundNotification() async {
    await Future.delayed(const Duration(seconds: 3));
    debugPrint('停止前台服务');
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('格式工厂'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.list_bullet),
          onPressed: () => _navigateToHistory(),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.settings),
              onPressed: () => _navigateToSettings(),
            ),
            Consumer<ConversionModel>(
              builder: (context, model, _) {
                if (model.isConverting) {
                  return CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text(
                      '取消',
                      style: TextStyle(color: CupertinoColors.destructiveRed),
                    ),
                    onPressed: () => model.cancelConversion(),
                  );
                }
                return CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Text(
                    '全部开始',
                    style: TextStyle(
                      color: model.tasks.isEmpty
                          ? CupertinoColors.systemGrey
                          : const Color(0xFF007AFF),
                    ),
                  ),
                  onPressed: model.tasks.isEmpty ? null : _startAll,
                );
              },
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // 列表
            Consumer<ConversionModel>(
              builder: (context, model, _) {
                if (model.tasks.isEmpty) {
                  return _buildEmptyState();
                }

                return Column(
                  children: [
                    // 全局进度条（仅转换时显示）
                    if (model.isConverting)
                      _buildProgressBar(model.overallProgress),

                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 80),
                        itemCount: model.tasks.length,
                        itemBuilder: (context, index) {
                          final task = model.tasks[index];
                          return FileListTile(
                            task: task,
                            thumbnailPath: _thumbnailPaths[task.id],
                            onTap: () => _showEditDialog(task),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),

            // 悬浮加号按钮
            Positioned(
              right: 20,
              bottom: 20,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(
                    CupertinoIcons.add,
                    color: CupertinoColors.white,
                    size: 28,
                  ),
                  onPressed: _pickFiles,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.cube_box,
              size: 64,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            const Text(
              '还没有文件',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '点击右下角加号选择需要转换的图片或视频',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              child: const Text('选择文件'),
              onPressed: _pickFiles,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '转换进度',
                style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF007AFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicatorCupertino(
                value: progress,
                backgroundColor: CupertinoColors.systemGrey5,
                foregroundColor: const Color(0xFF007AFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(ConversionTask task) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => EditDialog(task: task),
    );
  }

  void _navigateToHistory() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const HistoryPage(),
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const SettingsPage(),
      ),
    );
  }
}

/// Cupertino 风格的线性进度条（用自定义实现替代 Material 的 LinearProgressIndicator）
class LinearProgressIndicatorCupertino extends StatelessWidget {
  final double value;           // 0.0 - 1.0
  final Color backgroundColor;
  final Color foregroundColor;

  const LinearProgressIndicatorCupertino({
    super.key,
    required this.value,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: backgroundColor,
          ),
        ),
        FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: foregroundColor,
            ),
          ),
        ),
      ],
    );
  }
}
