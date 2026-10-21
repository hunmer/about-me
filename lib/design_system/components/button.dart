import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/motion.dart';
import '../tokens/shadows.dart';
import '../tokens/typography.dart';
import 'focus_ring.dart';
import 'icons.dart';
import 'jelly_box.dart';
import 'tooltip.dart';

/// 按钮变体（对标 shadcn：primary / secondary / outline / ghost / destructive）
/// + dashed：纸面底 + 虚线墨框（hover 时虚线换主题主色，无实线描边）
enum DSButtonVariant { primary, secondary, outline, ghost, destructive, dashed }

/// 按钮尺寸
enum DSButtonSize { sm, md, lg }

/// 手绘按钮：纯色实底 + 墨线描边
///
/// 颜色/圆角来自 [AppThemeData]；按压、悬停、禁用态
/// 通过 [Pressable] 的状态回调切换。
///
/// - [loading]：忙碌态——阻断点击但保持正常配色，
///   图标位（无图标时文字前）替换为旋转墨线圈
/// - [DSButtonVariant.dashed]：纸面底 + 虚线墨框
/// - 实底类（primary/secondary/destructive）带 [JellyBox.shadow]
///   错位阴影的「游戏按键」按压手感（hover 上浮、按压下压收阴影）
/// - 键盘聚焦时外圈显示 [DsFocusRing] 虚线焦点环
class DSButton extends StatelessWidget {
  const DSButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = DSButtonVariant.primary,
    this.size = DSButtonSize.md,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.semanticLabel,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final DSButtonVariant variant;
  final DSButtonSize size;
  final DsIconKind? icon;

  /// 忙碌态：视为 busy——阻断点击与键盘激活（onPressed 不触发），
  /// 但不算 disabled 灰，配色保持常态
  final bool loading;

  /// 是否占满可用宽度
  final bool expand;
  final String? semanticLabel;

  /// 悬停气泡提示（桌面悬停 / 移动端长按），无障碍标签仍由
  /// [semanticLabel]/[label] 提供
  final String? tooltip;

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

    final button = Pressable(
      onPressed: onPressed,
      // loading 视为 busy：阻断点击与键盘激活，但配色保持常态
      enabled: !loading,
      semanticLabel: semanticLabel ?? label,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        final hovered = states.contains(WidgetState.hovered);
        final focused = states.contains(WidgetState.focused);
        // busy 不是禁用：loading 期间不套禁用灰
        final disabled = states.contains(WidgetState.disabled) && !loading;

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
          case DSButtonVariant.dashed:
            base = theme.surface;
            labelColor = theme.text;
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

        // 前导位：loading 时替换为墨线圈，否则为图标（都没有则不占位）
        final Widget? leading = loading
            ? _InkSpinner(size: font.fontSize! + 5, color: labelColor)
            : icon == null
            ? null
            : DsIcon(icon!, size: font.fontSize! + 5, color: labelColor);

        Widget content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading,
              SizedBox(width: theme.spacing.sm),
            ],
            Text(label, style: font.copyWith(color: labelColor)),
          ],
        );

        // 实底类变体：错位阴影「游戏按键」按压手感
        final solid =
            variant == DSButtonVariant.primary ||
            variant == DSButtonVariant.secondary ||
            variant == DSButtonVariant.destructive;

        Widget box;
        if (variant == DSButtonVariant.ghost) {
          box = AnimatedContainer(
            duration: DsMotion.fast,
            curve: DsMotion.curve,
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
        } else if (variant == DSButtonVariant.dashed) {
          // 纸面底 + 虚线墨框（画在按钮边界的 Stack 层，hover 换主色虚线）
          box = Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: DsMotion.fast,
                curve: DsMotion.curve,
                height: height,
                padding: EdgeInsets.symmetric(horizontal: padH),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: theme.radii.lg,
                ),
                child: content,
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DashedBorderPainter(
                      color: hovered && !disabled ? theme.primary : theme.ink,
                      radius: theme.radii.lg,
                    ),
                  ),
                ),
              ),
            ],
          );
        } else if (solid) {
          // 按压手感：hovered 整体上浮 -1、pressed 下压 +2 且阴影厚度
          // 从 regular(0,5) 压到 (0,2)（light 的一半手感）。
          // 位移与阴影厚度用补间过渡，墨线随整体平移、不重画不抖变
          final lift = disabled
              ? Offset.zero
              : pressed
              ? const Offset(0, 2)
              : hovered
              ? const Offset(0, -1)
              : Offset.zero;
          final shadowOffset = pressed && !disabled
              ? const Offset(0, 2)
              : DsHandShadow.regular;
          box = TweenAnimationBuilder<Offset>(
            tween: Tween(end: lift),
            duration: DsMotion.fast,
            curve: DsMotion.curve,
            builder: (context, offset, child) =>
                Transform.translate(offset: offset, child: child),
            child: TweenAnimationBuilder<Offset>(
              tween: Tween(end: shadowOffset),
              duration: DsMotion.fast,
              curve: DsMotion.curve,
              builder: (context, offset, child) => JellyBox(
                radius: theme.radii.lg,
                height: height,
                padding: EdgeInsets.symmetric(horizontal: padH),
                color: base,
                shadow: true,
                shadowOffset: offset,
                raised: !pressed && !disabled,
                alignment: Alignment.center,
                child: child,
              ),
              child: content,
            ),
          );
        } else {
          // outline：白表面 + 主色描边（保持现状，无阴影无位移）
          box = JellyBox(
            radius: theme.radii.lg,
            height: height,
            padding: EdgeInsets.symmetric(horizontal: padH),
            color: null,
            strokeColor: theme.primary.withValues(alpha: 0.55),
            raised: !pressed && !disabled,
            alignment: Alignment.center,
            child: content,
          );
        }

        // 按压时轻微回缩，强化按压手感
        final scaled = AnimatedScale(
          scale: pressed && !disabled ? 0.96 : 1.0,
          duration: DsMotion.fast,
          curve: DsMotion.curve,
          child: box,
        );

        // 键盘聚焦虚线环（圆角与按钮一致）
        final ringed = DsFocusRing(
          show: focused,
          radius: theme.radii.lg,
          child: scaled,
        );

        return expand
            ? SizedBox(width: double.infinity, child: ringed)
            : ringed;
      },
    );

    // 无障碍标签由 Pressable.semanticLabel 提供；这里只负责悬停气泡
    return tooltip == null
        ? button
        : DSTooltip(message: tooltip!, child: button);
  }
}

