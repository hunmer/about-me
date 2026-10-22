/// 切角统计网格卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 左上液体切角装饰与圆形图标徽章保留（数据色实底 + 墨线描边）。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
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

class _CutoutStatGridCardWidgetState extends State<CutoutStatGridCardWidget> {
  double get _height {
    final scale = widget.size.scale;
    if (widget.size is Large3Size) return 340 * scale;
    return 240 * scale;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;
    // 切角装饰颜色 = 实际卡底色（props 数据色可空 → 纸底）
    final backgroundColor = widget.backgroundColor ?? theme.surface;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 384 * scale,
        height: widget.inline ? double.maxFinite : _height,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        fillColor: widget.backgroundColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title.isNotEmpty) ...[
              Text(
                widget.title,
                style: TextStyle(
                  color: theme.text,
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
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CutoutStatItem extends StatelessWidget {
  final CutoutStatItemData data;
  final Color cutoutColor;
  final HomeWidgetSize size;

  const _CutoutStatItem({
    required this.data,
    required this.cutoutColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = size.scale;
    // 数据色实底 + 墨线描边（小控件档）
    return Container(
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(26 * scale),
        fillColor: data.backgroundColor,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26 * scale),
        child: Stack(
          children: [
            // 液体切角装饰（内容层，保留）
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
                decoration: dsSketchDecoration(
                  theme: theme,
                  circle: true,
                  fillColor: data.iconBackgroundColor,
                ),
                child: Center(
                  child: WiredIcon(
                    icon: data.icon,
                    size: 23 * scale,
                    color: data.iconColor,
                    drawConfig: theme.wired.drawConfig,
                  ),
                ),
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
                        color: theme.text,
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
                              color: theme.text,
                              fontSize: size.getTitleFontSize() * 1.15,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          if (data.unit.isNotEmpty)
                            TextSpan(
                              text: ' ${data.unit}',
                              style: TextStyle(
                                color: theme.textSub,
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
      canvas.save();
      canvas.clipRect(rect);
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect)
        ..addOval(Rect.fromCircle(center: rect.bottomRight, radius: curve));
      canvas.drawPath(path, paint);
      canvas.restore();
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
