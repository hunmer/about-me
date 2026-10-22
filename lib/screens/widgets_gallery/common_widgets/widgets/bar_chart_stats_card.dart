/// 柱状图统计小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘圆形图标徽章 + 标题头部 / 平均值 / 淡墨横网格 + 斜纹柱状图
/// （数据色浅底 + 数据色浓斜纹 + 数据色描边）/ Y 轴刻度与 X 轴标签。
/// 柱高生长与逐项错峰入场动画保留。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 柱状图统计小组件
class BarChartStatsCardWidget extends StatefulWidget {
  /// 标题
  final String title;

  /// 日期范围
  final String dateRange;

  /// 平均值
  final double averageValue;

  /// 单位
  final String unit;

  /// 图标
  final IconData icon;

  /// 图标颜色（数据色，斜纹柱同色系）
  final Color iconColor;

  /// 数据点列表
  final List<double> data;

  /// X轴标签列表
  final List<String> labels;

  /// Y轴最大值
  final double maxValue;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const BarChartStatsCardWidget({
    super.key,
    required this.title,
    required this.dateRange,
    required this.averageValue,
    required this.unit,
    required this.icon,
    required this.iconColor,
    required this.data,
    required this.labels,
    required this.maxValue,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory BarChartStatsCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    // 解析颜色
    Color parseColor(dynamic colorValue) {
      if (colorValue == null) return Colors.blue;
      if (colorValue is Color) return colorValue;
      if (colorValue is int) return Color(colorValue);
      if (colorValue is String) {
        try {
          // 支持十六进制颜色格式
          if (colorValue.startsWith('#')) {
            return Color(
              int.parse(colorValue.substring(1), radix: 16) + 0xFF000000,
            );
          }
          // 支持 0xFF 格式
          if (colorValue.startsWith('0x')) {
            return Color(int.parse(colorValue.substring(2), radix: 16));
          }
        } catch (e) {
          // 解析失败，返回默认颜色
        }
      }
      return Colors.blue;
    }

    return BarChartStatsCardWidget(
      title: props['title'] as String? ?? 'Stats',
      dateRange: props['dateRange'] as String? ?? '',
      averageValue: (props['averageValue'] as num?)?.toDouble() ?? 0.0,
      unit: props['unit'] as String? ?? '',
      icon: _parseIcon(props['icon'] as String?),
      iconColor: parseColor(props['iconColor']),
      data:
          (props['data'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      labels:
          (props['labels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      maxValue: (props['maxValue'] as num?)?.toDouble() ?? 10.0,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  /// 解析图标字符串为 IconData
  static IconData _parseIcon(String? iconString) {
    if (iconString == null || iconString.isEmpty) {
      return Icons.bar_chart;
    }

    // 常用图标映射
    const iconMap = {
      'bar_chart': Icons.bar_chart,
      'directions_run': Icons.directions_run,
      'favorite': Icons.favorite,
      'fitness_center': Icons.fitness_center,
      'local_fire_department': Icons.local_fire_department,
      'water_drop': Icons.water_drop,
      'restaurant': Icons.restaurant,
      'work': Icons.work,
      'school': Icons.school,
      'shopping_cart': Icons.shopping_cart,
      'flight': Icons.flight,
      'bedtime': Icons.bedtime,
      'alarm': Icons.alarm,
      'timer': Icons.timer,
      'schedule': Icons.schedule,
      'event': Icons.event,
    };

    return iconMap[iconString] ?? Icons.bar_chart;
  }

  @override
  State<BarChartStatsCardWidget> createState() => _BarChartStatsCardWidgetState();
}

class _BarChartStatsCardWidgetState extends State<BarChartStatsCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  static const double _baseEnd = 0.6;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    final elementCount = widget.data.length + 2;
    final maxStep = (1.0 - _baseEnd) / (elementCount - 1);
    final step = maxStep * 0.9;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 320 * scale,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(theme, 0, step),
              SizedBox(height: widget.size.getTitleSpacing()),
              _buildAverageSection(theme, 1, step),
              SizedBox(height: widget.size.getTitleSpacing()),
              _buildChart(theme, step),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeData theme, int index, double step) {
    final itemAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        index * step,
        _baseEnd + index * step,
        curve: Curves.easeOutCubic,
      ),
    );

    final badgeSize =
        widget.size.getIconSize() * widget.size.iconContainerScale;

    return Opacity(
      opacity: itemAnimation.value,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - itemAnimation.value)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: widget.size.getTitleFontSize() * 0.8,
                        fontWeight: FontWeight.w700,
                        color: theme.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(height: widget.size.getItemSpacing()),
                  Flexible(
                    child: Text(
                      widget.dateRange,
                      style: TextStyle(
                        fontSize: widget.size.getSubtitleFontSize(),
                        fontWeight: FontWeight.w500,
                        color: theme.textSub,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.size is! SmallSize)
              Container(
                width: badgeSize,
                height: badgeSize,
                // 大圆角被 rough 引擎自动钳制成圆
                decoration: dsSketchDecoration(
                  theme: theme,
                  radius: BorderRadius.circular(badgeSize / 2),
                  fillColor: theme.surfaceAlt,
                ),
                child: Center(
                  child: WiredIcon(
                    icon: widget.icon,
                    size: widget.size.getIconSize(),
                    color: widget.iconColor,
                    drawConfig: theme.wired.drawConfig,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAverageSection(AppThemeData theme, int index, double step) {
    final itemAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        index * step,
        _baseEnd + index * step,
        curve: Curves.easeOutCubic,
      ),
    );

    return Opacity(
      opacity: itemAnimation.value,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - itemAnimation.value)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  widget.averageValue.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: widget.size.getLargeFontSize() * 0.8,
                    fontWeight: FontWeight.w700,
                    color: theme.text,
                    letterSpacing: -2,
                  ),
                ),
                SizedBox(width: widget.size.getItemSpacing()),
                Text(
                  widget.unit,
                  style: TextStyle(
                    fontSize: widget.size.getTitleFontSize() - 4,
                    fontWeight: FontWeight.w700,
                    color: theme.text,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(AppThemeData theme, double step) {
    // 根据尺寸动态计算图表高度
    final chartHeight =
        widget.size is SmallSize
            ? 120.0
            : widget.size is MediumSize
            ? 160.0
            : 192.0;
    // 根据尺寸动态计算 Y 轴宽度
    final yAxisWidth = widget.size.getLegendFontSize() * 2.5;

    return Column(
      children: [
        SizedBox(
          height: chartHeight,
          child: Row(
            children: [
              _buildYAxis(theme, step, yAxisWidth),
              SizedBox(width: widget.size.getItemSpacing()),
              Expanded(child: _buildBars(theme, step, chartHeight)),
            ],
          ),
        ),
        SizedBox(height: widget.size.getItemSpacing()),
        _buildXLabels(theme, step),
      ],
    );
  }

  Widget _buildYAxis(
    AppThemeData theme,
    double step,
    double yAxisWidth,
  ) {
    return SizedBox(
      width: yAxisWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (index) {
          final value = (widget.maxValue / 5) * (5 - index);
          final itemAnimation = CurvedAnimation(
            parent: _animationController,
            curve: Interval(2 * step, 1.0, curve: Curves.easeOutCubic),
          );
          return Opacity(
            opacity: itemAnimation.value,
            child: Text(
              value.toInt().toString(),
              style: TextStyle(
                fontSize: widget.size.getLegendFontSize(),
                fontWeight: FontWeight.w500,
                color: theme.textSub,
              ),
              textAlign: TextAlign.right,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBars(AppThemeData theme, double step, double chartHeight) {
    return Stack(
      children: [_buildGridLines(theme), _buildDataBars(step, chartHeight)],
    );
  }

  /// 横网格：淡墨细线，底行 X 轴墨线稍浓（平直几何，保证读数清晰）
  Widget _buildGridLines(AppThemeData theme) {
    return Positioned.fill(
      child: Column(
        children: List.generate(
          6,
          (index) => Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.ink.withValues(
                      alpha: index < 5 ? 0.15 : 0.45,
                    ),
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataBars(double step, double chartHeight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(widget.data.length, (index) {
        final barAnimation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            (2 + index) * step,
            _baseEnd + (2 + index) * step,
            curve: Curves.easeOutCubic,
          ),
        );

        final ratio = (widget.data[index] / widget.maxValue);
        final fullBarHeight = chartHeight * ratio;

        return Expanded(
          child: Container(
            height: chartHeight,
            alignment: Alignment.bottomCenter,
            child: AnimatedBuilder(
              animation: barAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(
                    widget.size.getBarWidth(),
                    fullBarHeight * barAnimation.value,
                  ),
                  painter: _StripedBarPainter(
                    color: widget.iconColor,
                    scale: widget.size.scale,
                  ),
                );
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildXLabels(AppThemeData theme, double step) {
    final labelsAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    );

    return Opacity(
      opacity: labelsAnimation.value,
      child: Padding(
        padding: EdgeInsets.only(left: widget.size.getPadding().left + 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            widget.labels.length,
            (index) => Expanded(
              child: Center(
                child: Text(
                  widget.labels[index],
                  style: TextStyle(
                    fontSize: widget.size.getLegendFontSize(),
                    fontWeight: FontWeight.w500,
                    color: theme.textSub,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 斜纹柱绘制器：数据色浅底（0.28）+ 数据色浓斜纹（0.9）+ 数据色描边（0.85）
///
/// 平直胶囊几何（无 rough 抖动），保证读数清晰（§9.5 统计图表规范）。
class _StripedBarPainter extends CustomPainter {
  final Color color;
  final double scale;

  const _StripedBarPainter({required this.color, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = Radius.circular(size.width / 2);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, radius);

    canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.28));
    paintDiagonalStripes(
      canvas,
      Path()..addRRect(rrect),
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
  bool shouldRepaint(covariant _StripedBarPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.scale != scale;
  }
}
