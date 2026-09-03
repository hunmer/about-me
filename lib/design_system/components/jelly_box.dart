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
    Decoration? foreground;
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
      // 彩色果冻件（水晶质感）：多段渐变 + 浅色描边 + 顶部高光罩层
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
          color: strokeColor ?? theme.jellyRim(base),
          width: borderWidth ?? 1.5,
        ),
        boxShadow: shadows ?? (raised ? theme.jellyShadow(base) : null),
      );
      // 水晶高光罩在表层（含 child 之上）：弧形玻璃罩 + 内圈亮边 + 右下回光
      foreground = JellyGlossDecoration(radius: r, isDark: theme.isDark);
    }

    return Container(
      width: width,
      height: height,
      padding: padding,
      alignment: alignment,
      constraints: constraints,
      decoration: decoration,
      foregroundDecoration: foreground,
      child: child,
    );
  }
}

/// 水晶高光装饰：绘制在果冻件表层（child 之上）
///
/// 对应设计稿的玻璃/水晶反光，三层叠加：
/// 1. 顶部弧形「玻璃罩」高光带（下缘为弧线，水晶感的关键）
/// 2. 内侧亮白描边（贴合外形的内圈亮边）
/// 3. 右下角柔和回光（环境光底部反射）
///
/// [JellyBox] 彩色件自动带这层效果；不用 JellyBox 的组件
/// （switch 轨道 / slider 进度 / 底部导航选中块等）可直接把它
/// 挂到 Container 的 `foregroundDecoration` 上复用同款质感。
///
/// 注：曾加过左上角点状高光斑（RadialGradient），但在宽扁按钮上
/// 会被拉成椭圆形白斑、观感像污渍投影，已移除——点状高光需要
/// 接近正圆的画布才好看，不适合通用罩层。
class JellyGlossDecoration extends Decoration {
  const JellyGlossDecoration({required this.radius, required this.isDark});

  final BorderRadiusGeometry radius;
  final bool isDark;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _JellyGlossPainter(this);
}

class _JellyGlossPainter extends BoxPainter {
  _JellyGlossPainter(this._decoration);

  final JellyGlossDecoration _decoration;

  static const Color _white = Color(0xFFFFFFFF);
  static const Color _clear = Color(0x00000000);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final rect = offset & size;
    final rrect =
        _decoration.radius.resolve(configuration.textDirection).toRRect(rect);
    final dark = _decoration.isDark;

    canvas.save();
    canvas.clipRRect(rrect);

    // 内缩一圈，高光与内描边都贴在外描边内侧
    final inner = rrect.deflate(2.5);

    // 1. 顶部弧形「玻璃罩」高光带：高度约一半，下缘用椭圆角拉出弧线
    final glossH = rect.height * 0.52;
    final glossRect = Rect.fromLTRB(
      inner.left,
      inner.top,
      inner.right,
      inner.top + glossH,
    );
    final domeY = glossH * 0.6;
    final glossRRect = RRect.fromRectAndCorners(
      glossRect,
      topLeft: inner.tlRadius,
      topRight: inner.trRadius,
      bottomLeft: Radius.elliptical(glossRect.width / 2, domeY),
      bottomRight: Radius.elliptical(glossRect.width / 2, domeY),
    );
    canvas.drawRRect(
      glossRRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _white.withValues(alpha: dark ? 0.30 : 0.60),
            _white.withValues(alpha: dark ? 0.12 : 0.28),
            _clear,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(glossRect),
    );

    // 2. 内侧亮白描边（上亮下弱：先整圈弱亮，再叠加顶部半圈强亮）
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _white.withValues(alpha: dark ? 0.20 : 0.45),
    );
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(
        rect.left, rect.top, rect.right, rect.top + rect.height * 0.45));
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _white.withValues(alpha: dark ? 0.30 : 0.55),
    );
    canvas.restore();

    // 3. 右下角柔和回光
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.8, 0.85),
          radius: 0.65,
          colors: [
            _white.withValues(alpha: dark ? 0.08 : 0.18),
            _clear,
          ],
          stops: const [0.0, 0.7],
        ).createShader(rect),
    );

    canvas.restore();
  }
}
