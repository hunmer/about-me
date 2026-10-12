import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// 手绘页面指示器：当前页为主色胶囊 + 墨描边，其余为淡墨圆点
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
            // 当前页略高：rough 引擎墨迹内收数像素，需要足够高度画胶囊
            height: i == index ? 12 : 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: i == index
                ? dsSketchDecoration(
                    theme: theme,
                    fillColor: active,
                    radius: theme.radii.pill,
                    strokeWidth: 1.2,
                  )
                : BoxDecoration(
                    color: theme.ink.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
          ),
      ],
    );
  }
}
