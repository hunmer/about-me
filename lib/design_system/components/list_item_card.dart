import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';

/// 果冻列表卡片：标题/副标题 + 尾部信息，左上角带半圆标志
///
/// 标志（[icon] 或 [leading]）是从顶边垂下的实心半圆，叠在卡片
/// 左上角之上，不作为行内元素占位——内容区仅为其让出左侧间距。
/// 面板为半透明描边圆角面板，透出页面背景实现融合。
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

  /// 左上角标志图标（与 [leading] 二选一）
  final DsIconKind? icon;

  /// 左上角标志自定义内容（如 Material 图标），优先于 [icon]
  final Widget? leading;

  final String? subtitle;

  /// 标志半圆填充色（默认主题主色）
  final Color? iconColor;

  final Widget? trailing;

  /// 简单尾部文字（如时间、状态）
  final String? trailingText;

  final VoidCallback? onTap;

  /// 半圆标志宽度（高度为宽度一半）
  static const double _badgeWidth = 44;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final hasBadge = leading != null || icon != null;
    final radius = theme.radii.xl;

    final card = ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              // 半透明表面透出页面背景，卡片自然融入
              color: theme.surface.withValues(alpha: theme.isDark ? 0.5 : 0.65),
              borderRadius: radius,
              border: Border.all(
                color: theme.primary.withValues(
                  alpha: theme.isDark ? 0.6 : 0.45,
                ),
                width: 1.8,
              ),
            ),
            // 内容区为左上角半圆标志让出左侧间距
            padding: EdgeInsets.only(
              left: hasBadge
                  ? _badgeWidth + theme.spacing.md
                  : theme.spacing.md,
              top: theme.spacing.md,
              right: theme.spacing.md,
              bottom: theme.spacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
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
          ),
          // 左上角半圆标志：叠在面板之上，不占行内布局
          if (hasBadge)
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: _badgeWidth,
                height: _badgeWidth / 2,
                decoration: BoxDecoration(
                  color: iconColor ?? theme.primary,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(_badgeWidth / 2),
                  ),
                ),
                alignment: Alignment.center,
                child:
                    leading ?? DsIcon(icon!, size: 16, color: theme.onPrimary),
              ),
            ),
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
