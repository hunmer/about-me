/// 闪光统计网格卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 闪光水印与斜放书页水印保留（内容层装饰），数据色实底 + 墨线描边。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
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

class SparkleStatGridCardWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = size.scale;
    final height = (size is Large3Size ? 300.0 : 220.0) * scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: inline ? double.maxFinite : 384 * scale,
        height: inline ? double.maxFinite : height,
        radius: BorderRadius.circular(24 * scale),
        padding: size.getPadding(),
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) SizedBox(width: 12 * scale),
              Expanded(child: _SparkleStatItem(data: items[index])),
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
    final theme = AppTheme.of(context);
    return Container(
      // 数据色实底 + 墨线描边（小控件档）
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(30),
        fillColor: data.backgroundColor,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            // 闪光水印（核心装饰，保留）
            Positioned.fill(
              child: CustomPaint(
                painter: _SparklePainter(
                  color: theme.surface.withValues(alpha: 0.32),
                ),
              ),
            ),
            // 斜放书页水印（核心装饰，保留）
            Positioned(
              right: -14,
              bottom: -16,
              child: Transform.rotate(
                angle: -0.24,
                child: WiredIcon(
                  icon: Icons.auto_stories_outlined,
                  size: 88,
                  color: theme.surface.withValues(alpha: 0.25),
                  drawConfig: theme.wired.drawConfig,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: dsSketchDecoration(
                          theme: theme,
                          circle: true,
                          fillColor: data.iconBackgroundColor,
                        ),
                        child: Center(
                          child: WiredIcon(
                            icon: data.icon,
                            size: 22,
                            color: theme.text,
                            drawConfig: theme.wired.drawConfig,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          data.label,
                          style: TextStyle(
                            color: theme.text,
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
                      style: TextStyle(
                        color: theme.text,
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
