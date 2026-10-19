import 'package:flutter/material.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

class CutoutStatItemData {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color backgroundColor;
  final Color iconBackgroundColor;
  final Color iconColor;

  const CutoutStatItemData({
    required this.label,
    required this.value,
    this.unit = '',
    required this.icon,
    required this.backgroundColor,
    required this.iconBackgroundColor,
    this.iconColor = const Color(0xFF222222),
  });
}

class CutoutStatGridCardWidget extends StatefulWidget {
  final String title;
  final List<CutoutStatItemData> items;
  final Color? backgroundColor;
  final bool inline;
  final HomeWidgetSize size;

  const CutoutStatGridCardWidget({
    super.key,
    this.title = '',
    this.items = const [],
    this.backgroundColor,
    this.inline = false,
    this.size = const Large3Size(),
  });

  factory CutoutStatGridCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final rawItems = props['items'];
    final items = rawItems is List
        ? rawItems.map((item) {
            if (item is CutoutStatItemData) return item;
            final map = item is Map ? item : const <String, dynamic>{};
            return CutoutStatItemData(
              label: map['label'] as String? ?? '',
              value: map['value']?.toString() ?? '0',
              unit: map['unit'] as String? ?? '',
              icon: _parseIcon(map['icon'], Icons.school_rounded),
              backgroundColor: _parseColor(
                map['backgroundColor'],
                const Color(0xFFC8B9EC),
              ),
              iconBackgroundColor: _parseColor(
                map['iconBackgroundColor'],
                const Color(0xFFDCD2F5),
              ),
              iconColor: _parseColor(map['iconColor'], const Color(0xFF222222)),
            );
          }).toList()
        : <CutoutStatItemData>[];

    return CutoutStatGridCardWidget(
      title: props['title'] as String? ?? '',
      items: items,
      backgroundColor: props['backgroundColor'] == null
          ? null
          : _parseColor(props['backgroundColor'], const Color(0xFFEEF2F5)),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<CutoutStatGridCardWidget> createState() =>
      _CutoutStatGridCardWidgetState();
}

class _CutoutStatGridCardWidgetState extends State<CutoutStatGridCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
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

  double get _height {
    final scale = widget.size.scale;
    if (widget.size is Large3Size) return 340 * scale;
    return 240 * scale;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = widget.size.scale;
    final backgroundColor =
        widget.backgroundColor ??
        (isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F5));

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - _animation.value)),
            child: child,
          ),
        );
      },
      child: Container(
        width: widget.inline ? double.maxFinite : 384 * scale,
        height: widget.inline ? double.maxFinite : _height,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(30 * scale),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.title.isNotEmpty) ...[
                Text(
                  widget.title,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF121212),
                    fontSize: widget.size.getTitleFontSize(),
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 14 * scale),
              ],
              Expanded(
                child: Row(
                  children: [
                    for (
                      var index = 0;
                      index < widget.items.length;
                      index++
                    ) ...[
                      if (index > 0) SizedBox(width: 9 * scale),
                      Expanded(
                        child: _CutoutStatItem(
                          data: widget.items[index],
                          cutoutColor: backgroundColor,
                          size: widget.size,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CutoutStatItem extends StatelessWidget {
  final CutoutStatItemData data;
  final Color cutoutColor;
  final HomeWidgetSize size;
  final bool isDark;

  const _CutoutStatItem({
    required this.data,
    required this.cutoutColor,
    required this.size,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final scale = size.scale;
    return Container(
      decoration: BoxDecoration(
        color: data.backgroundColor,
        borderRadius: BorderRadius.circular(26 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.04),
            blurRadius: 12 * scale,
            offset: Offset(0, 3 * scale),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26 * scale),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: SizedBox(
                width: 66 * scale,
                height: 66 * scale,
                child: CustomPaint(
                  painter: _CutoutCornerPainter(
                    color: cutoutColor,
                    scale: scale,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 5 * scale,
              left: 5 * scale,
              child: Container(
                width: 43 * scale,
                height: 43 * scale,
                decoration: BoxDecoration(
                  color: data.iconBackgroundColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.28),
                    width: 2 * scale,
                  ),
                ),
                child: Icon(data.icon, color: data.iconColor, size: 23 * scale),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12 * scale,
                  62 * scale,
                  12 * scale,
                  13 * scale,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.label,
                      style: TextStyle(
                        color: const Color(0xFF18181B),
                        fontSize: size.getSubtitleFontSize(),
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: data.value,
                            style: TextStyle(
                              color: const Color(0xFF111111),
                              fontSize: size.getTitleFontSize() * 1.15,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          if (data.unit.isNotEmpty)
                            TextSpan(
                              text: ' ${data.unit}',
                              style: TextStyle(
                                color: const Color(
                                  0xFF18181B,
                                ).withOpacity(0.55),
                                fontSize: size.getLegendFontSize(),
                                fontWeight: FontWeight.w500,
                                height: 1,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CutoutCornerPainter extends CustomPainter {
  final Color color;
  final double scale;

  const _CutoutCornerPainter({required this.color, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final side = 50 * scale;
    final curve = 16 * scale;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, side, side),
        bottomRight: Radius.circular(26 * scale),
      ),
      paint,
    );

    for (final rect in [
      Rect.fromLTWH(side, 0, curve, curve),
      Rect.fromLTWH(0, side, curve, curve),
    ]) {
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect)
        ..addOval(Rect.fromCircle(center: rect.bottomRight, radius: curve));
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CutoutCornerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.scale != scale;
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
