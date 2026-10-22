import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';

/// 手绘列表卡片：标题/副标题 + 尾部信息，浅色底 + 右上角图标水印
///
/// 卡片内部为 [iconColor] 调亮的浅色底，描边取 [iconColor] 原色手绘墨线。
/// 标志（[icon] 或 [leading]）放大后贴在卡片右上角作为背景水印，
/// 置于内容层之下，超出圆角的部分被裁剪。
class DSListItemCard extends StatelessWidget {
  const DSListItemCard({
    super.key,
    required this.title,
    this.titleSuffix,
    this.icon,
    this.leading,
    this.subtitle,
    this.onSubtitleTap,
    this.iconColor,
    this.trailing,
    this.trailingText,
    this.onTap,
  });

  final String title;

  /// 标题右侧附加内容（如状态圆点）
  final Widget? titleSuffix;

  /// 右上角水印图标（与 [leading] 二选一）
  final DsIconKind? icon;

  /// 右上角水印自定义内容（如 Material 图标），优先于 [icon]
  final Widget? leading;

  final String? subtitle;

  /// 副标题点击回调：设置后副标题可点击（主色调 + 右箭头提示）
  final VoidCallback? onSubtitleTap;

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
    // 环境描画动画（外层 WiredDraw 注入）；null = 已画完
    final progress = WiredDrawTransition.progressOf(context);
    final hasWatermark = leading != null || icon != null;
    final radius = theme.radii.xl;
    final baseColor = iconColor ?? theme.primary;
    // 内部背景为底色调亮的浅色，与 Timeline 消息卡片一致
    final cardColor = Color.lerp(baseColor, Colors.white, 0.85);

    final card = ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          // 浅色底 + 原色手绘描边
          Positioned.fill(
            child: DecoratedBox(
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: cardColor,
                stroke: baseColor,
                radius: radius,
                progress: progress,
              ),
            ),
          ),
          // 右上角图标水印：放大贴角，处于内容层之下；
          // 底色已浅，水印用底色低透明度保持可见。
          // 边长随卡片高度收缩，不超出卡片高度
          if (hasWatermark)
            Positioned(
              right: 0,
              top: 0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = math.min(
                    _watermarkSize,
                    constraints.maxHeight,
                  );
                  return SizedBox(
                    width: size,
                    height: size,
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
                  );
                },
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: DsTypography.heading.copyWith(
                                color: theme.text,
                              ),
                            ),
                          ),
                          if (titleSuffix != null) ...[
                            const SizedBox(width: 6),
                            titleSuffix!,
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        if (onSubtitleTap != null)
                          // 可点击副标题：渲染为小圆角按钮（淡主色底 + 墨线描边）
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onSubtitleTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: dsSketchDecoration(
                                theme: theme,
                                fillColor: theme.primary.withValues(alpha: 0.12),
                                stroke: theme.primary.withValues(alpha: 0.55),
                                strokeWidth: 1.2,
                                radius: theme.radii.pill,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      subtitle!,
                                      style: DsTypography.caption.copyWith(
                                        color: theme.primary,
                                      ),
                                    ),
                                  ),
                                  DsIcon(
                                    DsIconKind.chevronRight,
                                    size: 12,
                                    color: theme.primary,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
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
