/// 周期评分仪表盘卡片（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 周期切换手绘分段胶囊 / 手绘圆底图标徽章 + 标题 / 马蹄形斜纹仪表盘
///（主题色斜纹进度扇环 + 淡墨轨道 + 内圈墨线虚刻度）+ 中心分数。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

class ScorePeriodData {
  final String label;
  final String score;
  final double progress;

  const ScorePeriodData({
    required this.label,
    required this.score,
    required this.progress,
  });
}

class PeriodScoreGaugeCardWidget extends StatefulWidget {
  final String title;
  final String scoreLabel;
  final List<ScorePeriodData> periods;
  final int initialSelectedIndex;
  final ValueChanged<int>? onSelected;
  final bool inline;
  final HomeWidgetSize size;

  const PeriodScoreGaugeCardWidget({
    super.key,
    this.title = 'Progress',
    this.scoreLabel = 'Score',
    this.periods = const [],
    this.initialSelectedIndex = 0,
    this.onSelected,
    this.inline = false,
    this.size = const Large3Size(),
  });

  factory PeriodScoreGaugeCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final rawPeriods = props['periods'];
    final periods = rawPeriods is List
        ? rawPeriods.map((item) {
            if (item is ScorePeriodData) return item;
            final map = item is Map ? item : const <String, dynamic>{};
            return ScorePeriodData(
              label: map['label'] as String? ?? '',
              score: map['score']?.toString() ?? '0',
              progress: (map['progress'] as num?)?.toDouble() ?? 0,
            );
          }).toList()
        : <ScorePeriodData>[];
    return PeriodScoreGaugeCardWidget(
      title: props['title'] as String? ?? 'Progress',
      scoreLabel: props['scoreLabel'] as String? ?? 'Score',
      periods: periods,
      initialSelectedIndex:
          (props['initialSelectedIndex'] as num?)?.toInt() ?? 0,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<PeriodScoreGaugeCardWidget> createState() =>
      _PeriodScoreGaugeCardWidgetState();
}

class _PeriodScoreGaugeCardWidgetState extends State<PeriodScoreGaugeCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _validIndex();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant PeriodScoreGaugeCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periods.length != widget.periods.length ||
        oldWidget.initialSelectedIndex != widget.initialSelectedIndex) {
      _selectedIndex = _validIndex();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _validIndex() {
    if (widget.periods.isEmpty) return -1;
    return widget.initialSelectedIndex
        .clamp(0, widget.periods.length - 1)
        .toInt();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;
    final height = (widget.size is Wide2Size ? 360.0 : 430.0) * scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 384 * scale,
        height: widget.inline ? double.maxFinite : height,
        radius: BorderRadius.circular(24 * scale),
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          children: [
            _buildPeriodSwitcher(theme),
            SizedBox(height: 16 * scale),
            Expanded(
              child: Column(
                children: [
                  _buildHeader(theme),
                  SizedBox(height: 8 * scale),
                  Expanded(
                    child: _selectedIndex >= 0 &&
                            _selectedIndex < widget.periods.length
                        ? AnimatedBuilder(
                            animation: _animation,
                            builder: (context, _) => _ScoreGauge(
                              data: widget.periods[_selectedIndex],
                              label: widget.scoreLabel,
                              progress: _animation.value,
                              theme: theme,
                              scale: scale,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 头部：手绘圆底图标徽章 + 标题
  Widget _buildHeader(AppThemeData theme) {
    final scale = widget.size.scale;
    final badgeSize = 44 * scale;
    return Row(
      children: [
        Container(
          width: badgeSize,
          height: badgeSize,
          // 大圆角被 rough 引擎自动钳制成圆
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(badgeSize / 2),
            fillColor: theme.surfaceAlt,
          ),
          child: Center(
            child: WiredIcon(
              icon: Icons.pie_chart_outline_rounded,
              size: 22 * scale,
              color: theme.text,
              drawConfig: theme.wired.drawConfig,
            ),
          ),
        ),
        SizedBox(width: 12 * scale),
        Expanded(
          child: Text(
            widget.title,
            style: TextStyle(
              color: theme.text,
              fontSize: 19 * scale,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 周期切换：手绘分段胶囊（选中墨线实底，未选中透明淡字）
  Widget _buildPeriodSwitcher(AppThemeData theme) {
    final scale = widget.size.scale;
    return Container(
      height: 48 * scale,
      padding: EdgeInsets.all(4 * scale),
      decoration: dsSketchDecoration(
        theme: theme,
        // 大圆角被 rough 引擎自动钳制成胶囊
        radius: BorderRadius.circular(24 * scale),
        fillColor: theme.surfaceAlt,
      ),
      child: Row(
        children: [
          for (var index = 0; index < widget.periods.length; index++) ...[
            if (index > 0) SizedBox(width: 4 * scale),
            Expanded(
              child: GestureDetector(
                key: ValueKey('score-period-$index'),
                onTap: () {
                  setState(() => _selectedIndex = index);
                  widget.onSelected?.call(index);
                },
                child: Container(
                  height: double.infinity,
                  alignment: Alignment.center,
                  decoration: index == _selectedIndex
                      ? dsSketchDecoration(
                          theme: theme,
                          radius: BorderRadius.circular(20 * scale),
                          fillColor: theme.ink,
                        )
                      : null,
                  child: Text(
                    widget.periods[index].label,
                    style: TextStyle(
                      color: index == _selectedIndex
                          ? theme.surface
                          : theme.textSub,
                      fontSize: 13 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreGauge extends StatelessWidget {
  final ScorePeriodData data;
  final String label;
  final double progress;
  final AppThemeData theme;
  final double scale;

  const _ScoreGauge({
    required this.data,
    required this.label,
    required this.progress,
    required this.theme,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      // expand：Expanded 内横向是宽松约束，靠文字子级撑尺寸会把
      // 仪表画布缩成文字宽
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _HorseshoeGaugePainter(
                progress: data.progress.clamp(0.0, 1.0).toDouble() * progress,
                theme: theme,
                scale: scale,
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.score,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 40 * scale,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ),
                SizedBox(height: 6 * scale),
                Text(
                  label,
                  style: TextStyle(
                    color: theme.textSub,
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 马蹄形仪表盘绘制器（平直几何 + 斜纹）
///
/// 淡墨轨道扇环（270° 马蹄）垫底，主题色进度扇环（浅底 + 浓斜纹 +
/// 描边）自末端回扫生长，内圈保留墨线虚线刻度环。
class _HorseshoeGaugePainter extends CustomPainter {
  final double progress;
  final AppThemeData theme;
  final double scale;

  const _HorseshoeGaugePainter({
    required this.progress,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;
    final strokeWidth = 24 * scale;
    final radius = math.min(size.width * 0.36, size.height * 0.4);
    final center = Offset(size.width / 2, size.height * 0.52);
    final rOut = radius + strokeWidth / 2;
    final rIn = radius - strokeWidth / 2;
    final bounds = Offset.zero & size;

    // 轨道：淡墨底 + 低透明度斜纹 + 淡描边
    final trackPath = _sector(center, rIn, rOut, startAngle, startAngle + sweepAngle);
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

    // 进度扇环：主题色浅底 + 浓斜纹 + 描边（自末端回扫生长）
    if (progress > 0.004) {
      final activeSweep = sweepAngle * progress;
      final activePath = _sector(
        center,
        rIn,
        rOut,
        startAngle + sweepAngle - activeSweep,
        startAngle + sweepAngle,
      );
      canvas.drawPath(
        activePath,
        Paint()..color = theme.primary.withValues(alpha: 0.28),
      );
      paintDiagonalStripes(
        canvas,
        activePath,
        bounds,
        color: theme.primary.withValues(alpha: 0.9),
        strokeWidth: 3 * scale,
        spacing: 6.5 * scale,
      );
      canvas.drawPath(
        activePath,
        Paint()
          ..color = theme.primary.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );
    }

    // 内圈墨线虚线刻度环
    final innerRect = Rect.fromCircle(
      center: center,
      radius: math.max(0.0, radius - 25 * scale),
    );
    final dashPaint = Paint()
      ..color = theme.ink.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5 * scale
      ..strokeCap = StrokeCap.round;
    const dash = math.pi / 7;
    const gap = math.pi / 24;
    for (
      var angle = startAngle;
      angle < startAngle + sweepAngle;
      angle += dash + gap
    ) {
      final end = math.min(angle + dash, startAngle + sweepAngle);
      canvas.drawArc(innerRect, angle, end - angle, false, dashPaint);
    }
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
  bool shouldRepaint(covariant _HorseshoeGaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.theme != theme ||
      oldDelegate.scale != scale;
}
