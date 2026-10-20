import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 半圆仪表盘统计卡片
///
/// 上半圆三段式扇环：纯白进度段 + 斜纹段 + 半透明剩余段，
/// 进度段与斜纹段之间以哑铃状指针（两端圆点 + 连杆）分割，
/// 环内中心显示当前数值与总量。支持拖拽指针调节数值（interactive）。
class SemicircleGaugeCardWidget extends StatefulWidget {
  /// 当前值（如 1250）
  final double value;

  /// 总量（如 1600）
  final double maxValue;

  /// 斜纹段结束位置对应的值（0 表示无斜纹段，剩余段从指针开始）
  final double hatchedValue;

  /// 单位文本（如 'kcal'），为空时不显示
  final String unit;

  /// 卡片背景色
  final Color backgroundColor;

  /// 主色（进度段、指针、数值文字；斜纹/剩余段由其派生透明度）
  final Color activeColor;

  /// 是否可拖拽指针调节数值
  final bool interactive;

  /// 拖拽数值变化回调
  final ValueChanged<double>? onChanged;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const SemicircleGaugeCardWidget({
    super.key,
    required this.value,
    this.maxValue = 1600,
    this.hatchedValue = 0,
    this.unit = 'kcal',
    this.backgroundColor = const Color(0xFF106BFF),
    this.activeColor = Colors.white,
    this.interactive = false,
    this.onChanged,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory SemicircleGaugeCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    Color parseColor(dynamic colorValue, Color fallback) {
      if (colorValue == null) return fallback;
      if (colorValue is Color) return colorValue;
      if (colorValue is int) return Color(colorValue);
      if (colorValue is String) {
        try {
          if (colorValue.startsWith('#')) {
            return Color(
              int.parse(colorValue.substring(1), radix: 16) + 0xFF000000,
            );
          }
          if (colorValue.startsWith('0x')) {
            return Color(int.parse(colorValue.substring(2), radix: 16));
          }
        } catch (e) {
          // 解析失败，返回默认颜色
        }
      }
      return fallback;
    }

    return SemicircleGaugeCardWidget(
      value: (props['value'] as num?)?.toDouble() ?? 0.0,
      maxValue: (props['maxValue'] as num?)?.toDouble() ?? 1600.0,
      hatchedValue: (props['hatchedValue'] as num?)?.toDouble() ?? 0.0,
      unit: props['unit'] as String? ?? 'kcal',
      backgroundColor: parseColor(props['backgroundColor'], const Color(0xFF106BFF)),
      activeColor: parseColor(props['activeColor'], Colors.white),
      interactive: props['interactive'] as bool? ?? false,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<SemicircleGaugeCardWidget> createState() =>
      _SemicircleGaugeCardWidgetState();
}

class _SemicircleGaugeCardWidgetState extends State<SemicircleGaugeCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  /// 拖拽中的占比（null 表示未拖拽，走入场动画值）
  double? _dragFraction;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.addListener(() {
      setState(() {});
    });
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double get _targetFraction =>
      (widget.value / widget.maxValue).clamp(0.0, 1.0).toDouble();

  double get _displayFraction =>
      _dragFraction ?? _targetFraction * _animation.value;

  double get _displayValue => _dragFraction != null
      ? _dragFraction! * widget.maxValue
      : widget.value * _animation.value;

  double get _hatchedEndFraction => widget.hatchedValue > 0
      ? (widget.hatchedValue / widget.maxValue).clamp(0.0, 1.0).toDouble()
      : 0.0;

  void _updateFromPosition(Offset local, Size canvasSize) {
    final k = canvasSize.width / 2 / 1.15 / 196;
    final center = Offset(canvasSize.width / 2, canvasSize.height - 2 * k);
    final angle = math.atan2(local.dy - center.dy, local.dx - center.dx);
    // 下半圆吸附到最近端点
    double fraction;
    if (angle > 0) {
      fraction = angle < math.pi / 2 ? 1.0 : 0.0;
    } else {
      fraction = (angle + math.pi) / math.pi;
    }
    fraction = fraction.clamp(0.02, 0.98);
    setState(() => _dragFraction = fraction);
    widget.onChanged?.call(fraction * widget.maxValue);
  }

  void _reset() {
    setState(() => _dragFraction = null);
    _animationController.forward(from: 0);
  }

  double _defaultHeight() {
    final scale = widget.size.scale;
    if (widget.size is SmallSize) return 150 * scale;
    if (widget.size is MediumSize || widget.size is WideSize) {
      return 190 * scale;
    }
    if (widget.size is LargeSize || widget.size is Wide2Size) {
      return 330 * scale;
    }
    return 430 * scale;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _animation.value)),
            child: child,
          ),
        );
      },
      child: Container(
        width: widget.inline ? double.maxFinite : 384 * widget.size.scale,
        height: widget.inline ? double.maxFinite : _defaultHeight(),
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(24 * widget.size.scale),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20 * widget.size.scale,
              offset: Offset(0, 4 * widget.size.scale),
            ),
          ],
        ),
        child: Padding(
          padding: widget.size.getPadding(),
          child: Center(child: _buildGauge()),
        ),
      ),
    );
  }

  Widget _buildGauge() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 指针外圆点超出外圈约 14%，几何基准与 HTML 版一致（rOut=196）
        final rOut = math.min(
          constraints.maxWidth / 2 / 1.15,
          constraints.maxHeight / 1.2,
        );
        if (rOut <= 0) return const SizedBox.shrink();
        final k = rOut / 196;
        final canvasW = 2 * (rOut * 1.15);
        final canvasH = rOut * 1.15 + 4 * k;

        Widget gauge = CustomPaint(
          size: Size(canvasW, canvasH),
          painter: _SemicircleGaugePainter(
            progress: _displayFraction,
            hatchedEnd: _hatchedEndFraction,
            activeColor: widget.activeColor,
          ),
        );

        if (widget.interactive) {
          gauge = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _updateFromPosition(d.localPosition, Size(canvasW, canvasH)),
            onPanUpdate: (d) => _updateFromPosition(d.localPosition, Size(canvasW, canvasH)),
            onDoubleTap: _reset,
            child: gauge,
          );
        }

        final maxText = widget.maxValue == widget.maxValue.roundToDouble()
            ? widget.maxValue.round().toString()
            : widget.maxValue.toStringAsFixed(1);

        return SizedBox(
          width: canvasW,
          height: canvasH,
          child: Stack(
            children: [
              gauge,
              // 中心数值与总量（位于环内偏下，贴近圆心上方）
              Positioned(
                left: 0,
                right: 0,
                bottom: rOut * 0.10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _displayValue.round().toString(),
                      style: TextStyle(
                        color: widget.activeColor,
                        fontSize: rOut * 0.27,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8 * k,
                        height: 1.0,
                      ),
                    ),
                    SizedBox(height: 6 * k),
                    Text(
                      widget.unit.isEmpty
                          ? 'of $maxText'
                          : 'of $maxText ${widget.unit}',
                      style: TextStyle(
                        color: widget.activeColor.withOpacity(0.82),
                        fontSize: rOut * 0.11,
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 半圆仪表盘绘制器
class _SemicircleGaugePainter extends CustomPainter {
  /// 当前进度占比 0..1（动画/拖拽后的值）
  final double progress;

  /// 斜纹段结束占比 0..1（0 表示无斜纹段）
  final double hatchedEnd;

  final Color activeColor;

  _SemicircleGaugePainter({
    required this.progress,
    required this.hatchedEnd,
    required this.activeColor,
  });

  static const double _gapDeg = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rOut = size.width / 2 / 1.15;
    final k = rOut / 196;
    final rIn = rOut * (142 / 196);
    final center = Offset(size.width / 2, size.height - 2 * k);
    final rc = 15 * k;
    final gap = _gapDeg * math.pi / 180;
    final minSpan = 3 * math.pi / 180;

    // 角度定义：-π 为正左方，0 为正右方（上半圆）
    const startAngle = -math.pi;
    const endAngle = 0.0;
    final pinAngle = startAngle + math.pi * progress.clamp(0.0, 1.0);
    final hatchedEndAngle =
        hatchedEnd > 0 ? startAngle + math.pi * hatchedEnd : pinAngle;

    // 第三段：右下角半透明剩余段（先画，垫在最底层）
    final seg3Start = hatchedEnd > 0
        ? math.max(pinAngle + gap, hatchedEndAngle + gap)
        : pinAngle + gap;
    if (endAngle > seg3Start + minSpan) {
      final path3 = _roundedAnnularSector(
        center: center,
        rIn: rIn,
        rOut: rOut,
        startRad: seg3Start,
        endRad: endAngle,
        rc: rc - 1 * k,
      );
      canvas.drawPath(path3, Paint()..color = activeColor.withOpacity(0.25));
    }

    // 第二段：斜纹段（底色 + 斜线纹理 + 细描边）
    final seg2Start = pinAngle + gap;
    if (hatchedEnd > 0 && hatchedEndAngle > seg2Start + minSpan) {
      final path2 = _roundedAnnularSector(
        center: center,
        rIn: rIn,
        rOut: rOut,
        startRad: seg2Start,
        endRad: hatchedEndAngle,
        rc: rc - 1 * k,
      );
      canvas.drawPath(path2, Paint()..color = activeColor.withOpacity(0.23));

      // 斜线纹理：方向与指针保持平行（绕圆心旋转 pinAngle + 90°）
      canvas.save();
      canvas.clipPath(path2);
      canvas.translate(center.dx, center.dy);
      canvas.rotate(pinAngle + math.pi / 2);
      final stripePaint =
          Paint()
            ..color = activeColor.withOpacity(0.58)
            ..strokeWidth = 1.65 * k;
      final extent = rOut * 1.5;
      final step = 7.2 * k;
      for (double x = -extent; x <= extent; x += step) {
        canvas.drawLine(Offset(x, -extent), Offset(x, extent), stripePaint);
      }
      canvas.restore();

      // 外圈细描边
      canvas.drawPath(
        path2,
        Paint()
          ..color = activeColor.withOpacity(0.68)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * k,
      );
    }

    // 第一段：纯白主进度段
    final seg1End = math.max(startAngle + 4 * math.pi / 180, pinAngle - gap);
    final path1 = _roundedAnnularSector(
      center: center,
      rIn: rIn,
      rOut: rOut,
      startRad: startAngle,
      endRad: seg1End,
      rc: rc,
    );
    canvas.drawPath(path1, Paint()..color = activeColor);

    // 哑铃分割指针（两端圆点 + 径向连杆）
    final innerPt = Offset(
      center.dx + (rIn - 16.5 * k) * math.cos(pinAngle),
      center.dy + (rIn - 16.5 * k) * math.sin(pinAngle),
    );
    final outerPt = Offset(
      center.dx + (rOut + 16.5 * k) * math.cos(pinAngle),
      center.dy + (rOut + 16.5 * k) * math.sin(pinAngle),
    );
    final pinPaint = Paint()..color = activeColor;
    canvas.drawLine(
      innerPt,
      outerPt,
      Paint()
        ..color = activeColor
        ..strokeWidth = 3.2 * k
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(innerPt, 10.5 * k, pinPaint);
    canvas.drawCircle(outerPt, 10.5 * k, pinPaint);
  }

  /// 生成带真实圆角的扇环路径（精确欧氏几何切点计算，端面平直、四角圆润）
  static Path _roundedAnnularSector({
    required Offset center,
    required double rIn,
    required double rOut,
    required double startRad,
    required double endRad,
    required double rc,
  }) {
    final path = Path();
    final span = endRad - startRad;
    if (span <= 0.8 * math.pi / 180) return path;

    final thickness = rOut - rIn;
    final midR = (rIn + rOut) / 2;
    // 圆角半径不超过环宽一半以及扇环弧长可容纳范围
    final rCorner = math.max(
      1.0,
      math.min(rc, math.min(thickness / 2 - 0.5, (midR * span) / 2.2)),
    );

    // 外/内圈圆角切点角偏移与径向切点距离
    final dThetaOut = math.asin((rCorner / (rOut - rCorner)).clamp(-1.0, 1.0));
    final rOutTan = math.sqrt(
      math.max(0, math.pow(rOut - rCorner, 2) - math.pow(rCorner, 2)),
    );
    final dThetaIn = math.asin((rCorner / (rIn + rCorner)).clamp(-1.0, 1.0));
    final rInTan = math.sqrt(
      math.max(0, math.pow(rIn + rCorner, 2) - math.pow(rCorner, 2)),
    );

    Offset polar(double r, double a) =>
        Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));

    // 8 个关键切点
    final p1 = polar(rInTan, startRad);
    final p2 = polar(rOutTan, startRad);
    final p3 = polar(rOut, startRad + dThetaOut);
    final p4 = polar(rOut, endRad - dThetaOut);
    final p5 = polar(rOutTan, endRad);
    final p6 = polar(rInTan, endRad);
    final p7 = polar(rIn, endRad - dThetaIn);
    final p8 = polar(rIn, startRad + dThetaIn);

    final outerArcSpan = (endRad - dThetaOut) - (startRad + dThetaOut);
    final innerArcSpan = (endRad - dThetaIn) - (startRad + dThetaIn);

    path.moveTo(p1.dx, p1.dy);
    path.lineTo(p2.dx, p2.dy);
    path.arcToPoint(p3, radius: Radius.circular(rCorner), clockwise: true);
    if (outerArcSpan > 0) {
      path.arcToPoint(
        p4,
        radius: Radius.circular(rOut),
        largeArc: outerArcSpan > math.pi,
        clockwise: true,
      );
    }
    path.arcToPoint(p5, radius: Radius.circular(rCorner), clockwise: true);
    path.lineTo(p6.dx, p6.dy);
    path.arcToPoint(p7, radius: Radius.circular(rCorner), clockwise: true);
    if (innerArcSpan > 0) {
      path.arcToPoint(
        p8,
        radius: Radius.circular(rIn),
        largeArc: innerArcSpan > math.pi,
        clockwise: false,
      );
    }
    path.arcToPoint(p1, radius: Radius.circular(rCorner), clockwise: true);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _SemicircleGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hatchedEnd != hatchedEnd ||
        oldDelegate.activeColor != activeColor;
  }
}
