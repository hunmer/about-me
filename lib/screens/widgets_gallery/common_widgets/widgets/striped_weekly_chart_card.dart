import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

class StripedWeeklyBarData {
  final String label;
  final double value;
  final String valueLabel;

  const StripedWeeklyBarData({
    required this.label,
    required this.value,
    this.valueLabel = '',
  });
}

class StripedWeeklyChartCardWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<StripedWeeklyBarData> items;
  final int initialSelectedIndex;
  final IconData icon;
  final Color activeColor;
  final Color activeBackgroundColor;
  final ValueChanged<int>? onSelected;
  final bool inline;
  final HomeWidgetSize size;

  const StripedWeeklyChartCardWidget({
    super.key,
    this.title = '',
    this.subtitle = '',
    this.items = const [],
    this.initialSelectedIndex = 0,
    this.icon = Icons.pie_chart_rounded,
    this.activeColor = const Color(0xFFD972F8),
    this.activeBackgroundColor = const Color(0xFFF3C4FF),
    this.onSelected,
    this.inline = false,
    this.size = const Large3Size(),
  });

  factory StripedWeeklyChartCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final rawItems = props['items'];
    final items = rawItems is List
        ? rawItems.map((item) {
            if (item is StripedWeeklyBarData) return item;
            final map = item is Map ? item : const <String, dynamic>{};
            return StripedWeeklyBarData(
              label: map['label'] as String? ?? '',
              value: (map['value'] as num?)?.toDouble() ?? 0,
              valueLabel: map['valueLabel'] as String? ?? '',
            );
          }).toList()
        : <StripedWeeklyBarData>[];

    return StripedWeeklyChartCardWidget(
      title: props['title'] as String? ?? '',
      subtitle: props['subtitle'] as String? ?? '',
      items: items,
      initialSelectedIndex:
          (props['initialSelectedIndex'] as num?)?.toInt() ?? 0,
      icon: _parseIcon(props['icon'], Icons.pie_chart_rounded),
      activeColor: _parseColor(props['activeColor'], const Color(0xFFD972F8)),
      activeBackgroundColor: _parseColor(
        props['activeBackgroundColor'],
        const Color(0xFFF3C4FF),
      ),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<StripedWeeklyChartCardWidget> createState() =>
      _StripedWeeklyChartCardWidgetState();
}

