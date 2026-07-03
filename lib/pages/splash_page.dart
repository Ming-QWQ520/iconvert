/// SplashScreen - 冷启动加载页
///
/// 设计：
/// - 毛玻璃模糊背景（启动页允许 sigma=20，是规划的"全局异常"）
/// - APP 图标 80x80 脉冲动画
/// - 进度文字 + CupertinoActivityIndicator
///
/// 流程：
/// 1. "初始化组件…" 等 400ms
/// 2. "正在加载 FFmpeg…" 调用 FFmpegKitConfig.init()（或预热）
/// 3. "准备就绪" 等 500ms
/// 4. Navigator.pushReplacement 到 HomePage
library;

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:iconvert/pages/home_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  String _statusText = '初始化组件…';
  bool _fadeIn = false;

  @override
  void initState() {
    super.initState();

    // 脉冲动画（呼吸效果）
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 启动初始化流程
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });

    // 短暂延迟后开始淡入
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _fadeIn = true);
    });
  }

  Future<void> _initialize() async {
    try {
      // 阶段 1: 初始化组件
      setState(() => _statusText = '初始化组件…');
      await Future.delayed(const Duration(milliseconds: 400));

      // 阶段 2: 加载 FFmpeg
      if (mounted) setState(() => _statusText = '正在加载 FFmpeg…');
      try {
        if (kDebugMode) {
          await FFmpegKitConfig.init();
        }
        await Future.delayed(const Duration(milliseconds: 600));
      } catch (e) {
        debugPrint('FFmpeg 初始化异常: $e');
      }

      // 阶段 3: 准备就绪
      if (mounted) setState(() => _statusText = '准备就绪');
      await Future.delayed(const Duration(milliseconds: 500));

      // 进入主页
      if (!mounted) return;
      await _navigateToHome();
    } catch (e) {
      debugPrint('初始化失败: $e');
      if (mounted) {
        setState(() => _statusText = '初始化失败: $e');
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        await _navigateToHome();
      }
    }
  }

  Future<void> _navigateToHome() async {
    await Navigator.of(context).pushReplacement(
      CupertinoPageRoute<void>(
        builder: (_) => const HomePage(),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      // 启动页允许使用模糊背景（规划的"全局异常"）
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 背景图（纯色渐变模拟）
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE8F0FF),
                  Color(0xFFB0C4DE),
                  Color(0xFF6B8AF0),
                ],
              ),
            ),
          ),

          // 毛玻璃模糊层
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: const Color(0xFFFFFFFF).withOpacity(0.1),
            ),
          ),

          // 内容层
          AnimatedOpacity(
            opacity: _fadeIn ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 图标脉冲
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF5AC8FA), Color(0xFF007AFF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'iC',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // 标题
                const Text(
                  'iConvert',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  '全格式转换器',
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.systemGrey5,
                  ),
                ),

                const SizedBox(height: 60),

                // 进度指示器
                const CupertinoActivityIndicator(
                  color: CupertinoColors.white,
                  radius: 12,
                ),

                const SizedBox(height: 16),

                // 状态文字
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _statusText,
                    key: ValueKey(_statusText),
                    style: const TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.systemGrey5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
