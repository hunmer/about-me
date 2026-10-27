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

  /// 图标（省略时不渲染左上角圆形图标徽章）
  final IconData? icon;
  final Color backgroundColor;
  final Color iconBackgroundColor;
  final Color iconColor;

  const CutoutStatItemData({
    required this.label,
    required this.value,
    this.unit = '',
    this.icon,
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

  /// 统计项排列方向：horizontal 横排（默认，宽卡）/ vertical 竖排（窄卡）
  final Axis direction;

  /// 是否套外层纸卡面板（纸底 + 墨线框 + 标题）。
  /// 无框模式直接排布统计项（各自带切角装饰），适合嵌入已有卡片容器
  final bool framed;

  /// 点击统计项回调（参数为条目索引）
  final void Function(int index)? onItemTap;
  final HomeWidgetSize size;

  const CutoutStatGridCardWidget({
    super.key,
    this.title = '',
    this.items = const [],
    this.backgroundColor,
    this.inline = false,
    this.direction = Axis.horizontal,
    this.framed = true,
    this.onItemTap,
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
              icon: map['icon'] == null
                  ? null
                  : _parseIcon(map['icon'], Icons.school_rounded),
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
      direction: props['direction'] == 'vertical'
          ? Axis.vertical
          : Axis.horizontal,
      framed: props['framed'] as bool? ?? true,
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

    // 统计项布局（横排/竖排，撑满可用空间）
    Widget buildItems() {
      return widget.direction == Axis.vertical
          ? Column(
              children: [
                for (var index = 0; index < widget.items.length; index++) ...[
                  if (index > 0) SizedBox(height: 9 * scale),
                  Expanded(child: _buildItem(index, vertical: true)),
                ],
              ],
            )
          : Row(
              children: [
                for (var index = 0; index < widget.items.length; index++) ...[
                  if (index > 0) SizedBox(width: 9 * scale),
                  Expanded(child: _buildItem(index, vertical: false)),
                ],
              ],
            );
    }

    // 无框模式：不套纸卡面板与标题，直接排布统计项（嵌入已有卡片容器用）
    if (!widget.framed) {
      return SizedBox.expand(child: buildItems());
    }

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
            Expanded(child: buildItems()),
          ],
        ),
      ),
    );
  }

  /// 单个统计项（可点击）
  Widget _buildItem(int index, {required bool vertical}) {
    final item = _CutoutStatItem(
      data: widget.items[index],
      size: widget.size,
      vertical: vertical,
    );
    final onTap = widget.onItemTap;
    if (onTap == null) return item;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: item,
    );
  }
}

class _CutoutStatItem extends StatelessWidget {
  final CutoutStatItemData data;
  final HomeWidgetSize size;

  /// 竖排布局：图标徽章与文字左右并排（窄卡场景）
  final bool vertical;

  const _CutoutStatItem({
    required this.data,
    required this.size,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = size.scale;
    final hasIcon = data.icon != null;

    // 文字区：竖排时与徽章并排，横排时避开左上角徽章
    final contentPadding = vertical
        ? EdgeInsets.all(11 * scale)
        : EdgeInsets.fromLTRB(
            12 * scale,
            hasIcon ? 62 * scale : 14 * scale,
            12 * scale,
            13 * scale,
          );

    Widget buildValue() {
      return Text.rich(
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
      );
    }

    // 数据色实底 + 墨线描边（小控件档）
    return Stack(
      children: [
        Positioned.fill(
          child: ClipPath(
            clipper: _CutoutCornerClipper(scale: scale),
            child: Container(
              decoration: dsSketchDecoration(
                theme: theme,
                radius: BorderRadius.circular(26 * scale),
                fillColor: data.backgroundColor,
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          child: IgnorePointer(
            child: SizedBox(
              width: 66 * scale,
              height: 66 * scale,
              child: CustomPaint(
                painter: _CutoutCornerPainter(stroke: theme.ink, scale: scale),
              ),
            ),
          ),
        ),
        if (hasIcon)
          Positioned(
            top: 2 * scale,
            left: 2 * scale,
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
                  icon: data.icon!,
                  size: 23 * scale,
                  color: data.iconColor,
                  drawConfig: theme.wired.drawConfig,
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: Padding(
            padding: contentPadding,
            child: vertical
                ? Row(
                    children: [
                      if (hasIcon) SizedBox(width: 47 * scale + 6 * scale),
                      Expanded(
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            buildValue(),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
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
                      buildValue(),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

Path _cutoutCornerEdge(double scale) {
  final side = 50 * scale;
  final curve = 16 * scale;
  final radius = 26 * scale;
  return Path()
    ..moveTo(side + curve, 0)
    ..quadraticBezierTo(side, 0, side, curve)
    ..lineTo(side, side - radius)
    ..arcToPoint(Offset(side - radius, side), radius: Radius.circular(radius))
    ..lineTo(curve, side)
    ..quadraticBezierTo(0, side, 0, side + curve);
}

class _CutoutCornerClipper extends CustomClipper<Path> {
  final double scale;

  const _CutoutCornerClipper({required this.scale});

  @override
  Path getClip(Size size) {
    final panel = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(26 * scale),
        ),
      );
    final cutout = _cutoutCornerEdge(scale)
      ..lineTo(0, 0)
      ..close();
    return Path.combine(PathOperation.difference, panel, cutout);
  }

  @override
  bool shouldReclip(covariant _CutoutCornerClipper oldClipper) =>
      oldClipper.scale != scale;
}

class _CutoutCornerPainter extends CustomPainter {
  final Color stroke;
  final double scale;

  const _CutoutCornerPainter({required this.stroke, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _cutoutCornerEdge(scale),
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CutoutCornerPainter oldDelegate) =>
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
