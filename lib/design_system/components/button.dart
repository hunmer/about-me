import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 按钮变体（对标 shadcn：primary / secondary / outline / ghost / destructive）
enum DSButtonVariant { primary, secondary, outline, ghost, destructive }

/// 按钮尺寸
enum DSButtonSize { sm, md, lg }

/// 果冻按钮
///
/// 颜色/圆角/阴影全部来自 [AppThemeData]；按压、悬停、禁用态
/// 通过 [Pressable] 的状态回调切换。
class DSButton extends StatelessWidget {
  const DSButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = DSButtonVariant.primary,
    this.size = DSButtonSize.md,
    this.icon,
    this.expand = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final DSButtonVariant variant;
  final DSButtonSize size;
  final DsIconKind? icon;

  /// 是否占满可用宽度
  final bool expand;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    final double height;
    final double padH;
    final TextStyle font;
    switch (size) {
      case DSButtonSize.sm:
        height = 36;
        padH = theme.spacing.md;
        font = DsTypography.button.copyWith(fontSize: 13);
      case DSButtonSize.md:
        height = 46;
        padH = theme.spacing.xl;
        font = DsTypography.button;
      case DSButtonSize.lg:
        height = 56;
        padH = theme.spacing.xxl;
        font = DsTypography.button.copyWith(fontSize: 17);
    }

    return Pressable(
      onPressed: onPressed,
      semanticLabel: semanticLabel ?? label,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        final hovered = states.contains(WidgetState.hovered);
        final disabled = states.contains(WidgetState.disabled);

        Color base;
        Color labelColor;
        switch (variant) {
          case DSButtonVariant.primary:
            base = theme.primary;
            labelColor = theme.onPrimary;
          case DSButtonVariant.secondary:
            base = theme.secondary;
            labelColor = theme.onSecondary;
          case DSButtonVariant.destructive:
            base = theme.danger;
            labelColor = theme.onDanger;
          case DSButtonVariant.outline:
            base = theme.surface;
            labelColor = theme.primaryText;
          case DSButtonVariant.ghost:
            base = DsColors.transparent;
            labelColor = theme.primaryText;
        }
        if (disabled) {
          base = theme.disabled;
          labelColor = theme.surface;
        }
        if (pressed) {
          base = base.mixBlack(0.08);
        } else if (hovered && variant != DSButtonVariant.ghost) {
          base = base.mixWhite(0.06);
        }

        Widget content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              DsIcon(icon!, size: font.fontSize! + 5, color: labelColor),
              SizedBox(width: theme.spacing.sm),
            ],
            Text(label, style: font.copyWith(color: labelColor)),
          ],
        );

        Widget box;
        if (variant == DSButtonVariant.ghost) {
          box = AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: height,
            padding: EdgeInsets.symmetric(horizontal: padH),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hovered && !disabled
                  ? theme.surfaceAlt.withValues(alpha: 0.7)
                  : DsColors.transparent,
              borderRadius: theme.radii.lg,
            ),
            child: content,
          );
        } else {
          box = JellyBox(
            radius: theme.radii.lg,
            height: height,
            padding: EdgeInsets.symmetric(horizontal: padH),
            // outline 变体：白表面 + 主色描边
            color: variant == DSButtonVariant.outline ? null : base,
            strokeColor: variant == DSButtonVariant.outline
                ? theme.primary.withValues(alpha: 0.55)
                : null,
            raised: !pressed && !disabled,
            shadows: pressed && !disabled
                ? theme.pressedShadow(base == theme.surface ? theme.primary : base)
                : null,
            alignment: Alignment.center,
            child: content,
          );
        }

        // 按压时轻微回缩，强化果冻手感
        final scaled = AnimatedScale(
          scale: pressed && !disabled ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: box,
        );

        return expand
            ? SizedBox(width: double.infinity, child: scaled)
            : scaled;
      },
    );
  }
}

/// 圆形图标按钮
class DSIconButton extends StatelessWidget {
  const DSIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.color,
    this.iconColor,
    this.tooltip,
  });

  final DsIconKind icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final Color? iconColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final base = color ?? theme.primary;

    final button = Pressable(
      onPressed: onPressed,
      semanticLabel: tooltip,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        final disabled = onPressed == null;
        final effectiveBase = disabled
            ? theme.disabled
            : pressed
                ? base.mixBlack(0.08)
                : base;
        return AnimatedScale(
          scale: pressed && !disabled ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: JellyBox(
            width: size,
            height: size,
            radius: theme.radii.circle,
            color: effectiveBase,
            raised: !pressed && !disabled,
            shadows:
                pressed && !disabled ? theme.pressedShadow(base) : null,
            alignment: Alignment.center,
            child: DsIcon(
              icon,
              size: size * 0.5,
              color: disabled
                  ? theme.surface
                  : iconColor ?? (color == null ? theme.onPrimary : theme.onPrimary),
            ),
          ),
        );
      },
    );

    return tooltip == null
        ? button
        : Semantics(label: tooltip, button: true, child: button);
  }
}

/// 悬浮果冻按钮（FAB）
class DSFab extends StatelessWidget {
  const DSFab({
    super.key,
    this.icon = DsIconKind.plus,
    this.onPressed,
    this.size = 60,
  });

  final DsIconKind icon;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Pressable(
      onPressed: onPressed,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        final disabled = onPressed == null;
        return AnimatedScale(
          scale: pressed && !disabled ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: JellyBox(
            width: size,
            height: size,
            radius: theme.radii.circle,
            color: theme.primary,
            raised: !pressed,
            shadows: pressed
                ? theme.pressedShadow(theme.primary, height: 8)
                : theme.jellyShadow(theme.primary, height: 8),
            alignment: Alignment.center,
            child: DsIcon(icon, size: size * 0.46, color: theme.onPrimary),
          ),
        );
      },
    );
  }
}
