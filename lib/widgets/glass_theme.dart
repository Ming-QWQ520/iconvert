/// GlassThemeProvider - 液态玻璃全局状态管理
///
/// 背景图始终显示（不管液态玻璃开关）
/// 液态玻璃用 BackdropFilter 实现（兼容所有设备，不依赖 Impeller）
library;

import 'dart:io' as io;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:iconvert/services/storage_service.dart';
import 'package:iconvert/services/background_service.dart';

class GlassProvider extends ChangeNotifier {
  bool _enabled = false;
  String _backgroundPath = BackgroundService.defaultBackground;

  bool get enabled => _enabled;
  String get backgroundPath => _backgroundPath;

  Future<void> load() async {
    _enabled = await StorageService.isLiquidGlassEnabled();
    _backgroundPath = await BackgroundService.getBackgroundPath();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await StorageService.setLiquidGlassEnabled(value);
    notifyListeners();
  }

  Future<void> setBackgroundPath(String path) async {
    _backgroundPath = path;
    await BackgroundService.setBackgroundPath(path);
    notifyListeners();
  }

  Future<void> resetBackground() async {
    await BackgroundService.resetToDefault();
    _backgroundPath = BackgroundService.defaultBackground;
    notifyListeners();
  }
}

/// 全局背景容器
///
/// 用 Stack 布局：
/// - 底层：背景图（始终显示，全屏覆盖）
/// - 上层：用户 UI（scaffold 背景设为透明，让背景图透出来）
class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final glass = context.watch<GlassProvider>();

    return Stack(
      fit: StackFit.expand,
      children: [
        // 底层：背景图（始终全屏显示）
        _buildBackground(glass.backgroundPath),

        // 上层：UI 内容（背景透明，让背景图透出来）
        child,
      ],
    );
  }

  Widget _buildBackground(String path) {
    if (BackgroundService.isAsset(path)) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      );
    }
    return Image.file(
      io.File(path),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Image.asset(
        BackgroundService.defaultBackground,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}

/// 液态玻璃卡片
///
/// 用 BackdropFilter 实现真正的玻璃效果：
/// - 模糊背景（sigma 根据开关调整）
/// - 半透明着色
/// - 高光边框
/// - iOS 控制中心风格的连续圆角
class GlassCard extends StatelessWidget {
  final Widget child;
  final double cornerRadius;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const GlassCard({
    super.key,
    required this.child,
    this.cornerRadius = 20,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.watch<GlassProvider>();

    // 液态玻璃开启：强模糊 + 高折射感
    // 液态玻璃关闭：弱模糊 + 半透明
    final sigma = glass.enabled ? 20.0 : 8.0;
    final bgColor = glass.enabled
        ? const Color(0x33FFFFFF)     // 开启：更白的玻璃
        : CupertinoColors.systemBackground.withValues(alpha: 0.6);
    final borderColor = glass.enabled
        ? const Color(0x55FFFFFF)     // 开启：更亮的高光边框
        : CupertinoColors.white.withValues(alpha: 0.15);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(cornerRadius),
              border: Border.all(color: borderColor, width: 0.5),
              // iOS 控制中心风格的内阴影效果
              gradient: glass.enabled
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0x44FFFFFF),
                        const Color(0x11FFFFFF),
                      ],
                    )
                  : null,
              boxShadow: glass.enabled
                  ? [
                      BoxShadow(
                        color: const Color(0x22000000),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
