import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import 'jelly_box.dart';

/// 果冻卡片：白色面板 + 软阴影，可点击
class DSCard extends StatelessWidget {
  const DSCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.radius,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? radius;

  /// 覆盖面板底色（默认白表面）
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final card = JellyBox(
      radius: radius ?? theme.radii.xl,
      color: color,
      padding: padding ?? EdgeInsets.all(theme.spacing.lg),
      child: child,
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
