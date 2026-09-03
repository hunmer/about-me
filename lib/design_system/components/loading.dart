import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// 果冻加载动画：三颗圆点依次弹跳
class DSLoadingDots extends StatefulWidget {
  const DSLoadingDots({
    super.key,
    this.size = 12,
    this.color,
    this.label,
  });

  final double size;
  final Color? color;

  /// 可选文字说明
  final String? label;

  @override
  State<DSLoadingDots> createState() => _DSLoadingDotsState();
}

class _DSLoadingDotsState extends State<DSLoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final color = widget.color ?? theme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.size * 2,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 3; i++)
                    Transform.translate(
                      offset: Offset(
                        0,
                        -_bounce(_controller.value - i * 0.18),
                      ),
                      child: _Dot(color: color, size: widget.size),
                    ),
                ],
              );
            },
          ),
        ),
        if (widget.label != null)
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              widget.label!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.textSub,
              ),
            ),
          ),
      ],
    );
  }

  /// 弹跳曲线：t 在 [0, 0.6] 内为一个正弦弧，其余时间静止
  double _bounce(double t) {
    t = t % 1.0;
    if (t < 0 || t > 0.6) return 0;
    return math.sin(t / 0.6 * math.pi) * 8;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Container(
      width: size,
      height: size,
      margin: EdgeInsets.symmetric(horizontal: size * 0.28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.jellyGradient(color),
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            offset: const Offset(0, 3),
            blurRadius: 5,
          ),
        ],
      ),
    );
  }
}
