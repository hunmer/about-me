import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/motion.dart';
import '../tokens/typography.dart';
import 'ink_splash.dart';

/// 手绘数值计数器：数值变化时滚动补间到新值
///
/// - 数值：`TweenAnimationBuilder` 按 [DsMotion.curve] 补间，
///   显示四舍五入 [decimals] 位
/// - [jelly]：变化瞬间外层 scale 弹跳（1→1.14→0.98→1.08→1）
/// - [splash]：变化瞬间墨点爆发（[DsInkSplash]）
/// - 动画减弱（`context.dsAnimationsDisabled`）时直接显示终值
///
/// ```dart
/// DsCountUp(
///   value: stats.total,
///   prefix: '共 ',
///   suffix: ' 条',
///   jelly: true,
///   splash: true,
/// )
/// ```
class DsCountUp extends StatefulWidget {
  const DsCountUp({
    super.key,
    required this.value,
    this.duration = DsMotion.slow,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
    this.jelly = true,
    this.splash = false,
    this.splashColor,
  });

  /// 目标数值（变化时从当前显示值补间过去）
  final num value;

  /// 补间时长
  final Duration duration;

  /// 文字样式（默认 heading + 主题文字色）
  final TextStyle? style;

  final String prefix;
  final String suffix;

  /// 保留小数位（四舍五入）
  final int decimals;

  /// 变化瞬间的果冻弹跳
  final bool jelly;

  /// 变化瞬间的墨点爆发
  final bool splash;

  /// 墨点颜色（默认主题主色；[splash] 为 false 时忽略）
  final Color? splashColor;

  @override
  State<DsCountUp> createState() => _DsCountUpState();
}

class _DsCountUpState extends State<DsCountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _jellyController;

  /// 果冻弹跳序列：1→1.14→0.98→1.08→1，四段各占 25% 进度
  static final Animatable<double> _jellySequence = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.14), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 1.14, end: 0.98), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 0.98, end: 1.08), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 25),
  ]);

  @override
  void initState() {
    super.initState();
    _jellyController = AnimationController(
      vsync: this,
      duration: DsMotion.slow,
    );
  }

  @override
  void dispose() {
    _jellyController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DsCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        widget.jelly &&
        !context.dsAnimationsDisabled) {
      _jellyController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final disabled = context.dsAnimationsDisabled;

    Widget counter = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.value.toDouble()),
      duration: disabled ? Duration.zero : widget.duration,
      curve: DsMotion.curve,
      builder: (context, v, _) => Text(
        '${widget.prefix}${v.toStringAsFixed(widget.decimals)}${widget.suffix}',
        style: widget.style ??
            DsTypography.heading.copyWith(color: theme.text),
      ),
    );

    if (widget.jelly && !disabled) {
      counter = ScaleTransition(
        scale: _jellySequence.animate(_jellyController),
        child: counter,
      );
    }

    if (!widget.splash) return counter;

    // 墨点爆发：不随 scale 缩放，铺在数字外层（不裁剪，允许飞出）
    return Stack(
      clipBehavior: Clip.none,
      children: [
        counter,
        Positioned.fill(
          child: DsInkSplash(
            trigger: widget.value,
            color: widget.splashColor ?? theme.primary,
          ),
        ),
      ],
    );
  }
}
