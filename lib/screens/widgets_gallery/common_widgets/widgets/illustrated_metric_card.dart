/// 插画指标卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（数据色纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 左侧插画区（数据色实底墨线框 + 手绘大图标 + 出血圆装饰）/
/// 右侧标题与数值 / 右下角切角动作圆钮（墨底 + 数据色描边）。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
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
    extends State<IllustratedMetricCardWidget> {
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
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;
    final illustrationSize = _illustrationSize;

    // 手绘纸卡：数据色纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: SizedBox(
        width: widget.inline ? double.maxFinite : 384 * scale,
        height: widget.inline ? double.maxFinite : _height,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipPath(
                clipper: _ActivityCardClipper(
                  scale: scale,
                  showAction: widget.showAction,
                ),
                child: DsSketchPanel(
                  theme: theme,
                  radius: BorderRadius.circular(24 * scale),
                  fillColor: widget.data.backgroundColor,
                  padding: EdgeInsets.all(14 * scale),
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(14 * scale),
                        child: Row(
                          children: [
                            // 插画区：数据色实底 + 墨线描边 + 出血圆装饰
                            Container(
                              width: illustrationSize,
                              height: illustrationSize,
                              clipBehavior: Clip.antiAlias,
                              decoration: dsSketchDecoration(
                                theme: theme,
                                radius: BorderRadius.circular(24 * scale),
                                fillColor:
                                    widget.data.illustrationBackgroundColor,
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: -illustrationSize * 0.18,
                                    right: -illustrationSize * 0.12,
                                    child: Container(
                                      width: illustrationSize * 0.68,
                                      height: illustrationSize * 0.68,
                                      decoration: BoxDecoration(
                                        color: widget.data.iconColor
                                            .withOpacity(0.08),
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
                                        color: theme.surface.withValues(
                                          alpha: 0.2,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: WiredIcon(
                                      icon: widget.data.icon,
                                      size: illustrationSize * 0.52,
                                      color: widget.data.iconColor,
                                      drawConfig: theme.wired.drawConfig,
                                    ),
                                  ),
                                ],
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
                                        color: theme.text,
                                        fontSize: widget.size
                                            .getTitleFontSize(),
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
                                        color: theme.text,
                                        fontSize:
                                            widget.size.getLargeFontSize() *
                                            0.9,
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
                                          color: theme.textSub,
                                          fontSize: widget.size
                                              .getSubtitleFontSize(),
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
                    ],
                  ),
                ),
              ),
            ),
            if (widget.showAction) ...[
              Positioned(
                bottom: 0,
                right: 0,
                child: IgnorePointer(
                  child: SizedBox(
                    width: 98 * scale,
                    height: 98 * scale,
                    child: CustomPaint(
                      painter: _ActivityCutoutPainter(
                        stroke: theme.ink,
                        scale: scale,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 18 * scale,
                right: 18 * scale,
                child: GestureDetector(
                  key: const Key('illustrated-metric-action'),
                  onTap: widget.onAction,
                  // 动作圆钮：墨底实底 + 数据色描边
                  child: Container(
                    width: 50 * scale,
                    height: 50 * scale,
                    // 大圆角被 rough 引擎自动钳制成圆
                    decoration: dsSketchDecoration(
                      theme: theme,
                      radius: BorderRadius.circular(25 * scale),
                      fillColor: theme.ink,
                      stroke: widget.data.backgroundColor,
                      strokeWidth: 3 * scale,
                    ),
                    child: Center(
                      child: WiredIcon(
                        icon: widget.actionIcon,
                        size: 18 * scale,
                        color: theme.surface,
                        drawConfig: theme.wired.drawConfig,
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

Path _activityCutoutEdge(Size size, double scale) {
  final curve = 20 * scale;
  final innerRadius = 34 * scale;
  return Path()
    ..moveTo(size.width, 0)
    ..quadraticBezierTo(size.width, curve, size.width - curve, curve)
    ..lineTo(curve + innerRadius, curve)
    ..arcToPoint(
      Offset(curve, curve + innerRadius),
      radius: Radius.circular(innerRadius),
      clockwise: false,
    )
    ..lineTo(curve, size.height - curve)
    ..quadraticBezierTo(curve, size.height, 0, size.height);
}

class _ActivityCardClipper extends CustomClipper<Path> {
  final double scale;
  final bool showAction;

  const _ActivityCardClipper({required this.scale, required this.showAction});

  @override
  Path getClip(Size size) {
    final panel = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(24 * scale),
        ),
      );
    if (!showAction) return panel;
    final side = 98 * scale;
    final cutout = _activityCutoutEdge(Size.square(side), scale)
      ..lineTo(side, side)
      ..close();
    return Path.combine(
      PathOperation.difference,
      panel,
      cutout.shift(Offset(size.width - side, size.height - side)),
    );
  }

  @override
  bool shouldReclip(covariant _ActivityCardClipper oldClipper) =>
      oldClipper.scale != scale || oldClipper.showAction != showAction;
}

class _ActivityCutoutPainter extends CustomPainter {
  final Color stroke;
  final double scale;

  const _ActivityCutoutPainter({required this.stroke, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _activityCutoutEdge(size, scale),
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ActivityCutoutPainter oldDelegate) =>
      oldDelegate.stroke != stroke || oldDelegate.scale != scale;
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
