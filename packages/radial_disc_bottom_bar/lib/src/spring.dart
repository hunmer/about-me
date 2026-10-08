import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// 弹簧驱动的隐式动画组件
///
/// 目标值 [value] 变化时，携带当前速度从动画中的值弹向新目标，
/// 对应 motion/react 的 `spring(stiffness, damping)`（质量取 1）。
class SpringBuilder extends StatefulWidget {
  const SpringBuilder({
    super.key,
    required this.value,
    required this.builder,
    this.stiffness = 420,
    this.damping = 34,
  });

  final double value;
  final Widget Function(BuildContext context, double value) builder;
  final double stiffness;
  final double damping;

  @override
  State<SpringBuilder> createState() => _SpringBuilderState();
}

class _SpringBuilderState extends State<SpringBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this)..value = widget.value;
  Simulation? _simulation;

  @override
  void didUpdateWidget(SpringBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _simulation = SpringSimulation(
        SpringDescription(
          mass: 1,
          stiffness: widget.stiffness,
          damping: widget.damping,
        ),
        _controller.value,
        widget.value,
        _currentVelocity,
      );
      _controller.animateWith(_simulation!);
    }
  }

  double get _currentVelocity {
    final elapsed = _controller.lastElapsedDuration;
    final simulation = _simulation;
    if (elapsed == null || simulation == null) return 0;
    return simulation.dx(
      elapsed.inMicroseconds / Duration.microsecondsPerSecond,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _controller.value),
    );
  }
}
