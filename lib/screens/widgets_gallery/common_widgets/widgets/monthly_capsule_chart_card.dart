/// 月度胶囊图小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘圆形图标徽章 + 标题 / 内层淡底面板 / 斜纹胶囊柱阵（轨道淡墨斜纹、
/// 进度段数据色浅底 + 浓斜纹 + 描边，生长动画保留）/ 墨底徽章。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

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
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;
    final height = (widget.size is Wide2Size ? 350.0 : 430.0) * scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 384 * scale,
        height: widget.inline ? double.maxFinite : height,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52 * scale,
                  height: 52 * scale,
                  // 大圆角被 rough 引擎自动钳制成圆
                  decoration: dsSketchDecoration(
                    theme: theme,
                    radius: BorderRadius.circular(52 * scale / 2),
                    fillColor: theme.surfaceAlt,
                  ),
                  child: Center(
                    child: WiredIcon(
                      icon: Icons.pie_chart_outline_rounded,
                      size: 24 * scale,
                      color: theme.text,
                      drawConfig: theme.wired.drawConfig,
                    ),
                  ),
                ),
                SizedBox(width: 14 * scale),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: theme.text,
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
            // 胶囊生长动画：仅重建数据区驱动填充高度（非整卡淡入）
            Expanded(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) => DsSketchPanel(
                  theme: theme,
                  width: double.infinity,
                  // 纯淡底 + 墨线框（不叠排线，衬托胶囊数据区）
                  fillColor: theme.surfaceAlt,
                  hachure: false,
                  radius: BorderRadius.circular(24 * scale),
                  padding: EdgeInsets.all(16 * scale),
                  child: Row(
                    children: [
                      for (var index = 0;
                          index < widget.items.length;
                          index++) ...[
                        if (index > 0) SizedBox(width: 12 * scale),
                        Expanded(
                          child: _MonthlyCapsuleColumn(
                            data: widget.items[index],
                            progress: _animation.value,
                            scale: scale,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyCapsuleColumn extends StatelessWidget {
  final MonthlyCapsuleData data;
  final double progress;
  final double scale;

  const _MonthlyCapsuleColumn({
    required this.data,
    required this.progress,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
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
                  // 胶囊轨道：淡底 + 淡墨斜纹 + 淡墨描边
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CapsuleTrackPainter(theme: theme, scale: scale),
                    ),
                  ),
                  // 进度段：数据色浅底 + 浓斜纹 + 数据色描边
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: fillHeight,
                    child: CustomPaint(
                      painter: _CapsuleFillPainter(
                        color: data.color,
                        scale: scale,
                      ),
                      child:
                          fillHeight < 44
                              ? null
                              : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    data.value,
                                    style: TextStyle(
                                      color: theme.text,
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
                                      style: TextStyle(
                                        color: theme.textSub,
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
                          decoration: dsSketchDecoration(
                            theme: theme,
                            // 大圆角被 rough 引擎自动钳制成胶囊
                            radius: BorderRadius.circular(20),
                            fillColor: theme.ink,
                          ),
                          child: Text(
                            data.badge,
                            style: TextStyle(
                              color: theme.surface,
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
            color: theme.text,
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

/// 胶囊轨道：surfaceAlt 底 + 淡墨斜纹（ink 0.28）+ 淡墨描边（ink 0.45）
class _CapsuleTrackPainter extends CustomPainter {
  final AppThemeData theme;
  final double scale;

  const _CapsuleTrackPainter({required this.theme, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.width / 2),
    );
    final path = Path()..addRRect(rrect);
    canvas.drawRRect(rrect, Paint()..color = theme.surfaceAlt);
    paintDiagonalStripes(
      canvas,
      path,
      rect,
      color: theme.ink.withValues(alpha: 0.28),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = theme.ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _CapsuleTrackPainter oldDelegate) =>
      oldDelegate.theme != theme || oldDelegate.scale != scale;
}

/// 胶囊进度段：数据色浅底（0.28）+ 数据色浓斜纹（0.9）+ 数据色描边（0.85）
class _CapsuleFillPainter extends CustomPainter {
  final Color color;
  final double scale;

  const _CapsuleFillPainter({required this.color, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.width / 2);
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: radius,
      topRight: radius,
      bottomLeft: radius,
      bottomRight: radius,
    );
    final path = Path()..addRRect(rrect);
    canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.28));
    paintDiagonalStripes(
      canvas,
      path,
      rect,
      color: color.withValues(alpha: 0.9),
      strokeWidth: 3 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _CapsuleFillPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.scale != scale;
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
