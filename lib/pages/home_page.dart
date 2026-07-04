/// HomePage - 主界面（3 分区版）
///
/// 布局：
/// - 顶部：3 个分区按钮（图片/音频/视频）
/// - 中部：当前分区的任务列表
/// - 右下角：悬浮按钮（批量选择文件并设置统一输出格式）
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
import 'package:iconvert/dialogs/batch_convert_dialog.dart';

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
  late final ConversionModel _conversionModel;
  // 当前分区
  MediaFileType _currentTab = MediaFileType.image;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstRunWizard();
      _conversionModel = context.read<ConversionModel>();
      _conversionModel.addListener(_onTasksChanged);
      _generateMissingThumbnails();
    });
  }

  @override
  void dispose() {
    _conversionModel.removeListener(_onTasksChanged);
    super.dispose();
  }

  void _onTasksChanged() {
    _generateMissingThumbnails();
  }

  void _generateMissingThumbnails() {
    for (final task in _conversionModel.tasks) {
      if (!_thumbnailPaths.containsKey(task.id)) {
        _generateThumbnail(task);
      }
    }
  }

  Future<void> _checkFirstRunWizard() async {
    if (_wizardChecked) return;
    _wizardChecked = true;

    final hasPermission = await PermissionDialog.checkStoragePermission();
    if (!hasPermission && mounted) {
      await _showPermissionWizard();
    }

    if (!mounted) return;
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

  /// 批量选择文件并设置统一输出格式
  Future<void> _batchPickFiles() async {
    // 根据当前 tab 选择文件类型
    List<String> allowedExts;
    String defaultOutput;
    switch (_currentTab) {
      case MediaFileType.image:
        allowedExts = FileService.imageExts;
        defaultOutput = 'jpg';
        break;
      case MediaFileType.audio:
        allowedExts = FileService.audioExts;
        defaultOutput = 'mp3';
        break;
      case MediaFileType.video:
        allowedExts = FileService.videoExts;
        defaultOutput = 'mp4';
        break;
    }

    final files = await FileService.pickFiles(
      allowedExtensions: allowedExts,
      mediaType: _currentTab,
    );
    if (files.isEmpty) return;

    // 弹出批量转换弹窗，让用户选择统一输出格式和参数
    if (!mounted) return;
    final batchParams = await showCupertinoModalPopup<BatchConvertParams>(
      context: context,
      builder: (_) => BatchConvertDialog(
        fileType: _currentTab,
        defaultOutputFormat: defaultOutput,
        fileCount: files.length,
      ),
    );

    if (batchParams == null) return;

    // 用选择的参数创建任务
    final model = context.read<ConversionModel>();
    final List<ConversionTask> newTasks = [];

    for (final file in files) {
      try {
        final tempPath = await FileService.copyToTempInput(file);
        final type = FileService.inferType(file.name);

        final task = ConversionTask(
          id: 'task_${DateTime.now().millisecondsSinceEpoch}_${file.name.hashCode.abs()}',
          inputPath: tempPath,
          originalName: file.name,
          type: type,
          outputFormat: batchParams.outputFormat,
          quality: batchParams.quality,
          width: batchParams.width,
          height: batchParams.height,
          fps: batchParams.fps,
          loopCount: batchParams.loopCount,
          paletteColors: batchParams.paletteColors,
          keepTransparency: batchParams.keepTransparency,
          backgroundColor: batchParams.backgroundColor,
          sampleRate: batchParams.sampleRate,
          bitDepth: batchParams.bitDepth,
          audioBitrate: batchParams.audioBitrate,
          channels: batchParams.channels,
          enable3DSurround: batchParams.enable3DSurround,
          createdAt: DateTime.now(),
        );
        newTasks.add(task);
      } catch (e) {
        debugPrint('添加任务失败 ${file.name}: $e');
      }
    }

    if (newTasks.isNotEmpty) {
      model.addAll(newTasks);
    }
  }

  Future<void> _generateThumbnail(ConversionTask task) async {
    if (task.type == MediaFileType.audio) {
      // 音频用通用图标，不需要生成缩略图
      return;
    }
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

    int successCount = 0;
    int failedCount = 0;
    int completedCount = 0;

    await ForegroundService.start(total: total);

    await model.startAll(
      outputDir: outputDir,
      onProgress: (task, progress) {
        // 实时更新通知栏当前任务进度
        ForegroundService.updateProgress(
          currentProgress: progress,
          completedCount: completedCount,
          total: total,
          currentFileName: task.originalName,
          successCount: successCount,
          failedCount: failedCount,
        );
      },
      onTaskCompleted: (task) async {
        await history.add(task);
        completedCount++;
        successCount++;
        await ForegroundService.updateTaskDone(
          completedCount: completedCount,
          total: total,
          fileName: task.originalName,
          successCount: successCount,
          failedCount: failedCount,
        );
      },
      onTaskFailed: (task) {
        completedCount++;
        failedCount++;
        ForegroundService.updateTaskDone(
          completedCount: completedCount,
          total: total,
          fileName: task.originalName,
          successCount: successCount,
          failedCount: failedCount,
        );
      },
    );

    // 完成总结通知
    await ForegroundService.showSummary(
      total: total,
      successCount: successCount,
      failedCount: failedCount,
    );
    await Future.delayed(const Duration(seconds: 3));
    await ForegroundService.stop();
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('iConvert'),
          leading: CupertinoButton(
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
                      child: const Text('开始', style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w600)),
                      onPressed: _selectedTaskIds.isEmpty ? null : _startSelected,
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('删除', style: TextStyle(color: CupertinoColors.destructiveRed)),
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
                            child: const Text('取消', style: TextStyle(color: CupertinoColors.destructiveRed)),
                            onPressed: () {
                              model.cancelConversion();
                              ForegroundService.stop();
                            },
                          );
                        }
                        final currentTasks = model.tasks.where((t) => t.type == _currentTab).length;
                        return CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Text(
                            '全部开始',
                            style: TextStyle(
                              color: currentTasks == 0 ? CupertinoColors.systemGrey : const Color(0xFF007AFF),
                            ),
                          ),
                          onPressed: currentTasks == 0 ? null : _startAll,
                        );
                      },
                    ),
                  ],
                ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // 顶部 3 分区按钮
                  _buildTabBar(),
                  // 全局进度条
                  Consumer<ConversionModel>(
                    builder: (context, model, _) {
                      if (model.isConverting) {
                        return _buildProgressBar(model.overallProgress);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  // 任务列表（按当前 tab 过滤）
                  Expanded(
                    child: Consumer<ConversionModel>(
                      builder: (context, model, _) {
                        final tasks = model.tasks.where((t) => t.type == _currentTab).toList();
                        if (tasks.isEmpty) {
                          return _buildEmptyState();
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            if (_selectionMode) {
                              return FileListTile(
                                task: task,
                                thumbnailPath: _thumbnailPaths[task.id],
                                selectionMode: true,
                                selected: _selectedTaskIds.contains(task.id),
                                onTap: () => _toggleSelection(task.id),
                                onLongPress: () => _toggleSelection(task.id),
                              );
                            }
                            return Dismissible(
                              key: ValueKey(task.id),
                              direction: DismissDirection.endToStart,
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
                                final confirmed = await RemoveFromQueueDialog.show(
                                  context,
                                  fileName: task.originalName,
                                );
                                if (confirmed) {
                                  model.removeTask(task.id);
                                  _thumbnailPaths.remove(task.id);
                                }
                                return false;
                              },
                              child: FileListTile(
                                task: task,
                                thumbnailPath: _thumbnailPaths[task.id],
                                onTap: () => _showEditDialog(task),
                                onLongPress: () => _enterSelectionMode(task.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
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
                      child: const Icon(CupertinoIcons.add, color: CupertinoColors.white, size: 28),
                      onPressed: _batchPickFiles,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部 3 分区切换栏
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildTabButton('图片', MediaFileType.image, CupertinoIcons.photo),
          _buildTabButton('音频', MediaFileType.audio, CupertinoIcons.music_note),
          _buildTabButton('视频', MediaFileType.video, CupertinoIcons.film),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, MediaFileType type, IconData icon) {
    final selected = _currentTab == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? CupertinoColors.systemBackground : CupertinoColors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [BoxShadow(color: CupertinoColors.systemGrey.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: selected ? const Color(0xFF007AFF) : CupertinoColors.systemGrey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFF007AFF) : CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String msg;
    IconData icon;
    switch (_currentTab) {
      case MediaFileType.image:
        msg = '点击右下角加号选择需要转换的图片';
        icon = CupertinoIcons.photo;
        break;
      case MediaFileType.audio:
        msg = '点击右下角加号选择需要转换的音频';
        icon = CupertinoIcons.music_note;
        break;
      case MediaFileType.video:
        msg = '点击右下角加号选择需要转换的视频';
        icon = CupertinoIcons.film;
        break;
    }
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
            Icon(icon, size: 64, color: CupertinoColors.systemGrey),
            const SizedBox(height: 16),
            const Text('还没有文件', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: CupertinoColors.systemGrey)),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              child: const Text('选择文件'),
              onPressed: _batchPickFiles,
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
              const Text('转换进度', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
              Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
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

  void _enterSelectionMode(String taskId) {
    setState(() {
      _selectionMode = true;
      _selectedTaskIds.clear();
      _selectedTaskIds.add(taskId);
    });
  }

  void _toggleSelection(String taskId) {
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
        if (_selectedTaskIds.isEmpty) _selectionMode = false;
      } else {
        _selectedTaskIds.add(taskId);
      }
    });
  }

  void _deleteSelected() {
    final model = context.read<ConversionModel>();
    for (final id in _selectedTaskIds) {
      model.removeTask(id);
      _thumbnailPaths.remove(id);
    }
    setState(() {
      _selectionMode = false;
      _selectedTaskIds.clear();
    });
  }

  Future<void> _startSelected() async {
    final model = context.read<ConversionModel>();
    final history = context.read<HistoryModel>();
    final outputDir = await StorageService.getOutputDir();

    final selectedTasks = model.tasks.where((t) => _selectedTaskIds.contains(t.id)).toList();
    if (selectedTasks.isEmpty) return;

    setState(() {
      _selectionMode = false;
      _selectedTaskIds.clear();
    });

    final total = selectedTasks.length;
    int successCount = 0;
    int failedCount = 0;
    int completedCount = 0;
    await ForegroundService.start(total: total);

    for (final task in selectedTasks) {
      final taskIdx = model.tasks.indexWhere((t) => t.id == task.id);
      if (taskIdx < 0) continue;

      model.updateTask(task.copyWith(status: TaskStatus.converting, progress: 0.0, errorMessage: null));

      try {
        final outputPath = await CommandBuilder.execute(
          task: task,
          outputDir: outputDir,
          onProgress: (progress) {
            model.updateTask(task.copyWith(status: TaskStatus.converting, progress: progress));
          },
        );
        final completed = task.copyWith(status: TaskStatus.completed, progress: 1.0, outputPath: outputPath, completedAt: DateTime.now());
        model.updateTask(completed);
        await history.add(completed);
        completedCount++;
        successCount++;
      } catch (e) {
        model.updateTask(task.copyWith(status: TaskStatus.failed, errorMessage: e.toString(), completedAt: DateTime.now()));
        completedCount++;
        failedCount++;
      }

      await ForegroundService.updateNotification(
        completed: completedCount, total: total, success: successCount, failed: failedCount,
        currentFileName: task.originalName,
      );

      await Future.delayed(const Duration(milliseconds: 800));
      model.removeTask(task.id);
      _thumbnailPaths.remove(task.id);
    }

    await ForegroundService.updateNotification(completed: completedCount, total: total, success: successCount, failed: failedCount);
    await Future.delayed(const Duration(seconds: 3));
    await ForegroundService.stop();
  }

  void _showEditDialog(ConversionTask task) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => EditDialog(task: task),
    );
  }

  void _navigateToHistory() {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => const HistoryPage()));
  }

  void _navigateToSettings() {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => const SettingsPage()));
  }
}

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
