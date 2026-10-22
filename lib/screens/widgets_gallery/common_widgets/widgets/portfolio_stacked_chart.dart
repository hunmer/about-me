/// 投资组合堆叠图小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题 + 翻牌总额 + 手绘涨幅徽章 / 手绘图例色点 / 多段斜纹堆叠柱
/// （各资产段数据色浅底 + 数据色浓斜纹 + 数据色描边）。
/// 堆叠生长与翻牌计数动画保留。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 资产类型数据模型
class AssetType {
  final String label;
  final Color color;

  const AssetType({required this.label, required this.color});

  /// 从 JSON 创建
  factory AssetType.fromJson(Map<String, dynamic> json) {
    return AssetType(
      label: json['label'] as String? ?? '',
      color: Color(json['color'] as int? ?? 0xFF000000),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {'label': label, 'color': color.value};
  }
}

/// 月度数据模型
class MonthlyData {
  final int stocks;
  final int funds;
  final int bonds;

  const MonthlyData({
    required this.stocks,
    required this.funds,
    required this.bonds,
  });

  /// 从 JSON 创建
  factory MonthlyData.fromJson(Map<String, dynamic> json) {
    return MonthlyData(
      stocks: json['stocks'] as int? ?? 0,
      funds: json['funds'] as int? ?? 0,
      bonds: json['bonds'] as int? ?? 0,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {'stocks': stocks, 'funds': funds, 'bonds': bonds};
  }
}

/// 投资组合堆叠图小组件
class PortfolioStackedChartWidget extends StatefulWidget {
  final String title;
  final double totalAmount;
  final double growthPercentage;
  final List<AssetType> assetTypes;
  final List<MonthlyData> monthlyData;
  final List<String> monthLabels;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const PortfolioStackedChartWidget({
    super.key,
    required this.title,
    required this.totalAmount,
    required this.growthPercentage,
    required this.assetTypes,
    required this.monthlyData,
    required this.monthLabels,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory PortfolioStackedChartWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final assetTypesList =
        (props['assetTypes'] as List<dynamic>?)
            ?.map((e) => AssetType.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    final monthlyDataList =
        (props['monthlyData'] as List<dynamic>?)
            ?.map((e) => MonthlyData.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    final monthLabelsList =
        (props['monthLabels'] as List<dynamic>?)?.cast<String>() ?? const [];

    return PortfolioStackedChartWidget(
      title: props['title'] as String? ?? '',
      totalAmount: (props['totalAmount'] as num?)?.toDouble() ?? 0.0,
      growthPercentage: (props['growthPercentage'] as num?)?.toDouble() ?? 0.0,
      assetTypes: assetTypesList,
      monthlyData: monthlyDataList,
      monthLabels: monthLabelsList,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<PortfolioStackedChartWidget> createState() =>
      _PortfolioStackedChartWidgetState();
}

class _PortfolioStackedChartWidgetState extends State<PortfolioStackedChartWidget>
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

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 250,
        height: widget.inline ? double.maxFinite : 250,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: widget.size.getLegendFontSize(),
                    fontWeight: FontWeight.w500,
                    color: theme.textSub,
                  ),
                ),
                SizedBox(height: widget.size.getItemSpacing()),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) {
                            return AnimatedFlipCounter(
                              value: widget.totalAmount * _animation.value,
                              fractionDigits: 2,
                              prefix: '\$',
                              duration: const Duration(milliseconds: 1000),
                              textStyle: TextStyle(
                                fontSize: widget.size.getLargeFontSize() * 0.38,
                                fontWeight: FontWeight.w700,
                                color: theme.text,
                                height: 1.0,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: widget.size.getItemSpacing()),
                    // 手绘涨幅徽章：成功色淡底 + 墨线描边
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.size.getSmallSpacing(),
                        vertical: 2,
                      ),
                      decoration: dsSketchDecoration(
                        theme: theme,
                        radius: BorderRadius.circular(
                          widget.size.getLegendIndicatorWidth() / 2,
                        ),
                        fillColor: theme.success.withValues(alpha: 0.18),
                      ),
                      child: Row(
                        children: [
                          WiredIcon(
                            icon: Icons.trending_up,
                            size: widget.size.getIconSize() * 0.5,
                            color: theme.success,
                            drawConfig: theme.wired.drawConfig,
                          ),
                          SizedBox(
                            width: widget.size.getSmallSpacing(),
                          ),
                          Text(
                            '+${widget.growthPercentage.toInt()}%',
                            style: TextStyle(
                              fontSize: widget.size.getLegendFontSize() - 1,
                              fontWeight: FontWeight.w700,
                              color: theme.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.size.getItemSpacing()),
                Wrap(
                  spacing: widget.size.getItemSpacing() * 1.5,
                  children:
                      widget.assetTypes.map((type) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 手绘图例色点（§9.5 小控件档）
                            Container(
                              width: widget.size.getLegendIndicatorWidth() * 0.5,
                              height: widget.size.getLegendIndicatorHeight() * 0.5,
                              decoration: dsSketchDecoration(
                                theme: theme,
                                radius: BorderRadius.circular(
                                  widget.size.getLegendIndicatorWidth() * 0.25,
                                ),
                                fillColor: type.color,
                              ),
                            ),
                            SizedBox(
                              width: widget.size.getSmallSpacing(),
                            ),
                            Text(
                              type.label,
                              style: TextStyle(
                                fontSize: widget.size.getLegendFontSize(),
                                fontWeight: FontWeight.w400,
                                color: theme.textSub,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ],
            ),
            const Spacer(),
            _StackedBarChart(
              monthlyData: widget.monthlyData,
              assetTypes: widget.assetTypes,
              animation: _animation,
              size: widget.size,
            ),
            SizedBox(height: widget.size.getItemSpacing()),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children:
                  widget.monthLabels.map((label) {
                    return Text(
                      label,
                      style: TextStyle(
                        fontSize: widget.size.getLegendFontSize(),
                        fontWeight: FontWeight.w500,
                        color: theme.textSub,
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StackedBarChart extends StatelessWidget {
  final List<MonthlyData> monthlyData;
  final List<AssetType> assetTypes;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _StackedBarChart({
    required this.monthlyData,
    required this.assetTypes,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final maxTotal = monthlyData
        .map((d) => d.stocks + d.funds + d.bonds)
        .reduce((a, b) => a > b ? a : b);

    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(monthlyData.length, (index) {
          final data = monthlyData[index];
          final barAnimation = CurvedAnimation(
            parent: animation,
            curve: Interval(
              index * 0.05,
              0.5 + index * 0.03,
              curve: Curves.easeOutCubic,
            ),
          );

          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: size.getBarSpacing(),
              ),
              child: _StackedBar(
                data: data,
                animation: barAnimation,
                assetTypes: assetTypes,
                maxTotal: maxTotal,
                size: size,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StackedBar extends StatelessWidget {
  final MonthlyData data;
  final Animation<double> animation;
  final List<AssetType> assetTypes;
  final int maxTotal;
  final HomeWidgetSize size;

  const _StackedBar({
    required this.data,
    required this.animation,
    required this.assetTypes,
    required this.maxTotal,
    required this.size,
  });

  Color _assetColor(int index, Color fallback) {
    if (index < assetTypes.length) return assetTypes[index].color;
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final borderRadius = size.getSmallSpacing();

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final stocksHeight =
                (data.stocks / maxTotal) * availableHeight * animation.value;
            final fundsHeight =
                (data.funds / maxTotal) * availableHeight * animation.value;
            final bondsHeight =
                (data.bonds / maxTotal) * availableHeight * animation.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _stripedSegment(
                  bondsHeight,
                  _assetColor(2, const Color(0xFF000000)),
                  borderRadius,
                ),
                _stripedSegment(
                  fundsHeight,
                  _assetColor(1, const Color(0xFF2563EB)),
                  borderRadius,
                ),
                _stripedSegment(
                  stocksHeight,
                  _assetColor(0, const Color(0xFF94B8FF)),
                  borderRadius,
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 单个堆叠段：数据色浅底 + 数据色浓斜纹 + 数据色描边（§9.5）
  Widget _stripedSegment(double height, Color color, double radius) {
    return CustomPaint(
      size: Size(0, height),
      painter: _StripedSegmentPainter(
        color: color,
        scale: size.scale,
        radius: radius,
      ),
    );
  }
}

/// 堆叠段绘制器：数据色浅底（0.28）+ 数据色浓斜纹（0.9）+ 数据色描边（0.85）
///
/// 平直圆角几何（无 rough 抖动），保证读数清晰（§9.5 统计图表规范）。
class _StripedSegmentPainter extends CustomPainter {
  final Color color;
  final double scale;
  final double radius;

  const _StripedSegmentPainter({
    required this.color,
    required this.scale,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final rect = Offset.zero & size;

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
  bool shouldRepaint(covariant _StripedSegmentPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.scale != scale ||
        oldDelegate.radius != radius;
  }
}
