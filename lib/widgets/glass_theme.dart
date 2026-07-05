/// GlassThemeProvider - 液态玻璃全局状态管理
///
/// 未开启：白色主色调，无任何液态玻璃效果
/// 开启：LiquidGlassView 包裹 + GlassCard 用 LiquidGlassLens
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
  double _blur = 0.4;  // 默认中等模糊强度
  String _backgroundPath = BackgroundService.defaultBackground;

  bool get enabled => _enabled;
  double get blur => _blur;
  String get backgroundPath => _backgroundPath;

  Future<void> load() async {
    _enabled = await StorageService.isLiquidGlassEnabled();
    _blur = await StorageService.getLiquidGlassBlur();
    _backgroundPath = await BackgroundService.getBackgroundPath();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    // 关键：去重检查，避免状态错乱（修复开关切换时按钮状态卡顿问题）
    if (_enabled == value) return;
    _enabled = value;
    await StorageService.setLiquidGlassEnabled(value);
    notifyListeners();
  }

  Future<void> setBlur(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    if ((_blur - clamped).abs() < 0.001) return;
    _blur = clamped;
    await StorageService.setLiquidGlassBlur(clamped);
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

  /// 当前模糊强度对应的 sigma 值（2.0 - 14.0）
  double get blurSigma {
    // 0.0 -> 2.0, 1.0 -> 14.0
    return 2.0 + _blur * 12.0;
  }

  /// 当前模糊强度对应的 pixelRatio（值越大越清晰）
  /// 模糊越强 → pixelRatio 越小（背景采样更低分辨率 = 更模糊）
  double get pixelRatio {
    // 0.0 -> 1.0（最清晰）, 1.0 -> 0.2（最模糊）
    return 1.0 - _blur * 0.8;
  }
}

/// 构建背景图 Widget
Widget buildBackgroundWidget(String path) {
  if (BackgroundService.isAsset(path)) {
    return Image.asset(path, fit: BoxFit.cover, width: double.infinity, height: double.infinity, gaplessPlayback: true);
  }
  return Image.file(io.File(path), fit: BoxFit.cover, width: double.infinity, height: double.infinity, gaplessPlayback: true,
    errorBuilder: (_, __, ___) => Image.asset(BackgroundService.defaultBackground, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
  );
}

/// 全局背景容器
/// 未开启：白色背景（无背景图，无玻璃）
/// 开启：LiquidGlassView + 背景图
class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final glass = context.watch<GlassProvider>();

    if (glass.enabled) {
      return LiquidGlassView(
        backgroundWidget: buildBackgroundWidget(glass.backgroundPath),
        pixelRatio: glass.pixelRatio,
        realTimeCapture: false,
        useSync: true,
        child: child,
      );
    }

    // 未开启：白色背景，无任何玻璃效果
    return Container(
      color: CupertinoColors.systemBackground,
      child: child,
    );
  }
}

/// 液态玻璃卡片
/// 未开启：返回原 child（白色背景的原 UI）
/// 开启：LiquidGlassLens 包裹
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

  /// 仅在液态玻璃开启时包裹，否则返回原 child
  static Widget wrapIfEnabled(
    BuildContext context, {
    required Widget child,
    double cornerRadius = 20,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
    final glass = context.watch<GlassProvider>();
    if (!glass.enabled) return child;
    return GlassCard(cornerRadius: cornerRadius, padding: padding, margin: margin, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.watch<GlassProvider>();

    if (!glass.enabled) return child;

    final sigma = glass.blurSigma;

    return Container(
      margin: margin,
      child: LiquidGlassLens(
        style: LiquidGlassStyle(
          shape: LiquidGlassShape.continuousRoundedRectangle(
            cornerRadius: cornerRadius,
            borderWidth: 1.5,
            lightIntensity: 1.1,
            lightDirection: 39,
            borderType: OpticalBorder(borderSaturation: 0.8, ambientIntensity: 5.0, borderSolidity: 0.35),
          ),
          appearance: LiquidGlassAppearance(
            color: const Color(0x22FFFFFF),
            saturation: 1.1,
            blur: LiquidGlassBlur(sigmaX: sigma, sigmaY: sigma),
          ),
          refraction: LiquidGlassRefraction(refractionType: OpticalRefraction(refraction: 1.5, refractionWidth: 24, depth: 0.7)),
        ),
        child: padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );
  }
}

/// 液态玻璃弹窗背景
/// 用于 showCupertinoModalPopup 的弹窗内容包裹
class GlassPopup extends StatelessWidget {
  final Widget child;
  final double cornerRadius;

  const GlassPopup({super.key, required this.child, this.cornerRadius = 14});

  @override
  Widget build(BuildContext context) {
    final glass = context.watch<GlassProvider>();

    if (!glass.enabled) return child;

    final sigma = glass.blurSigma + 1.0;  // 弹窗略强一点的模糊

    return Container(
      margin: const EdgeInsets.all(16),
      child: LiquidGlassLens(
        style: LiquidGlassStyle(
          shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: cornerRadius, borderWidth: 1.5),
          appearance: LiquidGlassAppearance(
            color: const Color(0x33FFFFFF),
            saturation: 1.1,
            blur: LiquidGlassBlur(sigmaX: sigma, sigmaY: sigma),
          ),
          refraction: LiquidGlassRefraction(refractionType: OpticalRefraction(refraction: 1.5, refractionWidth: 24, depth: 0.7)),
        ),
        child: child,
      ),
    );
  }
}
