/// 睡眠时长统计卡片小组件（手绘纸卡风格，深底核心视觉保留）
///
/// 手绘深紫纸卡（深底 + 淡紫排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘圆形图标徽章 / 翻牌时长计数 + 趋势手绘箭头 / 斜纹睡眠周期条
/// （数据色浅底 + 数据色浓斜纹 + 数据色描边，胶囊端）。
/// 周期条滑入与计数动画保留。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 柱状图趋势枚举
enum BarChartTrend { up, down, neutral }

/// 睡眠时长统计卡片小组件
///
/// 显示睡眠时长、趋势和睡眠周期可视化
class DarkBarChartCard extends StatefulWidget {
  /// 睡眠时长（分钟）
  final int durationInMinutes;

  /// 趋势（上升、下降、中性）
  final BarChartTrend trend;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const DarkBarChartCard({
    super.key,
    required this.durationInMinutes,
    this.trend = BarChartTrend.neutral,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory DarkBarChartCard.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    // 将字符串趋势转换为枚举
    BarChartTrend parseTrend(dynamic trendValue) {
      if (trendValue == null) return BarChartTrend.neutral;
      if (trendValue is BarChartTrend) return trendValue;
      if (trendValue is String) {
        switch (trendValue.toLowerCase()) {
          case 'up':
            return BarChartTrend.up;
          case 'down':
            return BarChartTrend.down;
          default:
            return BarChartTrend.neutral;
        }
      }
      return BarChartTrend.neutral;
    }

    return DarkBarChartCard(
      durationInMinutes: props['durationInMinutes'] as int? ?? 0,
      trend: parseTrend(props['trend']),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<DarkBarChartCard> createState() => _DarkBarChartCardState();
}

class _DarkBarChartCardState extends State<DarkBarChartCard>
    with SingleTickerProviderStateMixin {
  /// 深底核心视觉：深紫纸底 + 配套淡紫排线/描边（原型设计保留）
  static const _backgroundColor = Color(0xFF4B006E);
  static const _barColor = Color(0xFFC084FC);
  static const _iconBgColor = Color(0xFFA855F7);
  static const _lightInk = Color(0xFFD8B4FE);

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
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

    final hours = widget.durationInMinutes ~/ 60;
    final minutes = widget.durationInMinutes % 60;

    // 根据 size 计算尺寸
    final iconSize = widget.size.getIconSize();
    final iconContainerSize = iconSize * widget.size.iconContainerScale;
    final largeFontSize = widget.size.getLargeFontSize();
    final subtitleFontSize = widget.size.getSubtitleFontSize();
    final legendFontSize = widget.size.getLegendFontSize();
    final padding = widget.size.getPadding();

    // 手绘深紫纸卡：深底 + 淡紫排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : null,
        height:
            widget.inline
                ? double.maxFinite
                : widget.size.getHeightConstraints().maxHeight,
        radius: BorderRadius.circular(24 * scale),
        padding: padding,
        fillColor: _backgroundColor,
        hachureColor: _iconBgColor.withValues(alpha: 0.22),
        stroke: _lightInk,
        child: Stack(
          children: [
            // 左上角图标徽章（手绘圆底）
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: iconContainerSize,
                height: iconContainerSize,
                // 大圆角被 rough 引擎自动钳制成圆
                decoration: dsSketchDecoration(
                  theme: theme,
                  radius: BorderRadius.circular(iconContainerSize / 2),
                  fillColor: _iconBgColor.withValues(alpha: 0.8),
                  stroke: _lightInk,
                ),
                child: Center(
                  child: WiredIcon(
                    icon: Icons.bed,
                    size: iconSize,
                    color: Colors.white,
                    drawConfig: theme.wired.drawConfig,
                  ),
                ),
              ),
            ),

            // 右侧柱状条（睡眠周期可视化）
            Positioned(
              top: padding.top,
              right: 0,
              bottom: padding.bottom,
              child: _buildSleepCycles(),
            ),

            // 左下角睡眠时长显示
            Positioned(
              bottom: 0,
              left: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Text(
                    'TIME ASLEEP',
                    style: TextStyle(
                      fontSize: legendFontSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: _lightInk.withValues(alpha: 0.9),
                    ),
                  ),
                  SizedBox(height: widget.size.getSmallSpacing()),

                  // 时长显示 + 趋势图标
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) => child!,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: largeFontSize * 1.1,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 小时数
                              SizedBox(
                                width: largeFontSize * 1.5,
                                height: largeFontSize * 1.1,
                                child: AnimatedFlipCounter(
                                  value: hours * _animation.value,
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: largeFontSize,
                                    fontWeight: FontWeight.w600,
                                    height: 1.0,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                              // 单位 "h"
                              SizedBox(
                                height: subtitleFontSize * 1.1,
                                child: Text(
                                  'h',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: subtitleFontSize,
                                    fontWeight: FontWeight.w500,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              SizedBox(width: widget.size.getItemSpacing()),
                              // 分钟数
                              SizedBox(
                                width: largeFontSize * 1.5,
                                height: largeFontSize * 1.1,
                                child: AnimatedFlipCounter(
                                  value: minutes * _animation.value,
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: largeFontSize,
                                    fontWeight: FontWeight.w600,
                                    height: 1.0,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                              // 单位 "m"
                              SizedBox(
                                height: subtitleFontSize * 1.1,
                                child: Text(
                                  'm',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: subtitleFontSize,
                                    fontWeight: FontWeight.w500,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: widget.size.getItemSpacing()),
                        // 趋势图标
                        if (widget.trend != BarChartTrend.neutral)
                          Transform.rotate(
                            angle: widget.trend == BarChartTrend.up
                                ? 0.78
                                : -0.78, // 45度旋转
                            child: WiredIcon(
                              icon:
                                  widget.trend == BarChartTrend.up
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                              color: _lightInk,
                              size: iconSize,
                              drawConfig: theme.wired.drawConfig,
                            ),
                          ),
                      ],
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

  /// 构建睡眠周期柱状条
  Widget _buildSleepCycles() {
    // 模拟睡眠周期的不同宽度（从原型中提取的数据）
    final cycleWidths = [
      0.80, 0.95, 0.90, 0.98, 0.85, 0.75, 0.90, 0.96, 0.80,
      0.60, 0.45, 0.70, 0.40, 0.35, 0.50, 0.45,
    ];

    // 根据 size 计算尺寸
    final itemSpacing = widget.size.getSmallSpacing();
    final barHeight = widget.size.getBarWidth() * 0.8; // 柱状条高度
    final barMaxWidth = widget.size.getLegendIndicatorWidth() * 4; // 柱状条最大宽度

    // 计算需要的总高度
    final totalHeightNeeded = cycleWidths.length * barHeight + (cycleWidths.length - 1) * itemSpacing;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;

        // 如果需要的总高度超过可用高度，启用垂直滚动
        final needsScroll = totalHeightNeeded > availableHeight;

        return SizedBox(
          width: barMaxWidth,
          child: needsScroll
              ? SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (int i = 0; i < cycleWidths.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i < cycleWidths.length - 1 ? itemSpacing : 0,
                          ),
                          child: _buildCycleBar(cycleWidths[i], i, barHeight, barMaxWidth),
                        ),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < cycleWidths.length; i++)
                      _buildCycleBar(cycleWidths[i], i, barHeight, barMaxWidth),
                  ],
                ),
        );
      },
    );
  }

  /// 构建单个睡眠周期柱状条（斜纹胶囊：数据色浅底 + 浓斜纹 + 描边）
  Widget _buildCycleBar(double widthRatio, int index, double barHeight, double barMaxWidth) {
    // 计算每个柱状条的动画延迟
    // 16个元素，baseEnd = 0.6
    // step <= (1.0 - 0.6) / 15 = 0.0267
    final safeStep = 0.025;
    final start = index * safeStep;
    final end = (0.6 + index * safeStep).clamp(0.0, 1.0);
    final itemAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        start,
        end,
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: itemAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(widget.size.getSmallSpacing() * (1 - itemAnimation.value), 0),
          child: Opacity(
            opacity: 0.9 * itemAnimation.value,
            child: Padding(
              padding: EdgeInsets.only(right: widget.size.getSmallSpacing()),
              child: CustomPaint(
                size: Size(barMaxWidth * widthRatio, barHeight),
                painter: _StripedCycleBarPainter(
                  color: _barColor,
                  scale: widget.size.scale,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 斜纹睡眠周期条绘制器：数据色浅底（0.28）+ 数据色浓斜纹（0.9）+ 数据色描边（0.85）
///
/// 平直胶囊几何（无 rough 抖动），保证读数清晰（§9.5 统计图表规范）。
class _StripedCycleBarPainter extends CustomPainter {
  final Color color;
  final double scale;

  const _StripedCycleBarPainter({required this.color, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = Radius.circular(size.height / 2);
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
  bool shouldRepaint(covariant _StripedCycleBarPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.scale != scale;
  }
}
