import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 手绘顶部导航栏：胶囊形，返回 + 标题 + 菜单
class DSTopBar extends StatelessWidget {
  const DSTopBar({
    super.key,
    required this.title,
    this.center,
    this.onBack,
    this.onMenu,
    this.actions,
  });

  final String title;

  /// 自定义中部内容；非 null 时替代标题文本展示（title 仅保留语义）
  final Widget? center;

  /// 为 null 时隐藏返回按钮
  final VoidCallback? onBack;
  final VoidCallback? onMenu;

  /// 尾部附加动作（跟随菜单按钮之后）
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
          if (onBack != null)
            _BarIcon(icon: DsIconKind.chevronLeft, onTap: onBack)
          else
            const SizedBox(width: 36, height: 36),
          Expanded(
            child:
                center ??
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: DsTypography.heading.copyWith(color: theme.text),
                ),
          ),
          // 尾部：菜单按钮（如有）+ 自定义 actions；
          // 都没有时留与返回钮等宽的占位，保证标题恒居中
          if (onMenu != null) _BarIcon(icon: DsIconKind.more, onTap: onMenu),
          if (actions != null && actions!.isNotEmpty)
            Row(mainAxisSize: MainAxisSize.min, children: actions!),
          if (onMenu == null && (actions == null || actions!.isEmpty))
            const SizedBox(width: 36, height: 36),
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
