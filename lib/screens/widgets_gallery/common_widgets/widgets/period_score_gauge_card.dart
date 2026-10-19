import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = widget.size.scale;
    final height = (widget.size is Wide2Size ? 360.0 : 430.0) * scale;
    final selected =
        _selectedIndex >= 0 && _selectedIndex < widget.periods.length
        ? widget.periods[_selectedIndex]
        : null;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - _animation.value)),
            child: Container(
              width: widget.inline ? double.maxFinite : 384 * scale,
              height: widget.inline ? double.maxFinite : height,
              padding: EdgeInsets.all(16 * scale),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : null,
                gradient: isDark
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFE3E8E8),
                          Color(0xFFEEF1F3),
                          Color(0xFFF7F8FA),
                        ],
                      ),
                borderRadius: BorderRadius.circular(36 * scale),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.28 : 0.08),
                    blurRadius: 24 * scale,
                    offset: Offset(0, 8 * scale),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildPeriodSwitcher(isDark),
                  SizedBox(height: 16 * scale),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16 * scale),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF4C4460)
                            : const Color(0xFFD9CEE8),
                        borderRadius: BorderRadius.circular(34 * scale),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44 * scale,
                                height: 44 * scale,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEDF2F3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.pie_chart_outline_rounded,
                                  size: 22 * scale,
                                  color: const Color(0xFF1A2225),
                                ),
                              ),
                              SizedBox(width: 12 * scale),
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1A2125),
                                    fontSize: 19 * scale,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8 * scale),
                          Expanded(
                            child: selected == null
                                ? const SizedBox.shrink()
                                : _ScoreGauge(
                                    data: selected,
                                    label: widget.scoreLabel,
                                    progress: _animation.value,
                                    isDark: isDark,
                                    scale: scale,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPeriodSwitcher(bool isDark) {
    final scale = widget.size.scale;
    return Container(
      height: 48 * scale,
      padding: EdgeInsets.all(4 * scale),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FBFC),
        borderRadius: BorderRadius.circular(30 * scale),
        border: Border.all(color: isDark ? Colors.white10 : Colors.white),
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: index == _selectedIndex
                        ? const Color(0xFF1A2125)
                        : (isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFECEFF0)),
                    borderRadius: BorderRadius.circular(24 * scale),
                  ),
                  child: Text(
                    widget.periods[index].label,
                    style: TextStyle(
                      color: index == _selectedIndex
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF1A2125)),
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
  final bool isDark;
  final double scale;

  const _ScoreGauge({
    required this.data,
    required this.label,
    required this.progress,
    required this.isDark,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _HorseshoeGaugePainter(
                progress: data.progress.clamp(0.0, 1.0).toDouble() * progress,
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
                    color: isDark ? Colors.white : const Color(0xFF1A2125),
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
                    color: isDark ? Colors.white70 : const Color(0xFF4A4857),
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

class _HorseshoeGaugePainter extends CustomPainter {
  final double progress;
  final double scale;

  const _HorseshoeGaugePainter({required this.progress, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;
    final strokeWidth = 24 * scale;
    final radius = math.min(size.width * 0.36, size.height * 0.4);
    final center = Offset(size.width / 2, size.height * 0.52);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = const Color(0xFFFAF9F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepAngle, false, track);

    if (progress > 0) {
      final activeSweep = sweepAngle * progress;
      canvas.drawArc(
        rect,
        startAngle + sweepAngle - activeSweep,
        activeSweep,
        false,
        Paint()
          ..color = const Color(0xFFFBE59B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    final innerRect = Rect.fromCircle(
      center: center,
      radius: math.max(0.0, radius - 25 * scale),
    );
    final dashPaint = Paint()
      ..color = const Color(0xFFFAF9F5)
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

  @override
  bool shouldRepaint(covariant _HorseshoeGaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.scale != scale;
}
