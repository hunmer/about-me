import 'dart:math';

import 'package:flutter/material.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 液体波浪进度填充：双层正弦波 + 渐变波体，
/// 绘制方式参考 wave_progress_indicator 的 WavePainter。
/// vertical 自下而上填充，horizontal 自左向右填充；
/// [drawProgress] 接外层 WiredDraw 描画进度，波浪在 30%–100% 阶段浮现。
///
/// 内部 CustomPaint 无 child，须置于有界约束且撑满
/// （SizedBox.expand / Positioned.fill / tight 约束），否则收缩为 0 不可见
class WaveFill extends StatefulWidget {
  const WaveFill({
    super.key,
    required this.progress,
    required this.color,
    this.horizontal = false,
    this.amplitude,
    this.drawProgress,
  });

  final double progress;
  final Color color;

  /// 自左向右填充（默认自下而上）
  final bool horizontal;

  /// 前层波幅；缺省按方向取默认（垂直 7 / 水平 5），后层波幅为其 +2。
  /// 小尺寸容器（如细窄柱）建议调小，避免波浪吞掉整个容器
  final double? amplitude;

  final Animation<double>? drawProgress;

  @override
  State<WaveFill> createState() => _WaveFillState();
}

class _WaveFillState extends State<WaveFill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draw = widget.drawProgress;
    return AnimatedBuilder(
      animation: draw == null
          ? _controller
          : Listenable.merge([_controller, draw]),
      builder: (context, _) => CustomPaint(
        painter: _WavePainter(
          progress: widget.progress,
          animationValue: _controller.value,
          drawValue: draw?.value ?? 1,
          color: widget.color,
          horizontal: widget.horizontal,
          amplitude: widget.amplitude,
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.progress,
    required this.animationValue,
    required this.drawValue,
    required this.color,
    this.horizontal = false,
    this.amplitude,
  });

  final double progress;
  final double animationValue;

  /// 外层 WiredDraw 描画进度；1 = 无动画环境，立即全画
  final double drawValue;
  final Color color;
  final bool horizontal;

  /// 前层波幅覆盖；null 时按方向取默认
  final double? amplitude;

  double get _frontAmp => amplitude ?? (horizontal ? 5.0 : 7.0);
  double get _backAmp => _frontAmp + 2;

  /// 墨线描边先描（0–65%），波体随后浮现（30%–100%），见 design.md §10
  double get fillPhase => ((drawValue - 0.3) / 0.7).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || fillPhase <= 0) return;
    if (horizontal) {
      _paintHorizontal(canvas, size);
    } else {
      _paintVertical(canvas, size);
    }
  }

  void _paintVertical(Canvas canvas, Size size) {
    // 后层波：更浅、反向流动，形成前后景深
    _drawWave(
      canvas,
      size,
      level: -8,
      amp: _backAmp,
      phase: -animationValue * 2 * pi,
      horizontal: false,
      paint: Paint()
        ..color = color.mixWhite(0.25).withValues(alpha: 0.45 * fillPhase),
    );
    // 前层波 + 波体：自下而上渐弱
    _drawWave(
      canvas,
      size,
      level: 0,
      amp: _frontAmp,
      phase: animationValue * 2 * pi,
      horizontal: false,
      paint: Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            color.withValues(alpha: 0.60 * fillPhase),
            color.withValues(alpha: 0.38 * fillPhase),
            color.withValues(alpha: 0.24 * fillPhase),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  void _paintHorizontal(Canvas canvas, Size size) {
    // 后层波：更浅、反向流动，形成前后景深
    _drawWave(
      canvas,
      size,
      level: -5,
      amp: _backAmp,
      phase: -animationValue * 2 * pi,
      horizontal: true,
      paint: Paint()
        ..color = color.mixWhite(0.25).withValues(alpha: 0.45 * fillPhase),
    );
    // 前层波 + 波体：自左向右渐弱
    _drawWave(
      canvas,
      size,
      level: 0,
      amp: _frontAmp,
      phase: animationValue * 2 * pi,
      horizontal: true,
      paint: Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.60 * fillPhase),
            color.withValues(alpha: 0.38 * fillPhase),
            color.withValues(alpha: 0.24 * fillPhase),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size, {
    required double level,
    required double amp,
    required double phase,
    required bool horizontal,
    required Paint paint,
  }) {
    final path = horizontal
        ? _buildHorizontalPath(size, level, amp, phase)
        : _buildVerticalPath(size, level, amp, phase);
    canvas.drawPath(path, paint);
  }

  /// 垂直填充：波面沿 x 轴起伏，水位线 y = height * (1 - progress)
  Path _buildVerticalPath(Size size, double level, double amp, double phase) {
    final base = size.height * (1 - progress) + level;
    final path = Path()..moveTo(0, base);
    for (double x = 0; x <= size.width; x++) {
      final y = base + sin((x / size.width * 2 * pi) + phase) * amp;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  /// 水平填充：波面沿 y 轴起伏，进度线 x = width * progress
  Path _buildHorizontalPath(Size size, double level, double amp, double phase) {
    final base = size.width * progress + level;
    final path = Path()..moveTo(base, 0);
    for (double y = 0; y <= size.height; y++) {
      final x = base + sin((y / size.height * 2 * pi) + phase) * amp;
      path.lineTo(x, y);
    }
    path
      ..lineTo(0, size.height)
      ..lineTo(0, 0)
      ..close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.animationValue != animationValue ||
      old.progress != progress ||
      old.drawValue != drawValue ||
      old.color != color ||
      old.horizontal != horizontal ||
      old.amplitude != amplitude;
}
