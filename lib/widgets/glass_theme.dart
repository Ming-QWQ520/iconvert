/// GlassThemeProvider - 液态玻璃全局状态管理
///
/// 背景图始终显示（不管液态玻璃开关）
/// 液态玻璃开启时用 LiquidGlassView + LiquidGlassLens（3.2.2 修复了 Skia 兼容性）
/// 液态玻璃关闭时用 BackdropFilter（简单模糊）
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

/// 构建背景图 Widget（共用）
Widget buildBackgroundWidget(String path) {
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

/// 全局背景 + 液态玻璃容器
///
/// 用 Stack 布局：
/// - 底层：背景图（始终显示）
/// - 上层：UI
///   - 液态玻璃开启：LiquidGlassView 包裹（Lens 会折射背景）
///   - 液态玻璃关闭：直接显示 UI
class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final glass = context.watch<GlassProvider>();

    if (glass.enabled) {
      // 液态玻璃开启：用 LiquidGlassView（3.2.2 兼容 Skia）
      return LiquidGlassView(
        backgroundWidget: buildBackgroundWidget(glass.backgroundPath),
        pixelRatio: 0.5,
        realTimeCapture: true,
        useSync: true,
        child: child,
      );
    }

    // 液态玻璃关闭：Stack 底层背景 + 上层 UI
    return Stack(
      fit: StackFit.expand,
      children: [
        buildBackgroundWidget(glass.backgroundPath),
        child,
      ],
    );
  }
}

/// 液态玻璃卡片
///
/// 液态玻璃开启：LiquidGlassLens（iOS 控制中心风格折射）
/// 液态玻璃关闭：返回 null（保持原 UI 风格，调用方需处理）
/// 用 GlassCard.wrapIfEnabled 替代直接使用
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

  /// 仅在液态玻璃开启时包裹 GlassCard，否则返回原 child
  static Widget wrapIfEnabled(
    BuildContext context, {
    required Widget child,
    double cornerRadius = 20,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
    final glass = context.watch<GlassProvider>();
    if (!glass.enabled) return child;
    return GlassCard(
      cornerRadius: cornerRadius,
      padding: padding,
      margin: margin,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.watch<GlassProvider>();

    if (!glass.enabled) {
      // 未开启：直接返回 child（保持原风格）
      return child;
    }

    // 开启：LiquidGlassLens
    return Container(
      margin: margin,
      child: LiquidGlassLens(
        style: LiquidGlassStyle(
          shape: LiquidGlassShape.continuousRoundedRectangle(
            cornerRadius: cornerRadius,
            borderWidth: 1.5,
            lightIntensity: 1.1,
            lightDirection: 39,
            borderType: OpticalBorder(
              borderSaturation: 0.8,
              ambientIntensity: 5.0,
              borderSolidity: 0.35,
            ),
          ),
          appearance: const LiquidGlassAppearance(
            color: Color(0x22FFFFFF),
            saturation: 1.15,
            blur: LiquidGlassBlur(sigmaX: 8, sigmaY: 8),
          ),
          refraction: LiquidGlassRefraction(
            refractionType: OpticalRefraction(
              refraction: 1.5,
              refractionWidth: 24,
              depth: 0.7,
            ),
          ),
        ),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}
