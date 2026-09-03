import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// 果冻容器：整个组件库的质感基底
///
/// - 传入 [color]：彩色果冻件（顶部高光渐变 + 深色描边 + 彩色投影）
/// - 不传 [color]：白色表面（面板/卡片），软阴影 + 浅描边
/// - [raised] 为 false 时无彩色下坠投影（输入框、滑轨等平整件）
class JellyBox extends StatelessWidget {
  const JellyBox({
    super.key,
    this.child,
    this.color,
    this.radius,
    this.width,
    this.height,
    this.padding,
    this.alignment,
    this.constraints,
    this.raised = true,
    this.strokeColor,
    this.gradient,
    this.shadows,
    this.borderWidth,
  });

  final Widget? child;
  final Color? color;
  final BorderRadiusGeometry? radius;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;
  final BoxConstraints? constraints;

  /// 是否带彩色下坠投影
  final bool raised;

  /// 覆盖描边色（默认由主题按基色派生）
  final Color? strokeColor;

  /// 覆盖渐变（默认由主题按基色派生顶部高光）
  final Gradient? gradient;

  /// 覆盖阴影
  final List<BoxShadow>? shadows;

  final double? borderWidth;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final r = radius ?? theme.radii.lg;

    final Decoration decoration;
    if (color == null && gradient == null) {
      // 白色表面件
      decoration = BoxDecoration(
        color: theme.surface,
        borderRadius: r,
        border: Border.all(
          color: strokeColor ?? theme.stroke,
          width: borderWidth ?? (theme.isDark ? 1 : 1.4),
        ),
        boxShadow: shadows ?? theme.shadows.soft,
      );
    } else {
      // 彩色果冻件
      final base = color ?? theme.primary;
      decoration = BoxDecoration(
        gradient: gradient ??
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: theme.jellyGradient(base),
              stops: theme.jellyStops,
            ),
        borderRadius: r,
        border: Border.all(
          color: strokeColor ?? theme.jellyStroke(base),
          width: borderWidth ?? 1.2,
        ),
        boxShadow: shadows ?? (raised ? theme.jellyShadow(base) : null),
      );
    }

    return Container(
      width: width,
      height: height,
      padding: padding,
      alignment: alignment,
      constraints: constraints,
      decoration: decoration,
      child: child,
    );
  }
}
