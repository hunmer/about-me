/// 条纹柱状图卡片（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘圆形图标徽章 + 标题头部 / 虚线网格 + 斜纹柱状图
/// （未选中柱淡墨斜纹、选中柱数据色浓斜纹 + 墨底数值气泡）/ 底部刻度。
/// 柱高生长动画与点击选中交互保留。
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

class StripedWeeklyBarData {
  final String label;
  final double value;
  final String valueLabel;

  const StripedWeeklyBarData({
    required this.label,
    required this.value,
    this.valueLabel = '',
  });
}

class StripedWeeklyChartCardWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<StripedWeeklyBarData> items;
  final int initialSelectedIndex;
  final IconData icon;
  final Color activeColor;
  final Color activeBackgroundColor;
  final ValueChanged<int>? onSelected;
  final bool inline;
  final HomeWidgetSize size;

  const StripedWeeklyChartCardWidget({
    super.key,
    this.title = '',
    this.subtitle = '',
    this.items = const [],
    this.initialSelectedIndex = 0,
    this.icon = Icons.pie_chart_rounded,
    this.activeColor = const Color(0xFFD972F8),
    this.activeBackgroundColor = const Color(0xFFF3C4FF),
    this.onSelected,
    this.inline = false,
    this.size = const Large3Size(),
  });

  factory StripedWeeklyChartCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final rawItems = props['items'];
    final items = rawItems is List
        ? rawItems.map((item) {
            if (item is StripedWeeklyBarData) return item;
            final map = item is Map ? item : const <String, dynamic>{};
            return StripedWeeklyBarData(
              label: map['label'] as String? ?? '',
              value: (map['value'] as num?)?.toDouble() ?? 0,
              valueLabel: map['valueLabel'] as String? ?? '',
            );
          }).toList()
        : <StripedWeeklyBarData>[];

    return StripedWeeklyChartCardWidget(
      title: props['title'] as String? ?? '',
      subtitle: props['subtitle'] as String? ?? '',
      items: items,
      initialSelectedIndex:
          (props['initialSelectedIndex'] as num?)?.toInt() ?? 0,
      icon: _parseIcon(props['icon'], Icons.pie_chart_rounded),
      activeColor: _parseColor(props['activeColor'], const Color(0xFFD972F8)),
      activeBackgroundColor: _parseColor(
        props['activeBackgroundColor'],
        const Color(0xFFF3C4FF),
      ),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<StripedWeeklyChartCardWidget> createState() =>
      _StripedWeeklyChartCardWidgetState();
}

