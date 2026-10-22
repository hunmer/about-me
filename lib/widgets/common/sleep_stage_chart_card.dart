/// 睡眠阶段图表卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 斜纹睡眠阶段胶囊（阶段数据色浅底 + 浓斜纹 + 描边，逐个错峰弹出）+
/// 淡墨虚线竖向网格 + 时间标签 / 底部图例（手绘色块指示器）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 睡眠阶段类型
///
/// 表示睡眠的不同阶段：核心睡眠、快速眼动(REM)、后快速眼动和深度睡眠
enum SleepStageType {
  /// 核心睡眠
  core,

  /// 快速眼动睡眠
  rem,

  /// 后快速眼动睡眠
  postREM,

  /// 深度睡眠
  deep,
}

/// 睡眠阶段数据模型
///
/// 描述单个睡眠阶段的位置、大小和类型信息
class SleepStageData {
  /// 睡眠阶段类型
  final SleepStageType type;

  /// 左边距位置（百分比，0-100）
  final double left;

  /// 顶部位置（百分比，0-100）
  final double topPercent;

  /// 宽度（百分比，0-100）
  final double widthPercent;

  /// 高度（像素）
  final double height;

  const SleepStageData({
    required this.type,
    required this.left,
    required this.topPercent,
    required this.widthPercent,
    required this.height,
  });

  /// 从 JSON 创建
  ///
  /// 用于从 JSON 数据反序列化睡眠阶段数据
  factory SleepStageData.fromJson(Map<String, dynamic> json) {
    return SleepStageData(
      type: SleepStageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SleepStageType.core,
      ),
      left: (json['left'] as num).toDouble(),
      topPercent: (json['topPercent'] as num).toDouble(),
      widthPercent: (json['widthPercent'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }

  /// 转换为 JSON
  ///
  /// 用于序列化睡眠阶段数据到 JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'left': left,
      'topPercent': topPercent,
      'widthPercent': widthPercent,
      'height': height,
    };
  }

  /// 复制并修改部分属性
  SleepStageData copyWith({
    SleepStageType? type,
    double? left,
    double? topPercent,
    double? widthPercent,
    double? height,
  }) {
    return SleepStageData(
      type: type ?? this.type,
      left: left ?? this.left,
      topPercent: topPercent ?? this.topPercent,
      widthPercent: widthPercent ?? this.widthPercent,
      height: height ?? this.height,
    );
  }
}

/// 睡眠阶段图表卡片组件
///
/// 展示睡眠阶段的可视化图表，支持动画效果和时间范围选择
class SleepStageChartCard extends StatefulWidget {
  /// 睡眠阶段数据列表
  final List<SleepStageData> sleepStages;

  /// 初始选中的标签索引
  final int selectedTab;

  /// 是否显示工具提示
  final bool showTooltip;

  /// 时间标签列表
  final List<String> timeLabels;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const SleepStageChartCard({
    super.key,
    required this.sleepStages,
    this.selectedTab = 1,
    this.showTooltip = true,
    this.timeLabels = const ['11:00', '12:00', '13:00', '14:00', '15:00'],
    this.size = const MediumSize(),
  });

  @override
  State<SleepStageChartCard> createState() => _SleepStageChartCardState();
}

