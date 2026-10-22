/// 半圆仪表盘统计卡片（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 上半圆三段式扇环（斜纹数据段 + 浅色目标斜纹段 + 淡墨轨道段），
/// 进度段与斜纹段之间以哑铃状墨线指针（两端圆点 + 连杆）分割，
/// 环内中心显示当前数值与总量。支持拖拽指针调节数值（interactive）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

class SemicircleGaugeCardWidget extends StatefulWidget {
  /// 当前值（如 1250）
  final double value;

  /// 总量（如 1600）
  final double maxValue;

  /// 斜纹段结束位置对应的值（0 表示无斜纹段，剩余段从指针开始）
  final double hatchedValue;

  /// 单位文本（如 'kcal'），为空时不显示
  final String unit;

  /// 旧深色卡的卡片底色；手绘纸卡下改作仪表盘数据色（斜纹 + 描边）
  final Color backgroundColor;

  /// 旧深色卡的对比色（纸底上不可读），仅为 props 兼容保留，不再消费
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
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 384 * scale,
        height: widget.inline ? double.maxFinite : _defaultHeight(),
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Center(child: _buildGauge(theme)),
      ),
    );
  }

  Widget _buildGauge(AppThemeData theme) {
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
            activeColor: widget.backgroundColor,
            theme: theme,
            scale: widget.size.scale,
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
                        color: theme.text,
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
                        color: theme.textSub,
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

/// 半圆仪表盘绘制器（平直几何 + 斜纹）
///
/// 淡墨轨道扇环垫底；进度扇环为数据色浅底 + 浓斜纹 + 数据色描边；
/// 指针与斜纹段之间的目标区为数据色浅斜纹（次档），指针为墨线哑铃
/// （两端圆点 + 径向连杆）。颜色一律取 [theme] 语义色，
/// 数据色 [activeColor]（原卡片底色 props）。
class _SemicircleGaugePainter extends CustomPainter {
  /// 当前进度占比 0..1（动画/拖拽后的值）
  final double progress;

  /// 斜纹段结束占比 0..1（0 表示无斜纹段）
  final double hatchedEnd;

  final Color activeColor;
  final AppThemeData theme;
  final double scale;

  _SemicircleGaugePainter({
    required this.progress,
    required this.hatchedEnd,
    required this.activeColor,
    required this.theme,
    required this.scale,
  });

  static const double _gapDeg = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rOut = size.width / 2 / 1.15;
    final k = rOut / 196;
    final rIn = rOut * (142 / 196);
    final center = Offset(size.width / 2, size.height - 2 * k);
    final gap = _gapDeg * math.pi / 180;
    final minSpan = 3 * math.pi / 180;
    final bounds = Offset.zero & size;

    // 角度定义：-π 为正左方，0 为正右方（上半圆）
    const startAngle = -math.pi;
    const endAngle = 0.0;
    final pinAngle = startAngle + math.pi * progress.clamp(0.0, 1.0);
    final hatchedEndAngle =
        hatchedEnd > 0 ? startAngle + math.pi * hatchedEnd : pinAngle;

    // 轨道：淡墨底 + 低透明度斜纹 + 淡描边（先画，垫在最底层）
    final trackPath = _sector(center, rIn, rOut, startAngle, endAngle);
    canvas.drawPath(trackPath, Paint()..color = theme.surfaceAlt);
    paintDiagonalStripes(
      canvas,
      trackPath,
      bounds,
      color: theme.ink.withValues(alpha: 0.28),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawPath(
      trackPath,
      Paint()
        ..color = theme.ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );

    // 第二段：目标区浅斜纹段（数据色次档：更淡的底/纹/描边）
    final seg2Start = pinAngle + gap;
    if (hatchedEnd > 0 && hatchedEndAngle > seg2Start + minSpan) {
      final path2 = _sector(center, rIn, rOut, seg2Start, hatchedEndAngle);
      canvas.drawPath(
        path2,
        Paint()..color = activeColor.withValues(alpha: 0.18),
      );
      paintDiagonalStripes(
        canvas,
        path2,
        bounds,
        color: activeColor.withValues(alpha: 0.5),
        strokeWidth: 3 * scale,
        spacing: 6.5 * scale,
      );
      canvas.drawPath(
        path2,
        Paint()
          ..color = activeColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );
    }

    // 第一段：数据色主进度段（浅底 + 浓斜纹 + 描边）
    final seg1End = math.max(startAngle + 4 * math.pi / 180, pinAngle - gap);
    if (seg1End > startAngle + minSpan) {
      final path1 = _sector(center, rIn, rOut, startAngle, seg1End);
      canvas.drawPath(
        path1,
        Paint()..color = activeColor.withValues(alpha: 0.28),
      );
      paintDiagonalStripes(
        canvas,
        path1,
        bounds,
        color: activeColor.withValues(alpha: 0.9),
        strokeWidth: 3 * scale,
        spacing: 6.5 * scale,
      );
      canvas.drawPath(
        path1,
        Paint()
          ..color = activeColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );
    }

    // 哑铃分割指针（两端墨线圆点 + 径向连杆）
    final innerPt = Offset(
      center.dx + (rIn - 16.5 * k) * math.cos(pinAngle),
      center.dy + (rIn - 16.5 * k) * math.sin(pinAngle),
    );
    final outerPt = Offset(
      center.dx + (rOut + 16.5 * k) * math.cos(pinAngle),
      center.dy + (rOut + 16.5 * k) * math.sin(pinAngle),
    );
    final pinPaint = Paint()..color = theme.ink;
    canvas.drawLine(
      innerPt,
      outerPt,
      Paint()
        ..color = theme.ink
        ..strokeWidth = 3.2 * k
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(innerPt, 10.5 * k, pinPaint);
    canvas.drawCircle(outerPt, 10.5 * k, pinPaint);
  }

  /// 平直扇环路径（与 half_gauge_card 的 _sector 同款）
  Path _sector(Offset c, double rIn, double rOut, double a0, double a1) {
    final largeArc = (a1 - a0) > math.pi;
    final path = Path();
    path.moveTo(c.dx + rOut * math.cos(a0), c.dy + rOut * math.sin(a0));
    path.arcToPoint(
      Offset(c.dx + rOut * math.cos(a1), c.dy + rOut * math.sin(a1)),
      radius: Radius.circular(rOut),
      largeArc: largeArc,
      clockwise: true,
    );
    path.lineTo(c.dx + rIn * math.cos(a1), c.dy + rIn * math.sin(a1));
    path.arcToPoint(
      Offset(c.dx + rIn * math.cos(a0), c.dy + rIn * math.sin(a0)),
      radius: Radius.circular(rIn),
      largeArc: largeArc,
      clockwise: false,
    );
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _SemicircleGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hatchedEnd != hatchedEnd ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}
