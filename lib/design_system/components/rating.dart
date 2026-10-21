import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/motion.dart';
import 'icons.dart';
import 'ink_splash.dart';

/// 星级评分：支持半星精度，可交互
///
/// - 数值变化时整排星级做滑动补间（外层 TweenAnimationBuilder 驱动
///   现有的 fraction 裁剪，增减星有滑动感）
/// - 交互点亮的那颗星弹跳（0.55 → 1.15 → 1）+ 墨点扩散；只读模式均不播
class DSRating extends StatelessWidget {
  const DSRating({
    super.key,
    required this.value,
    this.onChanged,
    this.max = 5,
    this.size = 30,
    this.color,
  });

  /// 0.0 ~ [max]
  final double value;
  final int max;
  final double size;

  /// 为 null 时只读
  final ValueChanged<double>? onChanged;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final filled = color ?? theme.warning;
    // 空星淡墨：衬托实星颜色，与手绘纸面协调
    final empty = theme.textSub.withValues(alpha: 0.45);

    // 外层数值补间：value 变化时自当前值滑动到新值（墨线不可补间，
    // 但星形裁剪的 fraction 是可补间的几何量）
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: DsMotion.slow,
      curve: DsMotion.curve,
      builder: (context, animatedValue, _) {
        final stars = <Widget>[];
        for (var i = 0; i < max; i++) {
          final fraction = (animatedValue - i).clamp(0.0, 1.0);
          final star = DsIcon(DsIconKind.star, size: size, color: empty);
          final filledStar = DsIcon(DsIconKind.star, size: size, color: filled);
          final Widget cell;
          if (fraction >= 1) {
            cell = filledStar;
          } else if (fraction <= 0) {
            cell = star;
          } else {
            // 半星：底层空星 + 上层裁剪实星（裁剪与 child 画法无关）
            cell = Stack(
              children: [
                star,
                ClipRect(
                  clipper: _FractionClipper(fraction),
                  child: filledStar,
                ),
              ],
            );
          }

          if (onChanged != null) {
            final index = i;
            // 该星是否为当前值对应的星（= 刚被点亮的那颗）
            final lit = index + 1 == value;
            stars.add(
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged!(index + 1.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 点亮瞬间该星弹跳一次（灭星不播）
                      _StarBounce(active: lit, child: cell),
                      Positioned.fill(
                        child: _StarSplash(active: lit, color: filled),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            // 只读：无弹跳、无墨点扩散
            stars.add(Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: cell,
            ));
          }
        }

        return Semantics(
          label: '$value / $max',
          child: MouseRegion(
            cursor: onChanged != null
                ? SystemMouseCursors.click
                : MouseCursor.defer,
            child: Row(mainAxisSize: MainAxisSize.min, children: stars),
          ),
        );
      },
    );
  }
}

class _FractionClipper extends CustomClipper<Rect> {
  const _FractionClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_FractionClipper oldDelegate) =>
      oldDelegate.fraction != fraction;
}

/// 点亮星星的弹跳：0.55 → 1.15 → 1，仅在由未点亮变为点亮的瞬间播放一次
///
/// 初始静置于 1（首次构建不弹跳，保持现状视觉）。
class _StarBounce extends StatefulWidget {
  const _StarBounce({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_StarBounce> createState() => _StarBounceState();
}

class _StarBounceState extends State<_StarBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DsMotion.slow,
  );

  /// 弹跳 keyframes：快速弹起过冲（1.15）再回稳（1）
  static final Animatable<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 0.55, end: 1.15).chain(
        CurveTween(curve: DsMotion.curve),
      ),
      weight: 60,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.15, end: 1).chain(
        CurveTween(curve: DsMotion.curve),
      ),
      weight: 40,
    ),
  ]);

  @override
  void initState() {
    super.initState();
    _controller.value = 1; // 初始静置，不弹跳
  }

  @override
  void didUpdateWidget(_StarBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && !context.dsAnimationsDisabled) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale.animate(_controller),
      child: widget.child,
    );
  }
}

/// 点亮星星的墨点扩散门控
///
/// [DsInkSplash] 的 trigger 只要变化就会重播，这里用生成计数把它
/// 收窄为「仅 [active] 由假变真（点亮瞬间）时重播一次」，灭星不播。
class _StarSplash extends StatefulWidget {
  const _StarSplash({required this.active, this.color});

  final bool active;
  final Color? color;

  @override
  State<_StarSplash> createState() => _StarSplashState();
}

class _StarSplashState extends State<_StarSplash> {
  int _generation = 0;

  @override
  void didUpdateWidget(_StarSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _generation++;
    }
  }

  @override
  Widget build(BuildContext context) =>
      DsInkSplash(trigger: _generation, color: widget.color);
}
