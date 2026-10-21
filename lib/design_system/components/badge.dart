import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/motion.dart';
import '../tokens/typography.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 手绘角标：小胶囊标签（如「新功能」）
class DSBadge extends StatelessWidget {
  const DSBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.autoColor = false,
    this.fontSize,
  });

  final String label;
  final Color? color;
  final Color? textColor;

  /// 开启后按 [label] 文本哈希生成浅色底 + 同色系深色文字
  /// （显式传入 [color]/[textColor] 时优先使用显式值）
  final bool autoColor;

  /// 覆盖字号（小尺寸场景）
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final Color base;
    final Color fg;
    if (autoColor && color == null) {
      base = _colorFromText(label, lightness: 0.9, saturation: 0.45);
      fg = _colorFromText(label, lightness: 0.32, saturation: 0.5);
    } else {
      base = color ?? theme.primary;
      fg = textColor ?? theme.onPrimary;
    }
    var style = DsTypography.label.copyWith(color: fg);
    if (fontSize != null) {
      style = style.copyWith(fontSize: fontSize);
    }
    // 内容出现/变化时 pop-in：0.6 → 1 弹性放大 + 淡入。
    // key 跟随 label——文本变化即重挂重播；减弱动画时直接静态显示。
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('ds-badge-pop:$label'),
      tween: Tween<double>(begin: 0.6, end: 1),
      duration: context.dsAnimationsDisabled ? Duration.zero : DsMotion.base,
      curve: DsMotion.enter,
      builder: (context, progress, child) => Opacity(
        opacity: progress.clamp(0.0, 1.0),
        child: Transform.scale(scale: progress, child: child),
      ),
      child: JellyBox(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        radius: theme.radii.pill,
        color: base,
        raised: false,
        child: Text(label, style: style),
      ),
    );
  }

  /// 文本哈希 → 稳定色相的 HSL 颜色（同文本恒同色）
  static Color _colorFromText(
    String text, {
    required double lightness,
    required double saturation,
  }) {
    var hash = 0;
    for (final unit in text.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
  }
}

/// 图标数字气泡：图标右上角带计数角标（如铃铛 + 3）
class DSIconBadge extends StatelessWidget {
  const DSIconBadge({
    super.key,
    required this.icon,
    this.count = 0,
    this.size = 30,
    this.iconColor,
    this.badgeColor,
  });

  final DsIconKind icon;
  final int count;
  final double size;
  final Color? iconColor;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: DsIcon(
              icon,
              size: size,
              color: iconColor ?? theme.primary,
            ),
          ),
          if (count > 0)
            Positioned(
              right: -2,
              top: -2,
              // 计数出现/变化时 pop-in：0.6 → 1 弹性放大 + 淡入。
              // key 跟随 count——数值变化即重挂重播；减弱动画时静态显示。
              child: TweenAnimationBuilder<double>(
                key: ValueKey<int>(count),
                tween: Tween<double>(begin: 0.6, end: 1),
                duration: context.dsAnimationsDisabled
                    ? Duration.zero
                    : DsMotion.base,
                curve: DsMotion.enter,
                builder: (context, progress, child) => Opacity(
                  opacity: progress.clamp(0.0, 1.0),
                  child: Transform.scale(scale: progress, child: child),
                ),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  // 计数气泡：<10 画手绘正圆，否则画手绘胶囊
                  decoration: dsSketchDecoration(
                    theme: theme,
                    circle: count < 10,
                    radius: count < 10 ? null : BorderRadius.circular(9),
                    fillColor: badgeColor ?? theme.danger,
                    stroke: theme.stroke,
                    strokeWidth: 1.6,
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: DsTypography.label.copyWith(
                      fontSize: 10,
                      color: theme.onDanger,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
