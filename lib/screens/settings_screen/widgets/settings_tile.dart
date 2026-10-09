import 'package:flutter/material.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 参考稿风格设置条目：粉彩圆形图标 + 标题/副标题 + 尾部控件 + 右箭头
///
/// 扁平无边框，按压时以圆角高亮反馈；
/// 图标底色为 [iconColor] 的低透明度粉彩背景，随亮暗模式调整。
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showChevron = true,
    this.onTap,
  });

  final IconData icon;

  /// 图标主色（圆形底色按此派生）
  final Color iconColor;
  final String title;
  final String? subtitle;

  /// 尾部控件（如开关、状态图标）
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: pressed
                ? theme.text.withValues(alpha: theme.isDark ? 0.08 : 0.05)
                : Colors.transparent,
            borderRadius: theme.radii.lg,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(
                    alpha: theme.isDark ? 0.25 : 0.15,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: theme.isDark ? iconColor.mixWhite(0.3) : iconColor,
                ),
              ),
              SizedBox(width: theme.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: DsTypography.heading.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.text,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: theme.spacing.sm),
                trailing!,
              ],
              if (showChevron) ...[
                SizedBox(width: theme.spacing.xs),
                DsIcon(
                  DsIconKind.chevronRight,
                  size: 16,
                  color: theme.textSub,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
