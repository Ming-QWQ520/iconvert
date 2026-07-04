/// GlassThemeProvider - 液态玻璃全局状态管理
///
/// 背景图始终显示（不管液态玻璃开关）
/// 液态玻璃开启时额外用 LiquidGlassView 包裹 UI
library;

import 'dart:io' as io;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
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

/// 全局背景 + 液态玻璃容器
///
/// 布局：
/// - 底层：背景图（始终显示）
/// - 上层：用户 UI
///   - 液态玻璃开启时：用 LiquidGlassView 包裹（UI 上的 GlassCard 会折射背景）
///   - 液态玻璃关闭时：直接显示 UI（背景图仍然在底层）
class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final glass = context.watch<GlassProvider>();

    // Stack: 底层背景图 + 上层 UI
    return Stack(
      fit: StackFit.expand,
      children: [
        // 底层：背景图（始终显示）
        _buildBackground(glass.backgroundPath),

        // 上层：UI 内容
        if (glass.enabled)
          // 液态玻璃开启：用 LiquidGlassView 包裹
          LiquidGlassView(
            backgroundWidget: _buildBackground(glass.backgroundPath),
            pixelRatio: 0.5,
            realTimeCapture: true,
            useSync: true,
            child: child,
          )
        else
          // 液态玻璃关闭：直接显示 UI
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
      );
    }
    return Image.file(
      io.File(path),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
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
/// 液态玻璃开启时：用 LiquidGlassLens（增强效果）
/// 液态玻璃关闭时：用 BackdropFilter + 半透明背景（也有模糊效果）
class GlassCard extends StatelessWidget {
  final Widget child;
  final double cornerRadius;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const GlassCard({
    super.key,
    required this.child,
    this.cornerRadius = 16,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.watch<GlassProvider>();

    if (glass.enabled) {
      // 液态玻璃开启：用 LiquidGlassLens（增强折射 + 模糊）
      return Container(
        margin: margin,
        child: LiquidGlassLens(
          style: LiquidGlassStyle(
            shape: LiquidGlassShape.continuousRoundedRectangle(
              cornerRadius: cornerRadius,
              borderWidth: 2.0,
            ),
            appearance: const LiquidGlassAppearance(
              color: Color(0x33FFFFFF),    // 更强的白色着色
              saturation: 1.3,             // 更强的饱和度
              blur: LiquidGlassBlur(sigmaX: 12, sigmaY: 12),  // 更强的模糊
            ),
            refraction: LiquidGlassRefraction(
              refractionType: OpticalRefraction(
                refraction: 2.0,           // 更强的折射
                refractionWidth: 32,       // 更宽的折射区域
                depth: 1.0,                // 更深的深度
              ),
            ),
          ),
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        ),
      );
    }

    // 液态玻璃关闭：用 BackdropFilter 模糊（也有玻璃感）
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(cornerRadius),
              border: Border.all(
                color: CupertinoColors.white.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
