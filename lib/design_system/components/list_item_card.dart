import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 果冻列表卡片：左上角图标 + 标题/副标题 + 尾部信息
///
/// 与 [DSListItem] 的区别：卡片式布局——图标是固定在左上角的彩色
/// 果冻小块；面板为带描边的半透明表面，透出页面背景实现融合。
class DSListItemCard extends StatelessWidget {
  const DSListItemCard({
    super.key,
    required this.title,
    this.icon,
    this.leading,
    this.subtitle,
    this.iconColor,
    this.trailing,
    this.trailingText,
    this.onTap,
  });

  final String title;

  /// 左上角图标（与 [leading] 二选一）
  final DsIconKind? icon;

  /// 左上角自定义内容（如头像、Material 图标块），优先于 [icon]
  final Widget? leading;

  /// 图标果冻块基色（默认主题主色）
  final Color? iconColor;

  final String? subtitle;

  final Widget? trailing;

  /// 简单尾部文字（如时间、状态）
  final String? trailingText;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    final card = Container(
      decoration: BoxDecoration(
        // 半透明表面透出页面背景，卡片自然融入
        color: theme.surface.withValues(alpha: theme.isDark ? 0.5 : 0.65),
        borderRadius: theme.radii.lg,
        border: Border.all(
          color: theme.stroke,
          width: theme.isDark ? 1 : 1.4,
        ),
      ),
      padding: EdgeInsets.all(theme.spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null || icon != null) ...[
            leading
                ?? JellyBox(
                    width: 36,
                    height: 36,
                    radius: theme.radii.md,
                    color: iconColor ?? theme.primary,
                    alignment: Alignment.center,
                    child: DsIcon(icon!, size: 18, color: theme.onPrimary),
                  ),
            SizedBox(width: theme.spacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: DsTypography.heading.copyWith(color: theme.text),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ],
              ],
            ),
          ),
          if (trailingText != null) ...[
            SizedBox(width: theme.spacing.sm),
            Text(
              trailingText!,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
          if (trailing != null) ...[
            SizedBox(width: theme.spacing.sm),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return Pressable(
      onPressed: onTap,
      builder: (context, states) => states.contains(WidgetState.pressed)
          ? Opacity(opacity: 0.85, child: card)
          : card,
    );
  }
}
