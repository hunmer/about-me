import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// 果冻页面指示器：当前页为长胶囊，其余为圆点
class DSPageIndicator extends StatelessWidget {
  const DSPageIndicator({
    super.key,
    required this.count,
    required this.index,
    this.color,
  });

  final int count;
  final int index;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final active = color ?? theme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: i == index ? 26 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == index
                  ? active
                  : theme.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
              boxShadow: i == index
                  ? [
                      BoxShadow(
                        color: active.withValues(alpha: 0.4),
                        offset: const Offset(0, 2),
                        blurRadius: 5,
                      ),
                    ]
                  : null,
            ),
          ),
      ],
    );
  }
}
