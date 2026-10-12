import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';

/// 手绘卡片：纸底 + 淡排线 + 墨线框，可点击
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

  /// 覆盖面板底色（默认纸面）
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final card = DsSketchPanel(
      theme: theme,
      radius:
          radius?.resolve(Directionality.maybeOf(context)) ??
          theme.radii.xl,
      fillColor: color,
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
