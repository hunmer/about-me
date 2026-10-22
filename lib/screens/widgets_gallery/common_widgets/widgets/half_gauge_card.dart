/// 半圆仪表盘小组件（手绘纸墨风格）
///
/// 手绘面板（纸底 + 排线 + 墨线框）内：标题 / rough 半圆仪表盘
/// （淡墨轨道 + 主题色马克笔进度弧 + 墨线指针）/ 0%-100% 刻度 / 底部余额。
/// 内容整体上下居中；仪表盘尺寸同时受宽高约束，任意尺寸下不再溢出。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 半圆仪表盘小组件
class HalfGaugeCardWidget extends StatefulWidget {
  final String title;
  final double totalBudget;
  final double remaining;
  final String currency;

  /// 组件尺寸
  final HomeWidgetSize size;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  const HalfGaugeCardWidget({
    super.key,
    this.title = 'Shopping',
    required this.totalBudget,
    required this.remaining,
    this.currency = 'AED',
    this.size = const MediumSize(),
    this.inline = false,
  });

  /// 从 props 创建实例
  factory HalfGaugeCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return HalfGaugeCardWidget(
      title: props['title'] as String? ?? 'Shopping',
      totalBudget: (props['totalBudget'] as num?)?.toDouble() ?? 0.0,
      remaining: (props['remaining'] as num?)?.toDouble() ?? 0.0,
      currency: props['currency'] as String? ?? 'AED',
      size: size,
      inline: props['inline'] as bool? ?? false,
    );
  }

  @override
  State<HalfGaugeCardWidget> createState() => _HalfGaugeCardWidgetState();
}

