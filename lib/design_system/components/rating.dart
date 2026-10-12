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
    // 空星淡墨：衬托实星颜色，与手绘纸面协调
    final empty = theme.textSub.withValues(alpha: 0.45);

    final stars = <Widget>[];
    for (var i = 0; i < max; i++) {
      final fraction = (value - i).clamp(0.0, 1.0);
      final star = DsIcon(DsIconKind.star, size: size, color: empty);
      final filledStar = DsIcon(DsIconKind.star, size: size, color: filled);
      final Widget cell;
      if (fraction >= 1) {
        cell = filledStar;
      } else if (fraction <= 0) {
        cell = star;
      } else {
        // 半星：底层空星 + 上层裁剪实星（裁剪与 child 画法无关）
        cell = Stack(
          children: [
            star,
            ClipRect(
              clipper: _FractionClipper(fraction),
              child: filledStar,
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
