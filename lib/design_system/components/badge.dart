import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 手绘角标：小胶囊标签（如「新功能」）
class DSBadge extends StatelessWidget {
  const DSBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
  });

  final String label;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final base = color ?? theme.primary;
    return JellyBox(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      radius: theme.radii.pill,
      color: base,
      raised: false,
      child: Text(
        label,
        style: DsTypography.label.copyWith(
          color: textColor ?? theme.onPrimary,
        ),
      ),
    );
  }
}

/// 图标数字气泡：图标右上角带计数角标（如铃铛 + 3）
class DSIconBadge extends StatelessWidget {
  const DSIconBadge({
    super.key,
    required this.icon,
    this.count = 0,
    this.size = 30,
    this.iconColor,
    this.badgeColor,
  });

  final DsIconKind icon;
  final int count;
  final double size;
  final Color? iconColor;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: DsIcon(
              icon,
              size: size,
              color: iconColor ?? theme.primary,
            ),
          ),
          if (count > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                // 计数气泡：<10 画手绘正圆，否则画手绘胶囊
                decoration: dsSketchDecoration(
                  theme: theme,
                  circle: count < 10,
                  radius: count < 10 ? null : BorderRadius.circular(9),
                  fillColor: badgeColor ?? theme.danger,
                  stroke: theme.stroke,
                  strokeWidth: 1.6,
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: DsTypography.label.copyWith(
                    fontSize: 10,
                    color: theme.onDanger,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