class _HalfGaugeCardWidgetState extends State<HalfGaugeCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  double get progress => widget.totalBudget <= 0
      ? 0.0
      : (widget.totalBudget - widget.remaining) / widget.totalBudget;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _progressAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HalfGaugeCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalBudget != widget.totalBudget ||
        oldWidget.remaining != widget.remaining) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 手绘描画入场：挂载即播一次，墨线「画出来」而非淡入
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(16 * scale),
        padding: widget.size.getPadding(),
        child: LayoutBuilder(
          builder: (context, constraints) =>
              _buildContent(theme, constraints),
        ),
      ),
    );
  }

  Widget _buildContent(
    AppThemeData theme,
    BoxConstraints constraints,
  ) {
    final gaugeTitleFontSize = widget.size.getTitleFontSize();
    final gaugeAmountFontSize = widget.size.getSubtitleFontSize() + 2;
    final gaugeIconSize = widget.size.getIconSize();
    final gaugeLabelFontSize = widget.size.getLegendFontSize();
    final gaugeRemainLabelFontSize = widget.size.getLegendFontSize() - 2;
    final gapUnit = widget.size.getSmallSpacing() * 2;

    // 仪表盘同时受宽度与高度预算约束，杜绝小尺寸下溢出：
    // 画布高 ≈ 宽 * 0.6（半圆 + 笔宽余量），刻度行可让位；
    // 预算按 0.62 折算、字体按 1.6 倍行高估，给手写字体留余量
    var gaugeWidth = constraints.maxWidth * 0.82;
    var showLabels = true;
    if (constraints.maxHeight.isFinite) {
      final reserved =
          gaugeTitleFontSize * 1.6 +
          gaugeAmountFontSize * 1.6 +
          gapUnit * 2;
      final withLabels =
          (constraints.maxHeight - reserved - gaugeLabelFontSize * 1.6) / 0.62;
      if (withLabels >= 64) {
        gaugeWidth = math.min(gaugeWidth, withLabels);
      } else {
        showLabels = false;
        gaugeWidth = math.min(
          gaugeWidth,
          (constraints.maxHeight - reserved) / 0.62,
        );
      }
    }
    gaugeWidth = math.max(gaugeWidth, 48);
    final showRemainBlock = gaugeWidth >= 96;

    final gaugeCanvasHeight = gaugeWidth * 0.6;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 标题
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: gaugeTitleFontSize,
              letterSpacing: 1.2,
              color: theme.textSub,
            ),
          ),

          SizedBox(height: gapUnit),

          // 半圆仪表盘 + 刻度
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: gaugeWidth,
                height: gaugeCanvasHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return CustomPaint(
                            size: Size(gaugeWidth, gaugeCanvasHeight),
                            painter: _HalfGaugePainter(
                              sweep: progress * _progressAnimation.value,
                              theme: theme,
                              inkProgress:
                                  WiredDrawTransition.progressOf(context),
                            ),
                          );
                        },
                      ),
                    ),
                    if (showRemainBlock)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: gaugeCanvasHeight * 0.08,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'REMAIN',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: gaugeRemainLabelFontSize,
                                letterSpacing: 1.5,
                                color: theme.textSub,
                              ),
                            ),
                            SizedBox(
                              height: widget.size.getSmallSpacing() * 2,
                            ),
                            DsIcon(
                              DsIconKind.cart,
                              size: gaugeIconSize,
                              color: theme.primary,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // 刻度标记
              if (showLabels)
                SizedBox(
                  width: gaugeWidth,
                  height: gaugeLabelFontSize * 1.6,
                  child: Stack(
                    children: [
                      for (final (label, align) in const [
                        ('0%', Alignment.centerLeft),
                        ('50%', Alignment.center),
                        ('100%', Alignment.centerRight),
                      ])
                        Align(
                          alignment: align,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: gaugeLabelFontSize,
                              color: theme.textSub,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),

          SizedBox(height: gapUnit),

          // 底部金额显示
          Text(
            '${_formatAmount(widget.remaining)}.${_getDecimalPart(widget.remaining)} / ${_formatAmount(widget.totalBudget)}.${_getDecimalPart(widget.totalBudget)} (${widget.currency})',
            style: TextStyle(
              fontSize: gaugeAmountFontSize,
              color: theme.text,
            ),
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  String _formatAmount(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    return parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _getDecimalPart(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    return parts[1];
  }
}

/// 仪表盘绘制器：淡墨 rough 轨道 + 主题色马克笔进度弧 + 墨线指针
///
/// [sweep] 为已消费进度（0~1，含入场动画插值）；[inkProgress] 消费外层
/// WiredDraw 的描画进度（null = 立即全画）。
class _HalfGaugePainter extends CustomPainter {
  final double sweep;
  final AppThemeData theme;
  final Animation<double>? inkProgress;

  _HalfGaugePainter({
    required this.sweep,
    required this.theme,
    this.inkProgress,
  }) : super(repaint: inkProgress);

  (double cx, double cy, double radius, double strokeWidth, double inset)
  _geometry(Size size) {
    final strokeWidth = math.max(3.0, size.width * 0.1);
    final cx = size.width / 2;
    final cy = size.height - strokeWidth * 0.9;
    final radius = size.width / 2 - strokeWidth / 2 - 1;
    final inset = math.asin(math.min(1.0, strokeWidth / (2 * radius)));
    return (cx, cy, radius, strokeWidth, inset);
  }

  Paint _inkPaint(double width, Color color) =>
      Paint()
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width
        ..color = color;

  @override
  void paint(Canvas canvas, Size size) {
    final drawConfig = theme.wired.drawConfig;
    final inkProgressValue = inkProgress?.value ?? 1;
    final (cx, cy, radius, strokeWidth, inset) = _geometry(size);
    final start = math.pi + inset;
    final span = math.pi - 2 * inset;

    // 淡墨轨道：留给马克笔「涂色」的底稿
    drawConfig.randomizer.reset();
    final trackGen = Generator(drawConfig, NoFiller());
    final trackPaint = _inkPaint(
      strokeWidth,
      theme.ink.withValues(alpha: 0.18),
    );
    RoughDrawing(
      trackGen.arc(cx, cy, radius * 2, radius * 2, start, start + span),
      trackPaint,
      trackPaint,
    ).paint(canvas, progress: inkProgressValue, pressure: 0);

    final s = sweep.clamp(0.0, 1.0);
    if (s <= 0.004) return;

    // 主题色进度弧：马克笔笔触
    drawConfig.randomizer.reset();
    final progressGen = Generator(drawConfig, NoFiller());
    final progressPaint = _inkPaint(strokeWidth, theme.primary);
    RoughDrawing(
      progressGen.arc(cx, cy, radius * 2, radius * 2, start, start + span * s),
      progressPaint,
      progressPaint,
    ).paint(canvas, progress: inkProgressValue, pressure: 0);

    // 指针：径向墨线小三角
    final pointerAngle = start + span * s;
    final dir = Offset(
      math.cos(pointerAngle),
      math.sin(pointerAngle),
    );
    final tang = Offset(-dir.dy, dir.dx);
    final ps = math.max(3.0, strokeWidth * 0.38);
    final tipR = radius + strokeWidth * 0.55;
    final baseR = radius - strokeWidth * 0.55;
    Offset polar(double r, double t) =>
        Offset(cx, cy) + dir * r + tang * t;
    drawConfig.randomizer.reset();
    final pointerGen = Generator(drawConfig, SolidFiller());
    final fill =
        Paint()
          ..style = PaintingStyle.fill
          ..isAntiAlias = true
          ..color = theme.ink;
    final outline = _inkPaint(1.4, theme.ink);
    RoughDrawing(
      pointerGen.polygon([
        PointD(polar(tipR, 0).dx, polar(tipR, 0).dy),
        PointD(polar(baseR, ps).dx, polar(baseR, ps).dy),
        PointD(polar(baseR, -ps).dx, polar(baseR, -ps).dy),
      ]),
      outline,
      fill,
    ).paint(canvas, progress: inkProgressValue, pressure: 0);
  }

  @override
  bool shouldRepaint(covariant _HalfGaugePainter oldDelegate) {
    return oldDelegate.sweep != sweep || oldDelegate.theme != theme;
  }
}
