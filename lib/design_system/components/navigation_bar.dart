import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 底部导航项
class DSNavItem {
  const DSNavItem({
    required this.icon,
    required this.label,
    this.showBadge = false,
  });

  final DsIconKind icon;
  final String label;

  /// 图标右上角小红点
  final bool showBadge;
}

/// 果冻底部导航栏：选中项为凸起的果冻方块
class DSBottomNavigation extends StatelessWidget {
  const DSBottomNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<DSNavItem> items;
  final int currentIndex;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return JellyBox(
      radius: theme.radii.xxl,
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.sm,
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _NavItemView(
                item: items[i],
                selected: i == currentIndex,
                onTap: onTap == null ? null : () => onTap!(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItemView extends StatelessWidget {
  const _NavItemView({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DSNavItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    final icon = selected
        ? DsIcon(item.icon, size: 22, color: theme.onPrimary)
        : DsIcon(item.icon, size: 22, color: theme.textSub);

    return Pressable(
      onPressed: onTap,
      semanticLabel: item.label,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 选中项：凸起果冻方块（带果冻投影）
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 46,
                height: selected ? 46 : 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: theme.jellyGradient(theme.primary),
                          stops: theme.jellyStops,
                        )
                      : null,
                  borderRadius: theme.radii.lg,
                  border: selected
                      ? Border.all(color: theme.jellyRim(theme.primary), width: 1.2)
                      : null,
                  boxShadow: selected && !pressed
                      ? theme.jellyShadow(theme.primary, height: 4)
                      : null,
                ),
                // 选中块叠加水晶玻璃罩
                foregroundDecoration: selected
                    ? JellyGlossDecoration(
                        radius: theme.radii.lg, isDark: theme.isDark)
                    : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    icon,
                    if (item.showBadge)
                      Positioned(
                        right: -4,
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.danger,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.stroke, width: 1.4),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                item.label,
                style: DsTypography.label.copyWith(
                  fontSize: 12,
                  color: selected ? theme.primaryText : theme.textSub,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