class _StripedWeeklyChartCardWidgetState
    extends State<StripedWeeklyChartCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _validSelectedIndex();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant StripedWeeklyChartCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSelectedIndex != widget.initialSelectedIndex ||
        oldWidget.items.length != widget.items.length) {
      _selectedIndex = _validSelectedIndex();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _validSelectedIndex() {
    if (widget.items.isEmpty) return -1;
    return widget.initialSelectedIndex
        .clamp(0, widget.items.length - 1)
        .toInt();
  }

  double get _height {
    final scale = widget.size.scale;
    if (widget.size is Wide2Size) return 330 * scale;
    return 430 * scale;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 384 * scale,
        height: widget.inline ? double.maxFinite : _height,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          children: [
            _buildHeader(theme),
            SizedBox(height: 14 * scale),
            Expanded(child: _buildChart(theme, _animation.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeData theme) {
    final scale = widget.size.scale;
    return Row(
      children: [
        Container(
          width: 44 * scale,
          height: 44 * scale,
          // 大圆角被 rough 引擎自动钳制成圆
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(44 * scale / 2),
            fillColor: theme.surfaceAlt,
          ),
          child: Center(
            child: WiredIcon(
              icon: widget.icon,
              size: 24 * scale,
              color: widget.activeColor,
              drawConfig: theme.wired.drawConfig,
            ),
          ),
        ),
        SizedBox(width: 12 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  color: theme.text,
                  fontSize: widget.size.getSubtitleFontSize() + 2 * scale,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.subtitle.isNotEmpty) ...[
                SizedBox(height: 3 * scale),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    color: theme.textSub,
                    fontSize: widget.size.getLegendFontSize(),
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
      ],
    );
  }

  Widget _buildChart(AppThemeData theme, double progress) {
    final maxValue = widget.items.fold<double>(
      0,
      (maximum, item) => math.max(maximum, item.value),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 220 * widget.size.scale;
        final topInset = 34 * widget.size.scale;
        final bottomInset = 30 * widget.size.scale;
        final maxBarHeight = math.max(
          0.0,
          chartHeight - topInset - bottomInset,
        );

        return SizedBox(
          height: chartHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _DashedGridPainter(
                    color: theme.ink.withValues(alpha: 0.18),
                    topInset: topInset,
                    bottomInset: bottomInset,
                    scale: widget.size.scale,
                  ),
                ),
              ),
              Row(
                children: [
                  for (var index = 0; index < widget.items.length; index++)
                    Expanded(
                      child: _buildBarColumn(
                        index: index,
                        maxValue: maxValue,
                        maxBarHeight: maxBarHeight,
                        topInset: topInset,
                        progress: progress,
                        theme: theme,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBarColumn({
    required int index,
    required double maxValue,
    required double maxBarHeight,
    required double topInset,
    required double progress,
    required AppThemeData theme,
  }) {
    final item = widget.items[index];
    final selected = index == _selectedIndex;
    final scale = widget.size.scale;
    final ratio = maxValue > 0 ? (item.value / maxValue).clamp(0.0, 1.0) : 0.0;
    final barHeight = maxBarHeight * ratio * progress;
    final valueLabel = item.valueLabel.isEmpty
        ? item.value.toStringAsFixed(1)
        : item.valueLabel;

    return GestureDetector(
      key: ValueKey('striped-weekly-bar-$index'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _selectedIndex = index);
        widget.onSelected?.call(index);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 3 * scale),
        child: Column(
          children: [
            SizedBox(
              height: topInset + maxBarHeight,
              child: Stack(
                children: [
                  Positioned(
                    left: 2 * scale,
                    right: 2 * scale,
                    bottom: 0,
                    height: barHeight,
                    child: CustomPaint(
                      painter: _StripedBarPainter(
                        selected: selected,
                        activeColor: widget.activeColor,
                        activeBackgroundColor: widget.activeBackgroundColor,
                        theme: theme,
                        scale: scale,
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: barHeight + 4 * scale,
                      child: Center(child: _BarTooltip(text: valueLabel, theme: theme)),
                    ),
                ],
              ),
            ),
            SizedBox(height: 8 * scale),
            SizedBox(
              height: 22 * scale,
              child: Text(
                item.label,
                style: TextStyle(
                  color: selected ? theme.text : theme.textSub,
                  fontSize: widget.size.getLegendFontSize(),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 选中柱数值气泡：墨底实底 + 纸色文字（§9.5 指针/墨块同语言）
class _BarTooltip extends StatelessWidget {
  final String text;
  final AppThemeData theme;

  const _BarTooltip({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(20),
            fillColor: theme.ink,
          ),
          child: Text(
            text,
            style: TextStyle(
              color: theme.surface,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
            maxLines: 1,
          ),
        ),
        CustomPaint(
          size: const Size(10, 5),
          painter: _TooltipArrowPainter(color: theme.ink),
        ),
      ],
    );
  }
}

class _TooltipArrowPainter extends CustomPainter {
  final Color color;

  const _TooltipArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TooltipArrowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// 斜纹柱绘制器：未选中柱淡墨斜纹（surfaceAlt 底），选中柱数据色浓斜纹
class _StripedBarPainter extends CustomPainter {
  final bool selected;
  final Color activeColor;
  final Color activeBackgroundColor;
  final AppThemeData theme;
  final double scale;

  const _StripedBarPainter({
    required this.selected,
    required this.activeColor,
    required this.activeBackgroundColor,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = Radius.circular(size.width / 2);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, radius);
    final background = selected ? activeBackgroundColor : theme.surfaceAlt;
    final stripe = selected
        ? activeColor.withValues(alpha: 0.9)
        : theme.ink.withValues(alpha: 0.28);
    final border = selected
        ? activeColor.withValues(alpha: 0.85)
        : theme.ink.withValues(alpha: 0.45);

    canvas.drawRRect(rrect, Paint()..color = background);
    paintDiagonalStripes(
      canvas,
      Path()..addRRect(rrect),
      rect,
      color: stripe,
      strokeWidth: (selected ? 3 : 1.5) * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _StripedBarPainter oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.activeBackgroundColor != activeBackgroundColor ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}

class _DashedGridPainter extends CustomPainter {
  final Color color;
  final double topInset;
  final double bottomInset;
  final double scale;

  const _DashedGridPainter({
    required this.color,
    required this.topInset,
    required this.bottomInset,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final availableHeight = math.max(0.0, size.height - topInset - bottomInset);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2 * scale;
    const dashCount = 4;
    for (var row = 0; row < dashCount; row++) {
      final y = topInset + availableHeight * row / (dashCount - 1);
      for (var x = 0.0; x < size.width; x += 10 * scale) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 5 * scale, size.width), y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.topInset != topInset ||
        oldDelegate.bottomInset != bottomInset ||
        oldDelegate.scale != scale;
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
