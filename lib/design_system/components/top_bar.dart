import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 果冻顶部导航栏：胶囊形，返回 + 标题 + 菜单
class DSTopBar extends StatelessWidget {
  const DSTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.onMenu,
    this.actions,
  });

  final String title;

  /// 默认 Navigator.maybePop；为 null 时隐藏返回按钮
  final VoidCallback? onBack;
  final VoidCallback? onMenu;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return JellyBox(
      radius: theme.radii.pill,
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.sm,
      ),
      child: Row(
        children: [
          _BarIcon(
            icon: DsIconKind.chevronLeft,
            onTap: onBack ?? () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: DsTypography.heading.copyWith(color: theme.text),
            ),
          ),
          _BarIcon(
            icon: DsIconKind.more,
            onTap: onMenu,
          ),
        ],
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({required this.icon, required this.onTap});

  final DsIconKind icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pressed
                ? theme.surfaceAlt
                : hovered
                    ? theme.surfaceAlt.withValues(alpha: 0.6)
                    : null,
          ),
          child: DsIcon(icon, size: 20, color: theme.text),
        );
      },
    );
  }
}
