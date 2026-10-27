import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';

/// 手绘列表项：leading + 标题/副标题 + 尾部信息，可点击
///
/// 半透明纸面 + 淡墨描边（透出页面背景），leading 图标顶部对齐，
/// 质感与 [DSListItemCard] 一致。
class DSListItem extends StatelessWidget {
  const DSListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.trailingText,
    this.onTap,
    this.showChevron = false,
    this.subtitleMaxLines,
  });

  final String title;
  final String? subtitle;

  /// 副标题最大行数，超出截断显示省略号；null 则不限制
  final int? subtitleMaxLines;
  final Widget? leading;
  final Widget? trailing;

  /// 简单尾部文字（如时间、状态）
  final String? trailingText;
  final VoidCallback? onTap;

  /// 是否显示右侧箭头
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: dsSketchDecoration(
            theme: theme,
            // 半透明纸面透出页面背景，与 DSListItemCard 一致
            fillColor: pressed
                ? theme.surfaceAlt.withValues(alpha: 0.6)
                : theme.surface.withValues(alpha: theme.isDark ? 0.5 : 0.65),
            radius: theme.radii.xl,
            stroke: theme.ink.withValues(alpha: 0.55),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: theme.spacing.md,
          ),
          child: Row(
            // leading 图标与首行标题顶部对齐
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: theme.spacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: DsTypography.body.copyWith(color: theme.text),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: subtitleMaxLines,
                        overflow:
                            subtitleMaxLines != null
                                ? TextOverflow.ellipsis
                                : null,
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
              if (showChevron) ...[
                SizedBox(width: theme.spacing.xs),
                DsIcon(DsIconKind.chevronRight, size: 16, color: theme.textSub),
              ],
            ],
          ),
        );
      },
    );
  }
}
