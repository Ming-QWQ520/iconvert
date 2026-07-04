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
import 'package:iconvert/services/command_builder.dart';
import 'package:iconvert/widgets/file_list_tile.dart';
import 'package:iconvert/dialogs/edit_dialog.dart';
import 'package:iconvert/dialogs/permission_dialog.dart';
import 'package:iconvert/dialogs/path_setting_dialog.dart';
import 'package:iconvert/dialogs/remove_from_queue_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Map<String, String> _thumbnailPaths = {};
  bool _wizardChecked = false;
  // 多选模式
  bool _selectionMode = false;
  final Set<String> _selectedTaskIds = {};
  // 用于监听 ConversionModel 变化的引用
  late final ConversionModel _conversionModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstRunWizard();
      _conversionModel = context.read<ConversionModel>();
      _conversionModel.addListener(_onTasksChanged);
      // 初始化时为已有任务生成缩略图
      _generateMissingThumbnails();
    });
  }

  @override
  void dispose() {
    _conversionModel.removeListener(_onTasksChanged);
    super.dispose();
  }

  /// ConversionModel 变化回调：检查新任务并生成缩略图
  void _onTasksChanged() {
    _generateMissingThumbnails();
  }

  /// 为没有缩略图的任务生成缩略图
  void _generateMissingThumbnails() {
    for (final task in _conversionModel.tasks) {
      if (!_thumbnailPaths.containsKey(task.id)) {
        _generateThumbnail(task);
      }
    }
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

    // 跟踪成功/失败计数
    int successCount = 0;
    int failedCount = 0;
    int completedCount = 0;

    // 启动前台服务通知
    await ForegroundService.start(total: total);

    await model.startAll(
      outputDir: outputDir,
      onTaskCompleted: (task) async {
        await history.add(task);
        completedCount++;
        successCount++;
        // 更新通知进度（含成功/失败计数）
        await ForegroundService.updateNotification(
          completed: completedCount,
          total: total,
          success: successCount,
          failed: failedCount,
          currentFileName: task.originalName,
        );
      },
      onTaskFailed: (task) {
        completedCount++;
        failedCount++;
        ForegroundService.updateNotification(
          completed: completedCount,
          total: total,
          success: successCount,
          failed: failedCount,
          currentFileName: task.originalName,
        );
      },
    );

    // 完成后通知 + 3 秒后停止前台服务
    await ForegroundService.updateNotification(
      completed: completedCount,
      total: total,
      success: successCount,
      failed: failedCount,
      currentFileName: null,
    );
    await Future.delayed(const Duration(seconds: 3));
    await ForegroundService.stop();
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(_selectionMode
              ? '已选 ${_selectedTaskIds.length} 项'
              : '格式工厂'),
          leading: _selectionMode
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('取消'),
                  onPressed: _exitSelectionMode,
                )
              : CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.list_bullet),
                  onPressed: () => _navigateToHistory(),
                ),
          trailing: _selectionMode
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text(
                        '开始',
                        style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w600),
                      ),
                      onPressed: _selectedTaskIds.isEmpty ? null : _startSelected,
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text(
                        '删除',
                        style: TextStyle(color: CupertinoColors.destructiveRed),
                      ),
                      onPressed: _selectedTaskIds.isEmpty ? null : _deleteSelected,
                    ),
                  ],
                )
              : Row(
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
                            // 选择模式不显示 Dismissible
                            if (_selectionMode) {
                              return FileListTile(
                                task: task,
                                thumbnailPath: _thumbnailPaths[task.id],
                                selectionMode: true,
                                selected: _selectedTaskIds.contains(task.id),
                                onTap: () => _toggleSelection(task.id),
                              );
                            }
                            // 非选择模式：只允许左滑（endToStart）删除
                            return Dismissible(
                              key: ValueKey(task.id),
                              // 仅左滑（endToStart）方向
                              direction: DismissDirection.endToStart,
                              // 左滑时显示的背景（靠右对齐的删除按钮）
                              background: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.destructiveRed,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.delete, color: CupertinoColors.white, size: 22),
                                    SizedBox(height: 2),
                                    Text('移除', style: TextStyle(color: CupertinoColors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                // 液态玻璃确认弹窗
                                final confirmed = await RemoveFromQueueDialog.show(
                                  context,
                                  fileName: task.originalName,
                                );
                                if (confirmed) {
                                  model.removeTask(task.id);
                                  _thumbnailPaths.remove(task.id);
                                }
                                return false;  // 不自动关闭，手动处理
                              },
                              child: FileListTile(
                                task: task,
                                thumbnailPath: _thumbnailPaths[task.id],
                                onTap: () => _showEditDialog(task),
                                onLongPress: () => _enterSelectionMode(task.id),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),

              // 悬浮加号按钮（选择模式隐藏）
              if (!_selectionMode)
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

  /// 进入多选模式（长按触发）
  void _enterSelectionMode(String taskId) {
    setState(() {
      _selectionMode = true;
      _selectedTaskIds.clear();
      _selectedTaskIds.add(taskId);
    });
  }

  /// 退出多选模式
  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedTaskIds.clear();
    });
  }

  /// 切换选中状态
  void _toggleSelection(String taskId) {
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
        if (_selectedTaskIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedTaskIds.add(taskId);
      }
    });
  }

  /// 删除选中的任务
  void _deleteSelected() {
    final model = context.read<ConversionModel>();
    for (final id in _selectedTaskIds) {
      model.removeTask(id);
      _thumbnailPaths.remove(id);
    }
    _exitSelectionMode();
  }

  /// 开始选中的任务转换
  Future<void> _startSelected() async {
    final model = context.read<ConversionModel>();
    final history = context.read<HistoryModel>();
    final outputDir = await StorageService.getOutputDir();

    // 取出选中的任务
    final selectedTasks = model.tasks
        .where((t) => _selectedTaskIds.contains(t.id))
        .toList();
    if (selectedTasks.isEmpty) return;

    // 退出选择模式
    _exitSelectionMode();

    // 启动前台服务
    final total = selectedTasks.length;
    int successCount = 0;
    int failedCount = 0;
    int completedCount = 0;
    await ForegroundService.start(total: total);

    // 逐个执行选中的任务
    for (final task in selectedTasks) {
      if (model.isConverting == false && completedCount == 0) {
        // 第一次进入
      }
      // 检查任务是否还在列表中（可能被用户删除）
      final taskIdx = model.tasks.indexWhere((t) => t.id == task.id);
      if (taskIdx < 0) continue;

      // 标记转换中
      model.updateTask(task.copyWith(
        status: TaskStatus.converting,
        progress: 0.0,
        errorMessage: null,
      ));

      try {
        final outputPath = await CommandBuilder.execute(
          task: task,
          outputDir: outputDir,
          onProgress: (progress) {
            model.updateTask(task.copyWith(
              status: TaskStatus.converting,
              progress: progress,
            ));
          },
        );
        final completed = task.copyWith(
          status: TaskStatus.completed,
          progress: 1.0,
          outputPath: outputPath,
          completedAt: DateTime.now(),
        );
        model.updateTask(completed);
        await history.add(completed);
        completedCount++;
        successCount++;
      } catch (e) {
        model.updateTask(task.copyWith(
          status: TaskStatus.failed,
          errorMessage: e.toString(),
          completedAt: DateTime.now(),
        ));
        completedCount++;
        failedCount++;
      }

      // 更新通知
      await ForegroundService.updateNotification(
        completed: completedCount,
        total: total,
        success: successCount,
        failed: failedCount,
        currentFileName: task.originalName,
      );

      // 自动移除完成的任务
      await Future.delayed(const Duration(milliseconds: 800));
      model.removeTask(task.id);
      _thumbnailPaths.remove(task.id);
    }

    // 完成通知 + 停止前台服务
    await ForegroundService.updateNotification(
      completed: completedCount,
      total: total,
      success: successCount,
      failed: failedCount,
    );
    await Future.delayed(const Duration(seconds: 3));
    await ForegroundService.stop();
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
