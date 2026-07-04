/// HomePage - 主界面
library;

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:iconvert/models/conversion_model.dart';
import 'package:iconvert/models/conversion_task.dart';
import 'package:iconvert/models/history_model.dart';
import 'package:iconvert/pages/history_page.dart';
import 'package:iconvert/pages/settings_page.dart';
import 'package:iconvert/services/file_service.dart';
import 'package:iconvert/services/storage_service.dart';
import 'package:iconvert/services/foreground_service.dart';
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
  final Map<String, String> _thumbnailPaths = {};
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
    }

    if (!mounted) return;
    // 用 isFirstRunDone 标记判断，避免每次都弹
    final firstRunDone = await StorageService.isFirstRunDone();
    if (!firstRunDone && mounted) {
      await _showPathWizard();
    }
  }

  Future<void> _showPermissionWizard() async {
    await showCupertinoModalPopup<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PermissionDialog(),
    );
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
        _generateThumbnail(task);
      } catch (e) {
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
    final total = model.tasks.length;

    // 启动前台服务通知
    await ForegroundService.start(total: total);

    await model.startAll(
      outputDir: outputDir,
      onTaskCompleted: (task) async {
        await history.add(task);
        // 更新通知进度
        await ForegroundService.updateNotification(
          completed: model.completedCount + 1,
          total: total,
          currentFileName: task.originalName,
        );
      },
    );

    // 完成后通知 + 3 秒后停止前台服务
    await ForegroundService.updateNotification(
      completed: total,
      total: total,
      currentFileName: '全部完成',
    );
    await Future.delayed(const Duration(seconds: 3));
    await ForegroundService.stop();
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: CupertinoPageScaffold(
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
                      onPressed: () {
                        model.cancelConversion();
                        ForegroundService.stop();
                      },
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
              Consumer<ConversionModel>(
                builder: (context, model, _) {
                  if (model.tasks.isEmpty) {
                    return _buildEmptyState();
                  }
                  return Column(
                    children: [
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
                        color: const Color(0xFF007AFF).withValues(alpha: 0.4),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.withValues(alpha: 0.7),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '点击右下角加号选择需要转换的图片或视频',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
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
      CupertinoPageRoute<void>(builder: (_) => const HistoryPage()),
    );
  }

  void _navigateToSettings() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }
}

/// Cupertino 风格的线性进度条
class LinearProgressIndicatorCupertino extends StatelessWidget {
  final double value;
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
        Container(decoration: BoxDecoration(color: backgroundColor)),
        FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(decoration: BoxDecoration(color: foregroundColor)),
        ),
      ],
    );
  }
}
