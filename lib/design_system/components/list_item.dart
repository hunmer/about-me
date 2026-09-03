import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 果冻列表项：leading + 标题/副标题 + 尾部信息，可点击
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
  });

  final String title;
  final String? subtitle;
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
        return JellyBox(
          radius: theme.radii.lg,
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: theme.spacing.md,
          ),
          raised: false,
          color: pressed ? theme.surfaceAlt.withValues(alpha: 0.6) : null,
          child: Row(
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
                      style:
                          DsTypography.body.copyWith(color: theme.text),
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
                  style: DsTypography.caption.copyWith(
                    color: theme.textSub,
                  ),
                ),
              ],
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
