import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

class MonthlyCapsuleData {
  final String label;
  final String value;
  final String unit;
  final String badge;
  final double progress;
  final Color color;

  const MonthlyCapsuleData({
    required this.label,
    required this.value,
    this.unit = '',
    required this.badge,
    required this.progress,
    required this.color,
  });
}

class MonthlyCapsuleChartCardWidget extends StatefulWidget {
  final String title;
  final List<MonthlyCapsuleData> items;
  final bool inline;
  final HomeWidgetSize size;

  const MonthlyCapsuleChartCardWidget({
    super.key,
    this.title = 'Progress',
    this.items = const [],
    this.inline = false,
    this.size = const Large3Size(),
  });

  factory MonthlyCapsuleChartCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final rawItems = props['items'];
    final items = rawItems is List
        ? rawItems.map((item) {
            if (item is MonthlyCapsuleData) return item;
            final map = item is Map ? item : const <String, dynamic>{};
            return MonthlyCapsuleData(
              label: map['label'] as String? ?? '',
              value: map['value']?.toString() ?? '0',
              unit: map['unit'] as String? ?? '',
              badge: map['badge']?.toString() ?? '',
              progress: (map['progress'] as num?)?.toDouble() ?? 0,
              color: _parseColor(map['color'], const Color(0xFFC7B3E8)),
            );
          }).toList()
        : <MonthlyCapsuleData>[];
    return MonthlyCapsuleChartCardWidget(
      title: props['title'] as String? ?? 'Progress',
      items: items,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<MonthlyCapsuleChartCardWidget> createState() =>
      _MonthlyCapsuleChartCardWidgetState();
}

class _MonthlyCapsuleChartCardWidgetState
    extends State<MonthlyCapsuleChartCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = widget.size.scale;
    final height = (widget.size is Wide2Size ? 350.0 : 430.0) * scale;
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
                  Row(
                    children: [
                      Container(
                        width: 52 * scale,
                        height: 52 * scale,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFEAEEEF),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.white,
                          ),
                        ),
                        child: Icon(
                          Icons.pie_chart_outline_rounded,
                          size: 24 * scale,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A2125),
                        ),
                      ),
                      SizedBox(width: 14 * scale),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A2125),
                            fontSize: 22 * scale,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16 * scale),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16 * scale),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF4C4460)
                            : const Color(0xFFD9CEE8),
                        borderRadius: BorderRadius.circular(36 * scale),
                      ),
                      child: Row(
                        children: [
                          for (
                            var index = 0;
                            index < widget.items.length;
                            index++
                          ) ...[
                            if (index > 0) SizedBox(width: 12 * scale),
                            Expanded(
                              child: _MonthlyCapsuleColumn(
                                data: widget.items[index],
                                progress: _animation.value,
                                isDark: isDark,
                              ),
                            ),
                          ],
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
}

class _MonthlyCapsuleColumn extends StatelessWidget {
  final MonthlyCapsuleData data;
  final double progress;
  final bool isDark;

  const _MonthlyCapsuleColumn({
    required this.data,
    required this.progress,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fillHeight =
                  constraints.maxHeight *
                  data.progress.clamp(0.0, 1.0).toDouble() *
                  progress;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MonthlyTrackPainter(isDark: isDark),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: fillHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: data.color,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: fillHeight < 44
                          ? null
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  data.value,
                                  style: const TextStyle(
                                    color: Color(0xFF182026),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                                  maxLines: 1,
                                ),
                                if (data.unit.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    data.unit,
                                    style: const TextStyle(
                                      color: Color(0xFF3B3A35),
                                      fontSize: 11,
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
                  ),
                  if (data.badge.isNotEmpty && fillHeight > 30)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: fillHeight - 12,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF182026),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            data.badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          data.label,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF182026),
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _MonthlyTrackPainter extends CustomPainter {
  final bool isDark;

  const _MonthlyTrackPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.width / 2),
    );
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      rect,
      Paint()
        ..color = isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
    );
    final stripe = Paint()
      ..color = isDark ? const Color(0xFF64748B) : const Color(0xFFE4E7EC)
      ..strokeWidth = 6;
    for (var x = -size.height; x < size.width + size.height; x += 13) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripe,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MonthlyTrackPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
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
      if (hex.length == 6) return Color(0xFF000000 | int.parse(hex, radix: 16));
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return fallback;
    }
  }
  return fallback;
}
