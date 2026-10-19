import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

class GradientProgressCardWidget extends StatefulWidget {
  final String title;
  final String label;
  final double progress;
  final IconData icon;
  final List<Color> gradientColors;
  final Color accentColor;
  final ValueChanged<double>? onChanged;
  final bool inline;
  final HomeWidgetSize size;

  const GradientProgressCardWidget({
    super.key,
    this.title = '',
    this.label = '',
    this.progress = 0,
    this.icon = Icons.analytics_rounded,
    this.gradientColors = const [
      Color(0xFFCBBBE3),
      Color(0xFFF5E5B8),
      Color(0xFFFCE1D9),
      Color(0xFFD88AF8),
    ],
    this.accentColor = const Color(0xFFDF92F7),
    this.onChanged,
    this.inline = false,
    this.size = const Large3Size(),
  });

  factory GradientProgressCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final rawColors = props['gradientColors'];
    final colors = rawColors is List
        ? rawColors
              .map((value) => _parseColor(value, Colors.transparent))
              .toList()
        : <Color>[];

    return GradientProgressCardWidget(
      title: props['title'] as String? ?? '',
      label: props['label'] as String? ?? '',
      progress: (props['progress'] as num?)?.toDouble() ?? 0,
      icon: _parseIcon(props['icon'], Icons.analytics_rounded),
      gradientColors: colors.length >= 2
          ? colors
          : const [
              Color(0xFFCBBBE3),
              Color(0xFFF5E5B8),
              Color(0xFFFCE1D9),
              Color(0xFFD88AF8),
            ],
      accentColor: _parseColor(props['accentColor'], const Color(0xFFDF92F7)),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<GradientProgressCardWidget> createState() =>
      _GradientProgressCardWidgetState();
}

class _GradientProgressCardWidgetState extends State<GradientProgressCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late double _progress;

  @override
  void initState() {
    super.initState();
    _progress = widget.progress.clamp(0.0, 1.0).toDouble();
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
  void didUpdateWidget(covariant GradientProgressCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _progress = widget.progress.clamp(0.0, 1.0).toDouble();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _height {
    final scale = widget.size.scale;
    if (widget.size is Wide2Size) return 240 * scale;
    if (widget.size is Large3Size) return 280 * scale;
    return 180 * scale;
  }

  void _updateProgress(double dx, double width, double thumbSize) {
    final travel = math.max(0.0, width - thumbSize);
    if (travel == 0) return;
    final next = ((dx - thumbSize / 2) / travel).clamp(0.0, 1.0).toDouble();
    if (next == _progress) return;
    setState(() => _progress = next);
    widget.onChanged?.call(next);
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
            child: child,
          ),
        );
      },
      child: Container(
        width: widget.inline ? double.maxFinite : 384 * scale,
        height: widget.inline ? double.maxFinite : _height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF9FBFD),
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
              Row(
                children: [
                  Container(
                    width: 44 * scale,
                    height: 44 * scale,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFDCE4EC),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? Colors.white24
                            : const Color(0xFF222222),
                        width: scale,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 24 * scale,
                      color: isDark ? Colors.white : const Color(0xFF2563EB),
                    ),
                  ),
                  SizedBox(width: 12 * scale),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF141414),
                        fontSize: widget.size.getSubtitleFontSize() + 2 * scale,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF7C8088),
                        fontSize: widget.size.getSubtitleFontSize(),
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(_progress * 100).round()}%',
                    key: const Key('gradient-progress-value'),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF111111),
                      fontSize: widget.size is Wide2Size
                          ? 30 * scale
                          : 26 * scale,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8 * scale),
              _buildTrack(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrack(bool isDark) {
    final scale = widget.size.scale;
    final trackHeight = 40 * scale;
    final thumbSize = 32 * scale;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final travel = math.max(0.0, width - thumbSize);
        final thumbLeft = travel * _progress;
        final hatchWidth = (thumbLeft + thumbSize / 2)
            .clamp(0.0, width)
            .toDouble();

        return GestureDetector(
          key: const Key('gradient-progress-track'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              _updateProgress(details.localPosition.dx, width, thumbSize),
          onHorizontalDragDown: (details) =>
              _updateProgress(details.localPosition.dx, width, thumbSize),
          onHorizontalDragUpdate: (details) =>
              _updateProgress(details.localPosition.dx, width, thumbSize),
          child: SizedBox(
            height: trackHeight,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: 20 * scale,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: widget.gradientColors),
                      borderRadius: BorderRadius.circular(20 * scale),
                    ),
                  ),
                ),
                if (hatchWidth > 0)
                  Positioned(
                    left: 0,
                    top: 4 * scale,
                    bottom: 4 * scale,
                    width: hatchWidth,
                    child: CustomPaint(
                      painter: _DiagonalHatchPainter(
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF9CA3AF),
                        scale: scale,
                      ),
                    ),
                  ),
                Positioned(
                  left: thumbLeft,
                  top: (trackHeight - thumbSize) / 2,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.accentColor,
                        width: 4.5 * scale,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withOpacity(0.28),
                          blurRadius: 10 * scale,
                          offset: Offset(0, 3 * scale),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DiagonalHatchPainter extends CustomPainter {
  final Color color;
  final double scale;

  const _DiagonalHatchPainter({required this.color, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas.clipRRect(
      RRect.fromRectAndCorners(
        Offset.zero & size,
        topLeft: radius,
        bottomLeft: radius,
      ),
    );
    final paint = Paint()
      ..color = color.withOpacity(0.72)
      ..strokeWidth = 1.5 * scale
      ..style = PaintingStyle.stroke;
    final spacing = 6.5 * scale;
    for (var x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height * 0.8, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiagonalHatchPainter oldDelegate) {
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
