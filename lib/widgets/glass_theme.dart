/// GlassThemeProvider - 液态玻璃全局状态管理
///
/// 管理液态玻璃开关 + 背景图路径
/// 当开关开启时，APP 全局使用 LiquidGlassView + LiquidGlassLens 效果
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
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

/// 全局液态玻璃背景容器
/// 当液态玻璃开启时，用 LiquidGlassView 包裹整个 APP 内容
/// 当关闭时，直接返回 child（不影响性能）
class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final glass = context.watch<GlassProvider>();

    if (!glass.enabled) {
      // 液态玻璃关闭：直接返回，不影响性能
      return child;
    }

    // 液态玻璃开启：用 LiquidGlassView 包裹
    return LiquidGlassView(
      backgroundWidget: _buildBackground(glass.backgroundPath),
      pixelRatio: 0.5,
      realTimeCapture: true,
      useSync: true,
      child: child,
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
      androidFile.File(path),
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
/// 当液态玻璃开启时，用 LiquidGlassLens 包裹内容
/// 当关闭时，用普通半透明背景
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
      // 液态玻璃开启：用 LiquidGlassLens
      return Container(
        margin: margin,
        child: LiquidGlassLens(
          style: LiquidGlassStyle(
            shape: LiquidGlassShape.continuousRoundedRectangle(
              cornerRadius: cornerRadius,
              borderWidth: 1.0,
            ),
            appearance: const LiquidGlassAppearance(
              color: Color(0x14FFFFFF),
              saturation: 1.05,
              blur: LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
            ),
            refraction: LiquidGlassRefraction(
              refractionType: OpticalRefraction(
                refraction: 1.3,
                refractionWidth: 16,
                depth: 0.5,
              ),
            ),
          ),
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        ),
      );
    }

    // 液态玻璃关闭：普通半透明背景
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: child,
    );
  }
}

// 导入 dart:io 用别名避免冲突
import 'dart:io' as androidFile;
