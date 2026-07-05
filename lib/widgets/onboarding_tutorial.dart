/// OnboardingTutorial - 新手教程（首次进入 APP 显示，可跳过）
///
/// 5 步教程：
/// 1. 历史记录向右滑重新转换
/// 2. 向左滑删除
/// 3. 长按打开系统打开方式
/// 4. 设置的全 UI 液态玻璃提示
/// 5. 如果觉得项目好给个 Star
library;

import 'package:flutter/cupertino.dart';
import 'package:iconvert/widgets/glass_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingTutorial extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingTutorial({super.key, required this.onComplete});

  /// 检查是否需要显示教程（首次进入 APP）
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('iconvert_onboarding_done') ?? false);
  }

  /// 标记教程已完成
  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('iconvert_onboarding_done', true);
  }

  @override
  State<OnboardingTutorial> createState() => _OnboardingTutorialState();
}

class _OnboardingTutorialState extends State<OnboardingTutorial> {
  int _currentStep = 0;

  final List<_TutorialStep> _steps = [
    _TutorialStep(
      icon: CupertinoIcons.arrow_clockwise,
      title: '重新转换',
      description: '在历史记录中，向右滑动卡片可以快速重新转换文件',
      color: const Color(0xFF007AFF),
    ),
    _TutorialStep(
      icon: CupertinoIcons.delete,
      title: '删除记录',
      description: '在历史记录或首页中，向左滑动卡片可以删除任务',
      color: CupertinoColors.destructiveRed,
    ),
    _TutorialStep(
      icon: CupertinoIcons.hand_point_right_fill,
      title: '打开方式',
      description: '长按历史记录中的卡片，可以调起系统打开方式选择器',
      color: const Color(0xFF34C759),
    ),
    _TutorialStep(
      icon: CupertinoIcons.sparkles,
      title: '液态玻璃',
      description: '在设置中开启「全 UI 液态玻璃」可以增加观感，但对性能有一定要求',
      color: const Color(0xFF5856D6),
    ),
    _TutorialStep(
      icon: CupertinoIcons.star_fill,
      title: '给个 Star',
      description: '如果觉得项目好，去 GitHub 给个 Star 吧！',
      color: const Color(0xFFFF9500),
    ),
  ];

  void _next() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _finish();
    }
  }

  void _skip() {
    _finish();
  }

  void _finish() {
    OnboardingTutorial.markDone();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0x99000000),
      child: SafeArea(
        child: Center(
          child: GlassCard(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(28),
            cornerRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 跳过按钮
                Align(
                  alignment: Alignment.topRight,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 30,
                    child: const Text('跳过', style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey)),
                    onPressed: _skip,
                  ),
                ),

                // 图标
                Container(
                  width: 72,
                  height: 72,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: step.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(step.icon, size: 36, color: step.color),
                ),

                // 标题
                Text(
                  step.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),

                // 描述
                Text(
                  step.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: CupertinoColors.systemGrey, height: 1.5),
                ),
                const SizedBox(height: 24),

                // 进度点
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_steps.length, (index) {
                    final active = index == _currentStep;
                    return Container(
                      width: active ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF007AFF) : CupertinoColors.systemGrey4,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // 按钮
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    borderRadius: BorderRadius.circular(14),
                    child: Text(isLast ? '开始使用' : '下一步', style: const TextStyle(fontSize: 16)),
                    onPressed: _next,
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

class _TutorialStep {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
