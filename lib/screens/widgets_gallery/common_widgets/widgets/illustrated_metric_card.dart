import 'package:flutter/material.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

class IllustratedMetricData {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color backgroundColor;
  final Color illustrationBackgroundColor;
  final Color iconColor;

  const IllustratedMetricData({
    required this.title,
    required this.value,
    this.unit = '',
    required this.icon,
    required this.backgroundColor,
    required this.illustrationBackgroundColor,
    this.iconColor = const Color(0xFF5B34AD),
  });
}

class IllustratedMetricCardWidget extends StatefulWidget {
  final IllustratedMetricData data;
  final bool showAction;
  final IconData actionIcon;
  final Color? actionCutoutColor;
  final VoidCallback? onAction;
  final bool inline;
  final HomeWidgetSize size;

  const IllustratedMetricCardWidget({
    super.key,
    required this.data,
    this.showAction = true,
    this.actionIcon = Icons.north_east_rounded,
    this.actionCutoutColor,
    this.onAction,
    this.inline = false,
    this.size = const Large3Size(),
  });

  factory IllustratedMetricCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return IllustratedMetricCardWidget(
      data: IllustratedMetricData(
        title: props['title'] as String? ?? '',
        value: props['value']?.toString() ?? '0',
        unit: props['unit'] as String? ?? '',
        icon: _parseIcon(props['icon'], Icons.auto_stories_rounded),
        backgroundColor: _parseColor(
          props['backgroundColor'],
          const Color(0xFFCBC0EB),
        ),
        illustrationBackgroundColor: _parseColor(
          props['illustrationBackgroundColor'],
          const Color(0xFFF7EBC4),
        ),
        iconColor: _parseColor(props['iconColor'], const Color(0xFF5B34AD)),
      ),
      showAction: props['showAction'] as bool? ?? true,
      actionIcon: _parseIcon(props['actionIcon'], Icons.north_east_rounded),
      actionCutoutColor: props['actionCutoutColor'] == null
          ? null
          : _parseColor(props['actionCutoutColor'], Colors.white),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<IllustratedMetricCardWidget> createState() =>
      _IllustratedMetricCardWidgetState();
}

class _IllustratedMetricCardWidgetState
    extends State<IllustratedMetricCardWidget>
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
    if (widget.size is Wide2Size) return 240 * scale;
    if (widget.size is Large3Size) return 300 * scale;
    return 170 * scale;
  }

  double get _illustrationSize {
    final scale = widget.size.scale;
    if (widget.size is Wide2Size) return 176 * scale;
    if (widget.size is Large3Size) return 200 * scale;
    return 128 * scale;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = widget.size.scale;
    final illustrationSize = _illustrationSize;

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
          color: widget.data.backgroundColor,
          borderRadius: BorderRadius.circular(30 * scale),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.28 : 0.06),
              blurRadius: 20 * scale,
              offset: Offset(0, 5 * scale),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(14 * scale),
              child: Row(
                children: [
                  Container(
                    width: illustrationSize,
                    height: illustrationSize,
                    decoration: BoxDecoration(
                      color: widget.data.illustrationBackgroundColor,
                      borderRadius: BorderRadius.circular(24 * scale),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24 * scale),
                      child: Stack(
                        children: [
                          Positioned(
                            top: -illustrationSize * 0.18,
                            right: -illustrationSize * 0.12,
                            child: Container(
                              width: illustrationSize * 0.68,
                              height: illustrationSize * 0.68,
                              decoration: BoxDecoration(
                                color: widget.data.iconColor.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -illustrationSize * 0.24,
                            left: -illustrationSize * 0.16,
                            child: Container(
                              width: illustrationSize * 0.72,
                              height: illustrationSize * 0.72,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Center(
                            child: Icon(
                              widget.data.icon,
                              size: illustrationSize * 0.52,
                              color: widget.data.iconColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 16 * scale),
                  Expanded(
                    child: SizedBox(
                      height: illustrationSize,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.data.title,
                            style: TextStyle(
                              color: const Color(0xFF141414),
                              fontSize: widget.size.getTitleFontSize(),
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Text(
                            widget.data.value,
                            style: TextStyle(
                              color: const Color(0xFF111111),
                              fontSize: widget.size.getLargeFontSize() * 0.9,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.data.unit.isNotEmpty) ...[
                            SizedBox(height: 5 * scale),
                            Text(
                              widget.data.unit,
                              style: TextStyle(
                                color: const Color(
                                  0xFF141414,
                                ).withOpacity(0.62),
                                fontSize: widget.size.getSubtitleFontSize(),
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
                ],
              ),
            ),
            if (widget.showAction) ...[
              Positioned(
                bottom: 0,
                right: 0,
                child: SizedBox(
                  width: 84 * scale,
                  height: 84 * scale,
                  child: CustomPaint(
                    painter: _ActivityCutoutPainter(
                      color:
                          widget.actionCutoutColor ??
                          (isDark ? Colors.black : Colors.white),
                      scale: scale,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 4 * scale,
                right: 4 * scale,
                child: Material(
                  key: const Key('illustrated-metric-action'),
                  color: const Color(0xFF0F0C14),
                  shape: CircleBorder(
                    side: BorderSide(
                      color: widget.data.backgroundColor,
                      width: 3 * scale,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onAction,
                    child: SizedBox(
                      width: 50 * scale,
                      height: 50 * scale,
                      child: Icon(
                        widget.actionIcon,
                        color: Colors.white,
                        size: 18 * scale,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityCutoutPainter extends CustomPainter {
  final Color color;
  final double scale;

  const _ActivityCutoutPainter({required this.color, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final side = 64 * scale;
    final curve = 20 * scale;
    final mainRect = Rect.fromLTWH(curve, curve, side, side);
    canvas.drawRRect(
      RRect.fromRectAndCorners(mainRect, topLeft: Radius.circular(34 * scale)),
      paint,
    );

    for (final rect in [
      Rect.fromLTWH(mainRect.right - curve, mainRect.top - curve, curve, curve),
      Rect.fromLTWH(
        mainRect.left - curve,
        mainRect.bottom - curve,
        curve,
        curve,
      ),
    ]) {
      canvas.save();
      canvas.clipRect(rect);
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect)
        ..addOval(Rect.fromCircle(center: rect.topLeft, radius: curve));
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityCutoutPainter oldDelegate) {
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
