import 'package:flutter/material.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';

/// 果冻列表卡片：标题/副标题 + 尾部信息，浅色底 + 左上角图标水印
///
/// 卡片内部为 [iconColor] 调亮的浅色底，描边取 [iconColor] 原色。
/// 标志（[icon] 或 [leading]）放大后贴在卡片左上角作为背景水印，
/// 置于内容层之下，超出圆角的部分被裁剪。
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

  /// 左上角水印图标（与 [leading] 二选一）
  final DsIconKind? icon;

  /// 左上角水印自定义内容（如 Material 图标），优先于 [icon]
  final Widget? leading;

  final String? subtitle;

  /// 卡片底色（默认主题主色）
  final Color? iconColor;

  final Widget? trailing;

  /// 简单尾部文字（如时间、状态）
  final String? trailingText;

  final VoidCallback? onTap;

  /// 水印图标边长
  static const double _watermarkSize = 96;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final hasWatermark = leading != null || icon != null;
    final radius = theme.radii.xl;
    final baseColor = iconColor ?? theme.primary;
    // 内部背景为底色调亮的浅色，与 Timeline 消息卡片一致
    final cardColor = Color.lerp(baseColor, Colors.white, 0.85);

    final card = ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          // 浅色底 + 原色描边
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: radius,
                border: Border.all(color: baseColor, width: 1.8),
              ),
            ),
          ),
          // 左上角图标水印：放大贴角，处于内容层之下，溢出被裁剪；
          // 底色已浅，水印用底色低透明度保持可见
          if (hasWatermark)
            Positioned(
              left: 0,
              top: 0,
              child: SizedBox(
                width: _watermarkSize,
                height: _watermarkSize,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Opacity(
                    opacity: 0.15,
                    child: IconTheme.merge(
                      data: IconThemeData(color: baseColor),
                      child: leading ?? DsIcon(icon!, color: baseColor),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(theme.spacing.md),
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
