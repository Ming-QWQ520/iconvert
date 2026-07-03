/// GlassContainer - 液态玻璃容器组件
///
/// 仅用于以下 4 类弹窗（项目硬性限制，避免性能问题）：
/// 1. 删除确认弹窗
/// 2. 权限引导弹窗
/// 3. 输出路径设置弹窗
/// 4. 首次设置向导提示框
///
/// 实现要点：
/// - 使用 RepaintBoundary 隔离重绘
/// - 复用相同 sigma 的 ImageFilter 实例（性能优化）
/// - sigma 上限 15（按规划要求）
/// - 背景色 withOpacity(0.75)
/// - 边框 separator.withOpacity(0.15)
library;

import 'dart:ui';
import 'package:flutter/cupertino.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double sigma;             // 模糊强度，上限 15
  final double borderRadius;     // 圆角
  final Color? backgroundColor;  // 自定义背景色
  final EdgeInsets padding;
  final EdgeInsets margin;

  /// 复用 ImageFilter（同 sigma 不重复创建）
  static final Map<double, ImageFilter> _filterCache = {};

  const GlassContainer({
    super.key,
    required this.child,
    this.sigma = 15,
    this.borderRadius = 14,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.all(24),
  }) : assert(sigma <= 15, 'sigma 必须 <= 15（性能限制）');

  ImageFilter _getFilter() {
    return _filterCache.putIfAbsent(sigma, () => ImageFilter.blur(
      sigmaX: sigma,
      sigmaY: sigma,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ??
        (isDark
            ? const Color(0xFF1C1C1E).withOpacity(0.75)
            : const Color(0xFFF2F2F7).withOpacity(0.75));
    final borderColor = isDark
        ? const Color(0xFF38383A).withOpacity(0.15)
        : const Color(0xFF3C3C43).withOpacity(0.15);

    return Container(
      margin: margin,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: _getFilter(),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: borderColor, width: 0.5),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
