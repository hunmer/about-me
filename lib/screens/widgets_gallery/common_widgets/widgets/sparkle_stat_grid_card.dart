import 'package:flutter/material.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

class SparkleStatItemData {
  final String label;
  final String value;
  final IconData icon;
  final Color backgroundColor;
  final Color iconBackgroundColor;

  const SparkleStatItemData({
    required this.label,
    required this.value,
    required this.icon,
    required this.backgroundColor,
    required this.iconBackgroundColor,
  });
}

class SparkleStatGridCardWidget extends StatefulWidget {
  final List<SparkleStatItemData> items;
  final bool inline;
  final HomeWidgetSize size;

  const SparkleStatGridCardWidget({
    super.key,
    this.items = const [],
    this.inline = false,
    this.size = const Large3Size(),
  });

  factory SparkleStatGridCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final rawItems = props['items'];
    final items = rawItems is List
        ? rawItems.map((item) {
            if (item is SparkleStatItemData) return item;
            final map = item is Map ? item : const <String, dynamic>{};
            return SparkleStatItemData(
              label: map['label'] as String? ?? '',
              value: map['value']?.toString() ?? '0',
              icon: _parseIcon(map['icon'], Icons.verified_outlined),
              backgroundColor: _parseColor(
                map['backgroundColor'],
                const Color(0xFFCBE0DC),
              ),
              iconBackgroundColor: _parseColor(
                map['iconBackgroundColor'],
                const Color(0xFFEEF5F4),
              ),
            );
          }).toList()
        : <SparkleStatItemData>[];
    return SparkleStatGridCardWidget(
      items: items,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<SparkleStatGridCardWidget> createState() =>
      _SparkleStatGridCardWidgetState();
}

class _SparkleStatGridCardWidgetState extends State<SparkleStatGridCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 850),
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
    final height = (widget.size is Large3Size ? 300.0 : 220.0) * scale;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Opacity(
        opacity: _animation.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - _animation.value)),
          child: child,
        ),
      ),
      child: Container(
        width: widget.inline ? double.maxFinite : 384 * scale,
        height: widget.inline ? double.maxFinite : height,
        padding: EdgeInsets.all(14 * scale),
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
        child: Row(
          children: [
            for (var index = 0; index < widget.items.length; index++) ...[
              if (index > 0) SizedBox(width: 12 * scale),
              Expanded(child: _SparkleStatItem(data: widget.items[index])),
            ],
          ],
        ),
      ),
    );
  }
}

class _SparkleStatItem extends StatelessWidget {
  final SparkleStatItemData data;

  const _SparkleStatItem({required this.data});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        color: data.backgroundColor,
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _SparklePainter(color: Colors.white.withOpacity(0.32)),
              ),
            ),
            Positioned(
              right: -14,
              bottom: -16,
              child: Transform.rotate(
                angle: -0.24,
                child: Icon(
                  Icons.auto_stories_outlined,
                  size: 88,
                  color: Colors.white.withOpacity(0.25),
                ),
              ),
            ),
            Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: data.iconBackgroundColor,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 2),
                        ],
                      ),
                      child: Icon(
                        data.icon,
                        size: 22,
                        color: const Color(0xFF1B2428),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        data.label,
                        style: const TextStyle(
                          color: Color(0xFF1A2225),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data.value,
                    style: const TextStyle(
                      color: Color(0xFF1A2225),
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;

  const _SparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final entry in [
      (0.72, 0.14, 11.0),
      (0.52, 0.42, 13.0),
      (0.86, 0.38, 7.0),
    ]) {
      final center = Offset(size.width * entry.$1, size.height * entry.$2);
      final radius = entry.$3;
      final path = Path()
        ..moveTo(center.dx, center.dy - radius)
        ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
        ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
        ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
        ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.color != color;
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

IconData _parseIcon(dynamic value, IconData fallback) {
  if (value is IconData) return value;
  final codePoint = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  return codePoint == null
      ? fallback
      : dynamicIconData(codePoint, fontFamily: 'MaterialIcons');
}