class _SleepStageChartCardState extends State<SleepStageChartCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

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

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: ConstrainedBox(
        constraints: widget.size.getHeightConstraints(),
        child: DsSketchPanel(
          theme: theme,
          radius: BorderRadius.circular(24 * scale),
          padding: widget.size.getPadding(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 睡眠阶段图表
              _buildChart(theme),
              SizedBox(height: widget.size.getTitleSpacing()),
              // 图例
              _buildLegend(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建睡眠阶段图表
  Widget _buildChart(AppThemeData theme) {
    // 根据尺寸计算图表高度
    final chartHeight = widget.size.getHeightForChart();
    // 使用更大的内容宽度支持横向滚动
    final contentWidth = widget.size.getWidthForChart() * 1.5;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 使用实际可用宽度或最小内容宽度
        final availableWidth = constraints.maxWidth;
        final scrollableWidth = contentWidth > availableWidth
            ? contentWidth
            : availableWidth;

        return SizedBox(
          height: chartHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: scrollableWidth,
              height: chartHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 淡墨虚线竖向网格
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DashedVerticalGridPainter(
                        color: theme.ink.withValues(alpha: 0.18),
                        count: 5,
                        bottomInset: widget.size.getLegendFontSize() * 2.5,
                        scale: widget.size.scale,
                      ),
                    ),
                  ),
                  // 时间标签
                  Positioned(
                    left: widget.size.getSmallSpacing(),
                    right: widget.size.getSmallSpacing(),
                    bottom: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: widget.timeLabels.map((time) {
                        return Text(
                          time,
                          style: TextStyle(
                            fontSize: widget.size.getLegendFontSize(),
                            fontWeight: FontWeight.w600,
                            color: theme.textSub,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // 睡眠阶段气泡
                  ...widget.sleepStages.asMap().entries.map((entry) {
                    final index = entry.key;
                    final stage = entry.value;
                    final step = 0.08;
                    final start = (index * step).clamp(0.0, 0.92);
                    final end = (0.5 + index * step).clamp(0.0, 1.0);

                    final itemAnimation = CurvedAnimation(
                      parent: _animationController,
                      curve: Interval(start, end, curve: Curves.easeOutCubic),
                    );

                    return _SleepStageBubble(
                      stage: stage,
                      chartWidth: scrollableWidth,
                      chartHeight:
                          chartHeight - widget.size.getLegendFontSize() * 3,
                      animation: itemAnimation,
                      size: widget.size,
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建图例
  Widget _buildLegend(AppThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _LegendItem(
            color: const Color(0xFF9CB573),
            label: 'Core',
            theme: theme,
            size: widget.size,
          ),
          SizedBox(width: widget.size.getItemSpacing()),
          _LegendItem(
            color: const Color(0xFF8D6E63),
            label: 'REM',
            theme: theme,
            size: widget.size,
          ),
          SizedBox(width: widget.size.getItemSpacing()),
          _LegendItem(
            color: const Color(0xFFF4CD26),
            label: 'Post-REM',
            theme: theme,
            size: widget.size,
          ),
          SizedBox(width: widget.size.getItemSpacing()),
          _LegendItem(
            color: const Color(0xFFC8B6F9),
            label: 'Deep',
            theme: theme,
            size: widget.size,
          ),
        ],
      ),
    );
  }
}

/// 睡眠阶段气泡组件
///
/// 显示单个睡眠阶段的斜纹胶囊，带错峰弹出动画
/// （AnimatedBuilder 逐帧 rebuild 驱动宽高变化）。
class _SleepStageBubble extends StatelessWidget {
  final SleepStageData stage;
  final double chartWidth;
  final double chartHeight;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _SleepStageBubble({
    required this.stage,
    required this.chartWidth,
    required this.chartHeight,
    required this.animation,
    required this.size,
  });

  /// 获取当前阶段类型的颜色（数据色）
  Color _getColor() {
    switch (stage.type) {
      case SleepStageType.core:
        return const Color(0xFF9CB573);
      case SleepStageType.rem:
        return const Color(0xFFE99547);
      case SleepStageType.postREM:
        return const Color(0xFFF4CD26);
      case SleepStageType.deep:
        return const Color(0xFFC8B6F9);
    }
  }

  /// 根据 size 计算气泡高度缩放因子
  double _getHeightScale() {
    if (size is SmallSize) {
      return 0.6;
    } else if (size is MediumSize || size is WideSize) {
      return 1.0;
    } else if (size is LargeSize || size is Wide2Size) {
      return 1.3;
    } else {
      // Large3, Wide3
      return 1.6;
    }
  }

  /// 计算气泡的实际高度，确保不会重叠
  /// 根据 topPercent 所在的层级计算可用高度
  double _calculateBubbleHeight(double heightScale) {
    // 将图表垂直空间分为4层（对应4种睡眠阶段类型）
    final layerHeight = chartHeight / 4;

    // 计算该层级的可用高度（留出一定间距）
    final availableHeight = layerHeight * 0.7; // 使用70%的空间，留30%作为间距

    // 计算基础高度（基于 stage.height 和缩放）
    final baseHeight = stage.height * heightScale;

    // 取实际高度和可用高度的较小值，确保不会溢出到其他层级
    return baseHeight.clamp(0.0, availableHeight);
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final heightScale = _getHeightScale();
    final bubbleHeight = _calculateBubbleHeight(heightScale);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final width = (chartWidth * stage.widthPercent / 100) * animation.value;
        final height = bubbleHeight * animation.value;

        return Positioned(
          left: (chartWidth * stage.left / 100),
          top: (chartHeight * stage.topPercent / 100),
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(
              painter: _StageBubblePainter(color: color, scale: size.scale),
            ),
          ),
        );
      },
    );
  }
}

/// 斜纹睡眠阶段胶囊绘制器
///
/// 阶段数据色浅底（0.28）+ 数据色浓斜纹（0.9）+ 数据色描边（0.85），
/// 胶囊圆角（高的一半）。
class _StageBubblePainter extends CustomPainter {
  final Color color;
  final double scale;

  const _StageBubblePainter({required this.color, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.28));
    paintDiagonalStripes(
      canvas,
      Path()..addRRect(rrect),
      Offset.zero & size,
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
  bool shouldRepaint(covariant _StageBubblePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.scale != scale;
  }
}

/// 淡墨虚线竖向网格绘制器
class _DashedVerticalGridPainter extends CustomPainter {
  final Color color;
  final int count;
  final double bottomInset;
  final double scale;

  const _DashedVerticalGridPainter({
    required this.color,
    required this.count,
    required this.bottomInset,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || count <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2 * scale;
    final stepX = count > 1 ? size.width / (count - 1) : 0.0;
    final gridBottom = math.max(0.0, size.height - bottomInset);
    for (var i = 0; i < count; i++) {
      final x = stepX * i;
      for (var y = 0.0; y < gridBottom; y += 10 * scale) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, math.min(y + 5 * scale, gridBottom)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedVerticalGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.count != count ||
        oldDelegate.bottomInset != bottomInset ||
        oldDelegate.scale != scale;
  }
}

/// 图例项组件
///
/// 显示单个图例项，包含手绘色块和标签
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final AppThemeData theme;
  final HomeWidgetSize size;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.theme,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 手绘图例色块：数据色实底 + 墨线描边
        Container(
          width: size.getLegendIndicatorWidth(),
          height: size.getLegendIndicatorHeight(),
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(size.getLegendIndicatorHeight() / 2),
            fillColor: color,
          ),
        ),
        SizedBox(width: size.getSmallSpacing()),
        Text(
          label,
          style: TextStyle(
            fontSize: size.getLegendFontSize(),
            fontWeight: FontWeight.bold,
            color: theme.text,
          ),
        ),
      ],
    );
  }
}
