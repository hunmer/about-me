import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

/// 「插件商店上新」横幅：主色果冻条 + 标题 + 立即领取胶囊按钮
class JellyStoreBanner extends StatelessWidget {
  const JellyStoreBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel = '立即领取',
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    final banner = JellyBox(
      radius: theme.radii.xxl,
      color: theme.primary,
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.lg,
        vertical: theme.spacing.md,
      ),
      child: Row(
        children: [
          // 购物车插画位：半透明白圆 + 图标
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.onPrimary.withValues(alpha: 0.20),
            ),
            child: DsIcon(DsIconKind.cart, size: 22, color: theme.onPrimary),
          ),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.title.copyWith(
                    fontSize: 16,
                    color: theme.onPrimary,
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.label.copyWith(
                    fontSize: 10,
                    color: theme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          // 白色胶囊领取按钮
          Pressable(
            onPressed: onTap,
            semanticLabel: actionLabel,
            builder: (context, states) {
              final pressed = states.contains(WidgetState.pressed);
              return AnimatedScale(
                scale: pressed ? 0.94 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.spacing.md,
                    vertical: theme.spacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: theme.radii.pill,
                    border: Border.all(
                      color: theme.primary.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow:
                        pressed
                            ? theme.pressedShadow(theme.primary, height: 3)
                            : theme.jellyShadow(theme.primary, height: 3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel,
                        style: DsTypography.label.copyWith(
                          fontSize: 11,
                          color: theme.primaryText,
                        ),
                      ),
                      SizedBox(width: theme.spacing.xs),
                      DsIcon(
                        DsIconKind.chevronRight,
                        size: 10,
                        color: theme.primaryText,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(width: theme.spacing.md),
          DsIcon(DsIconKind.gift, size: 30, color: theme.warning),
        ],
      ),
    );

    if (onTap == null) return banner;
    return Pressable(
      onPressed: onTap,
      builder:
          (context, states) =>
              states.contains(WidgetState.pressed)
                  ? Opacity(opacity: 0.9, child: banner)
                  : banner,
    );
  }
}