/// 旋转墨线圈：loading 占位的 270° 手绘弧线
///
/// [AnimationController.repeat]（约 900ms 线性）驱动旋转；
/// [BuildContext.dsAnimationsDisabled] 时静止画完整圆。
class _InkSpinner extends StatefulWidget {
  const _InkSpinner({required this.size, required this.color});

  /// 圈的边长（与图标位同尺寸）
  final double size;

  /// 墨线颜色（跟随当前内容色）
  final Color color;

  @override
  State<_InkSpinner> createState() => _InkSpinnerState();
}

class _InkSpinnerState extends State<_InkSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPlayback();
  }

  /// 动效减弱时停转（退化为静止整圆），恢复后继续旋转
  void _syncPlayback() {
    if (context.dsAnimationsDisabled) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = context.dsAnimationsDisabled;
    return CustomPaint(
      size: Size.square(widget.size),
      painter: _InkCirclePainter(
        color: widget.color,
        animation: animationsDisabled ? null : _controller,
      ),
    );
  }
}

/// 墨线弧 painter：270° 圆弧（线宽 2，圆心留空），
/// [animation] 驱动起点旋转；null 时画静止完整圆
class _InkCirclePainter extends CustomPainter {
  _InkCirclePainter({required this.color, this.animation})
    : super(repaint: animation);

  final Color color;
  final Animation<double>? animation;

  static const double _strokeWidth = 2;

  /// 旋转弧的扫过角度：270°
  static const double _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = size.shortestSide / 2 - _strokeWidth / 2;
    if (radius <= 0) return;
    final anim = animation;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..color = color;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );
    final sweep = anim == null ? math.pi * 2 : _sweep;
    final start = -math.pi / 2 + (anim?.value ?? 0) * math.pi * 2;
    canvas.drawArc(rect, start, sweep, false, paint);
  }

  @override
  bool shouldRepaint(_InkCirclePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.animation != animation;
}

/// 沿按钮边界画虚线墨框：圆角路径按「画 7 空 5」取段
/// （与 sketch.dart 的 _DashedBorderPainter 同款笔触，本文件私有实现）
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final BorderRadius radius;

  static const double _strokeWidth = 1.6;
  static const double _dashLength = 7;
  static const double _gapLength = 5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final half = _strokeWidth / 2;
    final rrect = radius.toRRect((Offset.zero & size).deflate(half));
    final path = Path()..addRRect(rrect);

    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var drawing = true;
      while (distance < metric.length) {
        final segment = drawing ? _dashLength : _gapLength;
        final next = math.min(distance + segment, metric.length);
        if (drawing) {
          dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        }
        distance = next;
        drawing = !drawing;
      }
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _strokeWidth
      ..color = color;
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
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

  /// 悬停气泡提示（桌面悬停 / 移动端长按），同时作为无障碍标签
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
            alignment: Alignment.center,
            child: DsIcon(
              icon,
              size: size * 0.5,
              color: disabled
                  ? theme.surface
                  : iconColor ??
                        (color == null ? theme.onPrimary : theme.onPrimary),
            ),
          ),
        );
      },
    );

    // 无障碍标签由 Pressable.semanticLabel 提供；这里只负责悬停气泡
    return tooltip == null
        ? button
        : DSTooltip(message: tooltip!, child: button);
  }
}

/// 悬浮手绘按钮（FAB）
class DSFab extends StatelessWidget {
  const DSFab({
    super.key,
    this.icon = DsIconKind.plus,
    this.onPressed,
    this.size = 60,
    this.color,
    this.iconColor,
    this.tooltip,
  });

  final DsIconKind icon;
  final VoidCallback? onPressed;
  final double size;

  /// 覆盖按钮基色（默认主题主色）
  final Color? color;

  /// 覆盖图标颜色（默认主色上的前景色）
  final Color? iconColor;

  /// 悬停气泡提示（桌面悬停 / 移动端长按）
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final base = color ?? theme.primary;
    final effectiveIconColor = iconColor ?? theme.onPrimary;
    final button = Pressable(
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
            color: disabled ? theme.disabled : base,
            raised: !pressed,
            alignment: Alignment.center,
            child: DsIcon(icon, size: size * 0.46, color: effectiveIconColor),
          ),
        );
      },
    );

    // 无障碍标签由 Pressable.semanticLabel 提供；这里只负责悬停气泡
    return tooltip == null
        ? button
        : DSTooltip(message: tooltip!, child: button);
  }
}
