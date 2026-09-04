import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 果冻标签（Chip）：默认 / 选中 / 可删除
class DSChip extends StatelessWidget {
  const DSChip({
    super.key,
    required this.label,
    this.icon,
    this.badge,
    this.selected = false,
    this.onSelected,
    this.onDeleted,
  });

  final String label;

  /// 可选前缀图标
  final DsIconKind? icon;

  /// 角标文本（如过滤项当前值的简写），跟随选中态着色
  final String? badge;

  /// 是否处于选中态（果冻高亮）
  final bool selected;

  /// 点击切换选中；为 null 时非交互
  final ValueChanged<bool>? onSelected;

  /// 删除回调；非 null 时显示 × 按钮
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final interactive = onSelected != null;

    return Pressable(
      onPressed: interactive ? () => onSelected?.call(!selected) : null,
      semanticLabel: label,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        final Widget content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              DsIcon(
                icon!,
                size: 14,
                color:
                    selected
                        ? (onSelected == null ? theme.surface : theme.onPrimary)
                        : theme.textSub,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: DsTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color:
                    selected
                        ? (onSelected == null ? theme.surface : theme.onPrimary)
                        : theme.textSub,
              ),
            ),
            if (badge != null && badge!.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color:
                      selected
                          ? theme.onPrimary.withValues(alpha: 0.25)
                          : theme.surfaceAlt,
                  borderRadius: theme.radii.pill,
                ),
                child: Text(
                  badge!,
                  style: DsTypography.label.copyWith(
                    color: selected ? theme.onPrimary : theme.textSub,
                  ),
                ),
              ),
            ],
            if (onDeleted != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDeleted,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color:
                        selected
                            ? theme.onPrimary.withValues(alpha: 0.25)
                            : theme.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: DsIcon(
                    DsIconKind.close,
                    size: 10,
                    color: selected ? theme.onPrimary : theme.textSub,
                  ),
                ),
              ),
            ],
          ],
        );

        if (selected) {
          return JellyBox(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            radius: theme.radii.pill,
            color: onSelected == null ? theme.disabled : theme.primary,
            raised: !pressed,
            child: content,
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: theme.radii.pill,
            border: Border.all(
              color: theme.textSub.withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: content,
        );
      },
    );
  }
}
