import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// 手绘墨盒：整个组件库的容器基底（前身「果冻容器」）
///
/// 手绘化后由 skribble rough 引擎绘制：
/// - 传入 [color]：彩色涂色块（纯色实底 + 墨线描边）
/// - 不传 [color]：纸面（surface 实底 + 墨线描边）
/// - [radius] 的 pill（999）会被 rough 引擎自动钳制成胶囊/正圆
/// - [gradient]/[shadows]/[raised] 仅保 API 兼容，手绘风格下不生效
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

  /// 兼容参数：手绘风格无彩色下坠投影
  final bool raised;

  /// 覆盖描边色（默认主题墨线）
  final Color? strokeColor;

  /// 兼容参数：手绘风格无渐变
  final Gradient? gradient;

  /// 兼容参数：手绘风格无柔影
  final List<BoxShadow>? shadows;

  final double? borderWidth;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final r = radius ?? theme.radii.lg;
    final br = r.resolve(Directionality.maybeOf(context));

    return Container(
      width: width,
      height: height,
      padding: padding,
      alignment: alignment,
      constraints: constraints,
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: color ?? gradient?.colors.first ?? theme.surface,
        radius: br,
        stroke: strokeColor,
        strokeWidth: borderWidth ?? 1.8,
      ),
      child: child,
    );
  }
}
