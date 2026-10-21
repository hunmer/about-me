import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/shadows.dart';

/// 手绘墨盒：整个组件库的容器基底（前身「果冻容器」）
///
/// 手绘化后由 skribble rough 引擎绘制：
/// - 传入 [color]：彩色涂色块（纯色实底 + 墨线描边）
/// - 不传 [color]：纸面（surface 实底 + 墨线描边）
/// - [radius] 的 pill（999）会被 rough 引擎自动钳制成胶囊/正圆
/// - [shadow]：手绘错位阴影——底层同形状偏移复制（实体、零模糊），
///   呈现「贴纸/游戏按键」的厚度感，默认关闭
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
    this.shadow = false,
    this.shadowOffset = DsHandShadow.regular,
  });

  final Widget? child;
  final Color? color;
  final BorderRadiusGeometry? radius;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;
  final BoxConstraints? constraints;

  /// 兼容参数：手绘风格无彩色下坠投影（错位阴影改用 [shadow]）
  final bool raised;

  /// 覆盖描边色（默认主题墨线）
  final Color? strokeColor;

  /// 兼容参数：手绘风格无渐变
  final Gradient? gradient;

  /// 兼容参数：手绘风格无柔影
  final List<BoxShadow>? shadows;

  final double? borderWidth;

  /// 手绘错位阴影：底层放一个同形状、偏移 [shadowOffset] 的实色rough副本
  final bool shadow;

  /// 阴影偏移量（默认 [DsHandShadow.regular]；按压时可动态切到小偏移）
  final Offset shadowOffset;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final r = radius ?? theme.radii.lg;
    final br = r.resolve(Directionality.maybeOf(context));

    Widget box = Container(
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
    if (!shadow) return box;

    // 实体错位副本：浅色下向黑混合（纸叠纸的厚度），深色下退化为淡墨影
    final fill = color ?? gradient?.colors.first ?? theme.surface;
    final shadowColor = theme.isDark
        ? theme.ink.withValues(alpha: 0.18)
        : fill.mixBlack(0.22);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Transform.translate(
              offset: shadowOffset,
              child: DecoratedBox(
                decoration: dsSketchDecoration(
                  theme: theme,
                  fillColor: shadowColor,
                  radius: br,
                  strokeWidth: 0.1,
                ),
              ),
            ),
          ),
        ),
        box,
      ],
    );
  }
}