class _StripedWeeklyChartCardWidgetState
    extends State<StripedWeeklyChartCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _validSelectedIndex();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant StripedWeeklyChartCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSelectedIndex != widget.initialSelectedIndex ||
        oldWidget.items.length != widget.items.length) {
      _selectedIndex = _validSelectedIndex();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _validSelectedIndex() {
    if (widget.items.isEmpty) return -1;
    return widget.initialSelectedIndex
        .clamp(0, widget.items.length - 1)
        .toInt();
  }

  double get _height {
    final scale = widget.size.scale;
    if (widget.size is Wide2Size) return 330 * scale;
    return 430 * scale;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = widget.size.scale;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - _animation.value)),
            child: Container(
              width: widget.inline ? double.maxFinite : 384 * scale,
              height: widget.inline ? double.maxFinite : _height,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF9FBFD),
                borderRadius: BorderRadius.circular(30 * scale),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.white,
                  width: scale,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.28 : 0.05),
                    blurRadius: 20 * scale,
                    offset: Offset(0, 5 * scale),
                  ),
                ],
              ),
              child: Padding(
                padding: widget.size.getPadding(),
                child: Column(
                  children: [
                    _buildHeader(isDark),
                    SizedBox(height: 14 * scale),
                    Expanded(child: _buildChart(isDark, _animation.value)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    final scale = widget.size.scale;
    return Row(
      children: [
        Container(
          width: 44 * scale,
          height: 44 * scale,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFDCE4EC),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? Colors.white24 : const Color(0xFF222222),
              width: scale,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 24 * scale,
            color: isDark ? Colors.white : const Color(0xFF3B82F6),
          ),
        ),
        SizedBox(width: 12 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF141414),
                  fontSize: widget.size.getSubtitleFontSize() + 2 * scale,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.subtitle.isNotEmpty) ...[
                SizedBox(height: 3 * scale),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF7C8088),
                    fontSize: widget.size.getLegendFontSize(),
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChart(bool isDark, double progress) {
    final scale = widget.size.scale;
    final maxValue = widget.items.fold<double>(
      0,
      (maximum, item) => math.max(maximum, item.value),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 220 * scale;
        final topInset = 34 * scale;
        final bottomInset = 30 * scale;
        final maxBarHeight = math.max(
          0.0,
          chartHeight - topInset - bottomInset,
        );

        return SizedBox(
          height: chartHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _DashedGridPainter(
                    color: isDark
                        ? const Color(0xFF475569)
                        : const Color(0xFFE2E6EA),
                    topInset: topInset,
                    bottomInset: bottomInset,
                    scale: scale,
                  ),
                ),
              ),
              Row(
                children: [
                  for (var index = 0; index < widget.items.length; index++)
                    Expanded(
                      child: _buildBarColumn(
                        index: index,
                        maxValue: maxValue,
                        maxBarHeight: maxBarHeight,
                        topInset: topInset,
                        progress: progress,
                        isDark: isDark,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBarColumn({
    required int index,
    required double maxValue,
    required double maxBarHeight,
    required double topInset,
    required double progress,
    required bool isDark,
  }) {
    final item = widget.items[index];
    final selected = index == _selectedIndex;
    final scale = widget.size.scale;
    final ratio = maxValue > 0 ? (item.value / maxValue).clamp(0.0, 1.0) : 0.0;
    final barHeight = maxBarHeight * ratio * progress;
    final valueLabel = item.valueLabel.isEmpty
        ? item.value.toStringAsFixed(1)
        : item.valueLabel;

    return GestureDetector(
      key: ValueKey('striped-weekly-bar-$index'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _selectedIndex = index);
        widget.onSelected?.call(index);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 3 * scale),
        child: Column(
          children: [
            SizedBox(
              height: topInset + maxBarHeight,
              child: Stack(
                children: [
                  Positioned(
                    left: 2 * scale,
                    right: 2 * scale,
                    bottom: 0,
                    height: barHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100 * scale),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: widget.activeColor.withOpacity(0.35),
                                  blurRadius: 14 * scale,
                                  offset: Offset(0, 6 * scale),
                                ),
                              ]
                            : null,
                      ),
                      child: CustomPaint(
                        painter: _StripedBarPainter(
                          selected: selected,
                          activeColor: widget.activeColor,
                          activeBackgroundColor: widget.activeBackgroundColor,
                          isDark: isDark,
                          scale: scale,
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: barHeight + 4 * scale,
                      child: Center(child: _BarTooltip(text: valueLabel)),
                    ),
                ],
              ),
            ),
            SizedBox(height: 8 * scale),
            SizedBox(
              height: 22 * scale,
              child: Text(
                item.label,
                style: TextStyle(
                  color: selected
                      ? (isDark ? Colors.white : const Color(0xFF141414))
                      : (isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF52555C)),
                  fontSize: widget.size.getLegendFontSize(),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarTooltip extends StatelessWidget {
  final String text;

  const _BarTooltip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0C14),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
            maxLines: 1,
          ),
        ),
        CustomPaint(
          size: const Size(10, 5),
          painter: const _TooltipArrowPainter(color: Color(0xFF0F0C14)),
        ),
      ],
    );
  }
}

class _TooltipArrowPainter extends CustomPainter {
  final Color color;

  const _TooltipArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TooltipArrowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _StripedBarPainter extends CustomPainter {
  final bool selected;
  final Color activeColor;
  final Color activeBackgroundColor;
  final bool isDark;
  final double scale;

  const _StripedBarPainter({
    required this.selected,
    required this.activeColor,
    required this.activeBackgroundColor,
    required this.isDark,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = Radius.circular(size.width / 2);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, radius);
    final background = selected
        ? activeBackgroundColor
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE4E6E9));
    final stripe = selected
        ? activeColor
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF9BA0A8));
    final border = selected
        ? activeColor.withOpacity(0.85)
        : (isDark ? const Color(0xFF64748B) : const Color(0xFF595959));

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, Paint()..color = background);
    final stripePaint = Paint()
      ..color = stripe.withOpacity(selected ? 0.9 : 0.45)
      ..strokeWidth = (selected ? 3 : 1.5) * scale
      ..style = PaintingStyle.stroke;
    final spacing = 6.5 * scale;
    for (var x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height * 0.85, 0),
        stripePaint,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _StripedBarPainter oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.activeBackgroundColor != activeBackgroundColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.scale != scale;
  }
}

class _DashedGridPainter extends CustomPainter {
  final Color color;
  final double topInset;
  final double bottomInset;
  final double scale;

  const _DashedGridPainter({
    required this.color,
    required this.topInset,
    required this.bottomInset,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final availableHeight = math.max(0.0, size.height - topInset - bottomInset);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2 * scale;
    const dashCount = 4;
    for (var row = 0; row < dashCount; row++) {
      final y = topInset + availableHeight * row / (dashCount - 1);
      for (var x = 0.0; x < size.width; x += 10 * scale) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 5 * scale, size.width), y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.topInset != topInset ||
        oldDelegate.bottomInset != bottomInset ||
        oldDelegate.scale != scale;
  }
}

Color _parseColor(dynamic value, Color fallback) {
  if (value is Color) return value;
  if (value is int) return Color(value);
  if (value is String) {
    try {
      final hex = value.startsWith('#')
          ? value.substring(1)
          : value.startsWith('0x')
          ? value.substring(2)
          : '';
      if (hex.length == 6) {
        return Color(0xFF000000 | int.parse(hex, radix: 16));
      }
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return fallback;
    }
  }
  return fallback;
}

IconData _parseIcon(dynamic value, IconData fallback) {
  if (value is IconData) return value;
  final codePoint = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  if (codePoint == null) return fallback;
  return dynamicIconData(codePoint, fontFamily: 'MaterialIcons');
}
