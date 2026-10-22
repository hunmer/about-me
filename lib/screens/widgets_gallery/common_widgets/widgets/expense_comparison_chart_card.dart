/// 支出对比图表卡片（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题 + 翻牌金额 + 手绘图例（色块指示器）/ 变化百分比徽章（危险色斜纹底）/
/// 双数据系列斜纹柱状图（上月淡墨斜纹 vs 本月主题色浓斜纹）/ X 轴刻度。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 支出对比图表卡片
///
/// 用于展示支出对比的卡片组件，支持：
/// - 本月支出金额显示（带动画计数）
/// - 变化百分比徽章
/// - 双数据系列柱状图（上月 vs 本月）
class ExpenseComparisonChartCardWidget extends StatefulWidget {
  /// 标题文本
  final String title;

  /// 本月金额
  final double currentAmount;

  /// 单位
  final String unit;

  /// 变化百分比
  final double changePercent;

  /// 日数据列表
  final List<DailyExpenseDataModel> dailyData;

  /// Y轴最大值
  final double maxValue;

  /// X轴标签列表（自定义图例）
  final List<String> labels;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const ExpenseComparisonChartCardWidget({
    super.key,
    required this.title,
    required this.currentAmount,
    required this.unit,
    required this.changePercent,
    required this.dailyData,
    this.maxValue = 24.0,
    this.labels = const [],
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于小组件系统）
  factory ExpenseComparisonChartCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final dailyDataList = (props['dailyData'] as List<dynamic>?);
    final dailyData =
        dailyDataList?.map((item) {
          final map = item as Map<String, dynamic>;
          return DailyExpenseDataModel(
            lastMonth: (map['lastMonth'] as num).toDouble(),
            currentMonth: (map['currentMonth'] as num).toDouble(),
          );
        }).toList() ??
        [];

    final labelsList =
        (props['labels'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    return ExpenseComparisonChartCardWidget(
      title: props['title'] as String? ?? '本月支出',
      currentAmount: (props['currentAmount'] as num?)?.toDouble() ?? 0.0,
      unit: props['unit'] as String? ?? '',
      changePercent: (props['changePercent'] as num?)?.toDouble() ?? 0.0,
      dailyData: dailyData,
      maxValue: (props['maxValue'] as num?)?.toDouble() ?? 24.0,
      labels: labelsList,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<ExpenseComparisonChartCardWidget> createState() =>
      _ExpenseComparisonChartCardWidgetState();
}

class _ExpenseComparisonChartCardWidgetState
    extends State<ExpenseComparisonChartCardWidget>
    with SingleTickerProviderStateMixin {
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

  /// 构建图例行（手绘色块指示器 + 标签）
  Widget _buildLegendRow(AppThemeData theme) {
    return Row(
      children: [
        Row(
          children: [
            Container(
              width: widget.size.getLegendIndicatorWidth(),
              height: widget.size.getLegendIndicatorHeight(),
              margin: EdgeInsets.only(right: widget.size.getSmallSpacing()),
              decoration: dsSketchDecoration(
                theme: theme,
                radius: BorderRadius.circular(
                  widget.size.getLegendIndicatorHeight() / 2,
                ),
                fillColor: theme.surfaceAlt,
              ),
            ),
            Text(
              '上月',
              style: TextStyle(
                fontSize: widget.size.getLegendFontSize() * 0.8,
                fontWeight: FontWeight.w500,
                color: theme.textSub,
              ),
            ),
          ],
        ),
        SizedBox(width: widget.size.getItemSpacing()),
        Row(
          children: [
            Container(
              width: widget.size.getLegendIndicatorWidth(),
              height: widget.size.getLegendIndicatorHeight(),
              margin: EdgeInsets.only(right: widget.size.getSmallSpacing()),
              decoration: dsSketchDecoration(
                theme: theme,
                radius: BorderRadius.circular(
                  widget.size.getLegendIndicatorHeight() / 2,
                ),
                fillColor: theme.primary,
              ),
            ),
            Text(
              '本月',
              style: TextStyle(
                fontSize: widget.size.getLegendFontSize(),
                fontWeight: FontWeight.w500,
                color: theme.textSub,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建变化百分比徽章（危险色浅底 + 墨线描边 + 手绘箭头）
  Widget _buildChangePercentBadge(AppThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.size.getSmallSpacing() * 2,
        vertical: widget.size.getSmallSpacing() / 2,
      ),
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(99),
        fillColor: theme.danger.withValues(alpha: 0.15),
      ),
      child: Row(
        children: [
          Transform.rotate(
            angle: -0.785, // -45度
            child: WiredIcon(
              icon: Icons.arrow_forward,
              size: widget.size.getSubtitleFontSize(),
              color: theme.danger,
              drawConfig: theme.wired.drawConfig,
            ),
          ),
          SizedBox(width: widget.size.getItemSpacing() / 4),
          Text(
            '+${widget.changePercent}%',
            style: TextStyle(
              fontSize: widget.size.getSubtitleFontSize(),
              fontWeight: FontWeight.bold,
              color: theme.danger,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 400,
        height: widget.inline ? double.maxFinite : null,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题和金额
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: widget.size.getTitleFontSize(),
                            fontWeight: FontWeight.bold,
                            color: theme.text,
                          ),
                        ),
                        SizedBox(
                          height: widget.size.getItemSpacing() * 0.5,
                        ),
                        SizedBox(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AnimatedFlipCounter(
                                value:
                                    widget.currentAmount * _animation.value,
                                fractionDigits: 2,
                                textStyle: TextStyle(
                                  fontSize:
                                      widget.size.getLargeFontSize() * 0.6,
                                  fontWeight: FontWeight.w600,
                                  color: theme.primary,
                                  height: 1.0,
                                ),
                              ),
                              SizedBox(
                                width: widget.size.getItemSpacing() / 2,
                              ),
                              Text(
                                widget.unit,
                                style: TextStyle(
                                  fontSize:
                                      widget.size.getSubtitleFontSize(),
                                  fontWeight: FontWeight.w500,
                                  color: theme.textSub,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Wide size: 图例和变化百分比在右侧
                    if (widget.size is WideSize ||
                        widget.size is Wide2Size ||
                        widget.size is Wide3Size)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildLegendRow(theme),
                          SizedBox(height: widget.size.getItemSpacing()),
                          _buildChangePercentBadge(theme),
                        ],
                      ),
                  ],
                ),
                // 非 wide size: 图例和变化百分比在新的一行横向展示
                if (!(widget.size is WideSize ||
                    widget.size is Wide2Size ||
                    widget.size is Wide3Size)) ...[
                  SizedBox(height: widget.size.getItemSpacing()),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLegendRow(theme),
                      _buildChangePercentBadge(theme),
                    ],
                  ),
                ],
                SizedBox(height: widget.size.getTitleSpacing()),
                // 柱状图
                Flexible(
                  child: _BarChartWidget(
                    data: widget.dailyData,
                    maxValue: widget.maxValue,
                    labels: widget.labels,
                    animation: _animation,
                    theme: theme,
                    size: widget.size,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 日支出数据模型
class DailyExpenseDataModel {
  final double lastMonth;
  final double currentMonth;

  const DailyExpenseDataModel({
    required this.lastMonth,
    required this.currentMonth,
  });

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {'lastMonth': lastMonth, 'currentMonth': currentMonth};
  }

  /// 从 Map 创建
  factory DailyExpenseDataModel.fromMap(Map<String, dynamic> map) {
    return DailyExpenseDataModel(
      lastMonth: (map['lastMonth'] as num).toDouble(),
      currentMonth: (map['currentMonth'] as num).toDouble(),
    );
  }
}

/// 柱状图组件
class _BarChartWidget extends StatelessWidget {
  final List<DailyExpenseDataModel> data;
  final double maxValue;
  final List<String> labels;
  final Animation<double> animation;
  final AppThemeData theme;
  final HomeWidgetSize size;

  /// 柱子最小宽度
  static const double minBarWidth = 10.0;

  /// 柱子间距
  static const double barSpacing = 4.0;

  const _BarChartWidget({
    required this.data,
    required this.maxValue,
    required this.labels,
    required this.animation,
    required this.theme,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // 计算总宽度：每个柱子的宽度 + 间距
    final barWidth = size.getBarWidth().clamp(minBarWidth, double.infinity);
    final stepWidth = barWidth + barSpacing * 2;
    final totalWidth = data.length * stepWidth;
    final labelHeight = size.getLegendFontSize() * 2;

    // 整个图表区域（柱状图 + X轴标签）使用同一个滚动控制器
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalWidth,
        child: Column(
          children: [
            // 柱状图主体
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(data.length, (index) {
                  final barAnimation = CurvedAnimation(
                    parent: animation,
                    curve: Interval(
                      index * 0.015,
                      0.5 + index * 0.015,
                      curve: Curves.easeOutCubic,
                    ),
                  );
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: barSpacing),
                    child: _BarItemWidget(
                      lastMonth: data[index].lastMonth,
                      currentMonth: data[index].currentMonth,
                      maxValue: maxValue,
                      animation: barAnimation,
                      theme: theme,
                      size: size,
                      minWidth: minBarWidth,
                    ),
                  );
                }),
              ),
            ),
            // X轴标签 - 使用自绘，与柱状图在同一滚动容器中
            SizedBox(height: size.getSmallSpacing() * 3),
            CustomPaint(
              size: Size(totalWidth, labelHeight),
              painter: _XAxisLabelPainter(
                labels:
                    labels.isEmpty
                        ? ['01', '05', '10', '15', '20', '25', '30']
                        : labels,
                labelIndices:
                    labels.isEmpty
                        ? [0, 4, 9, 14, 19, 24, 29]
                        : List.generate(labels.length, (i) => i),
                totalDataCount: data.length,
                fontSize: size.getLegendFontSize(),
                color: theme.textSub,
                barWidth: barWidth,
                barSpacing: barSpacing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// X轴标签绘制器
class _XAxisLabelPainter extends CustomPainter {
  final List<String> labels;
  final List<int> labelIndices;
  final int totalDataCount;
  final double fontSize;
  final Color color;
  final double barWidth;
  final double barSpacing;

  _XAxisLabelPainter({
    required this.labels,
    required this.labelIndices,
    required this.totalDataCount,
    required this.fontSize,
    required this.color,
    required this.barWidth,
    required this.barSpacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    final stepWidth = barWidth + barSpacing * 2;

    for (int i = 0; i < labels.length; i++) {
      final labelIndex = labelIndices[i];
      if (labelIndex >= totalDataCount) continue;

      final x = labelIndex * stepWidth + stepWidth / 2;

      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.5,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, 0));
    }
  }

  @override
  bool shouldRepaint(covariant _XAxisLabelPainter oldDelegate) {
    return oldDelegate.labels != labels ||
        oldDelegate.totalDataCount != totalDataCount ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.color != color ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.barSpacing != barSpacing;
  }
}

/// 单个柱状图项（上月柱垫底 + 本月柱覆盖，斜纹数据区）
class _BarItemWidget extends StatelessWidget {
  final double lastMonth;
  final double currentMonth;
  final double maxValue;
  final Animation<double> animation;
  final AppThemeData theme;
  final HomeWidgetSize size;
  final double minWidth;

  const _BarItemWidget({
    required this.lastMonth,
    required this.currentMonth,
    required this.maxValue,
    required this.animation,
    required this.theme,
    required this.size,
    this.minWidth = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    // 使用最小宽度限制
    final barWidth = size.getBarWidth().clamp(minWidth, double.infinity);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final lastMonthHeight =
                maxValue > 0
                    ? (lastMonth / maxValue * availableHeight * animation.value)
                    : 0.0;
            final currentMonthHeight =
                maxValue > 0
                    ? (currentMonth /
                        maxValue *
                        availableHeight *
                        animation.value)
                    : 0.0;

            return SizedBox(
              width: barWidth,
              height: availableHeight,
              child: CustomPaint(
                size: Size(barWidth, availableHeight),
                painter: _StripedCompareColumnPainter(
                  lastHeight: lastMonthHeight,
                  currentHeight: currentMonthHeight,
                  dataColor: theme.primary,
                  theme: theme,
                  scale: size.scale,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 双柱对比绘制器：上月柱淡墨斜纹（surfaceAlt 底）垫底，
/// 本月柱数据色浅底 + 浓斜纹 + 数据色描边覆盖其上，顶部微圆角。
class _StripedCompareColumnPainter extends CustomPainter {
  final double lastHeight;
  final double currentHeight;
  final Color dataColor;
  final AppThemeData theme;
  final double scale;

  const _StripedCompareColumnPainter({
    required this.lastHeight,
    required this.currentHeight,
    required this.dataColor,
    required this.theme,
    required this.scale,
  });

  void _paintColumn(Canvas canvas, Rect rect, Color fillColor) {
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(4),
      topRight: const Radius.circular(4),
    );
    final path = Path()..addRRect(rrect);
    canvas.drawRRect(rrect, Paint()..color = fillColor.withValues(alpha: 0.28));
    paintDiagonalStripes(
      canvas,
      path,
      rect,
      color: fillColor.withValues(alpha: 0.9),
      strokeWidth: 3 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = fillColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // 上月柱：轨道配色（surfaceAlt 底 + 淡墨斜纹 + 淡墨描边）
    if (lastHeight > 0.5) {
      final rect = Rect.fromLTWH(
        0,
        size.height - lastHeight,
        size.width,
        lastHeight,
      );
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(rrect, Paint()..color = theme.surfaceAlt);
      paintDiagonalStripes(
        canvas,
        Path()..addRRect(rrect),
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
    // 本月柱：数据色斜纹覆盖
    if (currentHeight > 0.5) {
      _paintColumn(
        canvas,
        Rect.fromLTWH(
          0,
          size.height - currentHeight,
          size.width,
          currentHeight,
        ),
        dataColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripedCompareColumnPainter oldDelegate) {
    return oldDelegate.lastHeight != lastHeight ||
        oldDelegate.currentHeight != currentHeight ||
        oldDelegate.dataColor != dataColor ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}
