import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart';

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
    this.accent,
    this.pattern = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? radius;

  /// 覆盖面板底色（默认纸面）
  final Color? color;

  /// 强调色：非空时整卡染成该色调——底色 accent.mixWhite(0.85)、
  /// 墨线描边 accent、排线 accent 低透明度（深色 0.30 / 浅色 0.22）。
  /// 与 [color] 同时传入时底色以 [color] 为准
  final Color? accent;

  /// 波点底纹：true 时透传 DsSketchPanel 的 polka 壁纸；
  /// 有 [accent] 时波点取 accent 低透明度，否则用面板默认墨点。
  /// 可与 [accent] 组合成「彩色波点卡」
  final bool pattern;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // 环境描画动画（外层 WiredDraw 注入）；null = 已画完
    final progress = WiredDrawTransition.progressOf(context);
    final card = DsSketchPanel(
      theme: theme,
      radius:
          radius?.resolve(Directionality.maybeOf(context)) ?? theme.radii.xl,
      fillColor: color ?? accent?.mixWhite(0.85),
      stroke: accent,
      hachureColor: accent?.withValues(alpha: theme.isDark ? 0.30 : 0.22),
      polka: pattern,
      polkaColor: accent?.withValues(alpha: theme.isDark ? 0.20 : 0.13),
      padding: padding ?? EdgeInsets.all(theme.spacing.lg),
      progress: progress,
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
