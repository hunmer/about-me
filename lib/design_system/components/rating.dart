import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import 'icons.dart';

/// 星级评分：支持半星精度，可交互
class DSRating extends StatelessWidget {
  const DSRating({
    super.key,
    required this.value,
    this.onChanged,
    this.max = 5,
    this.size = 30,
    this.color,
  });

  /// 0.0 ~ [max]
  final double value;
  final int max;
  final double size;

  /// 为 null 时只读
  final ValueChanged<double>? onChanged;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final filled = color ?? theme.warning;
    final empty = theme.surfaceAlt;

    final stars = <Widget>[];
    for (var i = 0; i < max; i++) {
      final fraction = (value - i).clamp(0.0, 1.0);
      final star = DsIcon(DsIconKind.star, size: size, color: empty);
      // 实星叠加顶部透亮光泽（ShaderMask 只作用于星星像素）
      final glossyFilled = _StarGloss(
        isDark: theme.isDark,
        child: DsIcon(DsIconKind.star, size: size, color: filled),
      );
      final Widget cell;
      if (fraction >= 1) {
        cell = glossyFilled;
      } else if (fraction <= 0) {
        cell = star;
      } else {
        // 半星：底层空星 + 上层裁剪实星
        cell = Stack(
          children: [
            star,
            ClipRect(
              clipper: _FractionClipper(fraction),
              child: glossyFilled,
            ),
          ],
        );
      }

      if (onChanged != null) {
        final index = i;
        stars.add(
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged!(index + 1.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: cell,
            ),
          ),
        );
      } else {
        stars.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: cell,
        ));
      }
    }

    return Semantics(
      label: '$value / $max',
      child: MouseRegion(
        cursor: onChanged != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        child: Row(mainAxisSize: MainAxisSize.min, children: stars),
      ),
    );
  }
}

class _FractionClipper extends CustomClipper<Rect> {
  const _FractionClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_FractionClipper oldDelegate) =>
      oldDelegate.fraction != fraction;
}

/// 星星的水晶光泽：ShaderMask 沿星形像素叠加顶部透亮渐变
/// （srcATop 只在 child 非透明区域着色，不会糊到背景上）
class _StarGloss extends StatelessWidget {
  const _StarGloss({required this.isDark, required this.child});

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFFFFF).withValues(alpha: isDark ? 0.25 : 0.5),
          const Color(0xFFFFFFFF).withValues(alpha: isDark ? 0.06 : 0.15),
          const Color(0x00000000),
        ],
        stops: const [0.0, 0.45, 0.75],
      ).createShader(rect),
      child: child,
    );
  }
}
