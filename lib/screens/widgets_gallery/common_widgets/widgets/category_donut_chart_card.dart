/// 分类环形图卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 顶部手绘徽章 + 周期说明 / 斜纹分段圆环（各分类数据色斜纹扇环，
/// 中心显示总额）/ 分类列表（手绘色块指示器 + 标签 + 百分比，逐项错峰入场）。
library;

import 'dart:math' as math;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 分类数据模型
class CategoryChartData {
  final String label;
  final double percentage;
  final Color color;

  const CategoryChartData({
    required this.label,
    required this.percentage,
    required this.color,
  });

  /// 从 JSON 创建
  factory CategoryChartData.fromJson(Map<String, dynamic> json) {
    return CategoryChartData(
      label: json['label'] as String,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      color: Color(json['color'] as int? ?? 0xFF000000),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'percentage': percentage,
      'color': color.value,
    };
  }
}

/// 分类环形图卡片小组件
class CategoryDonutChartCardWidget extends StatefulWidget {
  /// 顶部徽章标签
  final String badgeLabel;

  /// 时间周期描述
  final String timePeriod;

  /// 总金额数值
  final double totalAmount;

  /// 总金额单位（如 K、M 等）
  final String totalUnit;

  /// 分类数据列表
  final List<CategoryChartData> categories;

  /// 主色调（用于徽章背景）
  final Color? primaryColor;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const CategoryDonutChartCardWidget({
    super.key,
    required this.badgeLabel,
    required this.timePeriod,
    required this.totalAmount,
    required this.totalUnit,
    required this.categories,
    this.primaryColor,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory CategoryDonutChartCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final categoriesList = props['categories'] as List<dynamic>?;
    final categories = categoriesList?.map((categoryJson) {
      return CategoryChartData.fromJson(categoryJson as Map<String, dynamic>);
    }).toList() ?? [];

    final primaryColor = props['primaryColor'] as int?;
    return CategoryDonutChartCardWidget(
      badgeLabel: props['badgeLabel'] as String? ?? '',
      timePeriod: props['timePeriod'] as String? ?? '',
      totalAmount: (props['totalAmount'] as num?)?.toDouble() ?? 0.0,
      totalUnit: props['totalUnit'] as String? ?? '',
      categories: categories,
      primaryColor: primaryColor != null ? Color(primaryColor) : null,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<CategoryDonutChartCardWidget> createState() =>
      _CategoryDonutChartCardWidgetState();
}

class _CategoryDonutChartCardWidgetState extends State<CategoryDonutChartCardWidget>
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
    final primaryColor = widget.primaryColor ?? const Color(0xFFD8F57E);

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 340,
        height: widget.inline ? double.maxFinite : 500,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部标签
            _buildHeaderSection(theme, primaryColor),
            SizedBox(height: widget.size.getTitleSpacing()),
            // 环形图
            Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: _DonutChart(
                  categories: widget.categories,
                  totalAmount: widget.totalAmount,
                  totalUnit: widget.totalUnit,
                  animation: _animation,
                  size: widget.size,
                  theme: theme,
                ),
              ),
            ),
            SizedBox(height: widget.size.getTitleSpacing()),
            // 分类列表
            _buildCategoryList(theme),
          ],
        ),
      ),
    );
  }

  /// 构建头部区域（数据色手绘徽章 + 周期说明）
  Widget _buildHeaderSection(AppThemeData theme, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.size.getItemSpacing() * 1.5,
            vertical: widget.size.getItemSpacing() * 0.5,
          ),
          decoration: dsSketchDecoration(
            theme: theme,
            // 大圆角被 rough 引擎自动钳制成胶囊
            radius: BorderRadius.circular(20),
            fillColor: primaryColor,
          ),
          child: Text(
            widget.badgeLabel,
            style: TextStyle(
              fontSize: widget.size.getLegendFontSize(),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: theme.ink,
            ),
          ),
        ),
        SizedBox(height: widget.size.getItemSpacing()),
        Text(
          widget.timePeriod,
          style: TextStyle(
            fontSize: widget.size.getSubtitleFontSize(),
            fontWeight: FontWeight.w500,
            color: theme.textSub,
          ),
        ),
      ],
    );
  }

  /// 构建分类列表
  Widget _buildCategoryList(AppThemeData theme) {
    return Column(
      children: List.generate(
        widget.categories.length,
        (index) {
          final category = widget.categories[index];
          final itemAnimation = CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              0.3 + index * 0.1,
              0.8 + index * 0.05,
              curve: Curves.easeOutCubic,
            ),
          );

          return Padding(
            padding: EdgeInsets.only(bottom: widget.size.getItemSpacing()),
            child: _CategoryItem(
              label: category.label,
              percentage: category.percentage,
              color: category.color,
              animation: itemAnimation,
              size: widget.size,
              theme: theme,
            ),
          );
        },
      ),
    );
  }
}

/// 环形图绘制组件
class _DonutChart extends StatelessWidget {
  final List<CategoryChartData> categories;
  final double totalAmount;
  final String totalUnit;
  final Animation<double> animation;
  final HomeWidgetSize size;
  final AppThemeData theme;

  const _DonutChart({
    required this.categories,
    required this.totalAmount,
    required this.totalUnit,
    required this.animation,
    required this.size,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(220, 220),
          painter: _DonutChartPainter(
            categories: categories,
            animation: animation.value,
            theme: theme,
            scale: size.scale,
          ),
          child: child,
        );
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedFlipCounter(
              value: totalAmount * animation.value,
              fractionDigits: 0,
              suffix: totalUnit,
              duration: const Duration(milliseconds: 800),
              textStyle: TextStyle(
                fontSize: size.getLargeFontSize(),
                fontWeight: FontWeight.w700,
                color: theme.text,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 环形图绘制器（平直几何 + 斜纹）
///
/// 从顶部起按占比切分扇环（段间留小间隙便于读数）：每段铺
/// 数据色浅底 + 浓斜纹 + 数据色描边，随 [animation] 同步生长。
class _DonutChartPainter extends CustomPainter {
  final List<CategoryChartData> categories;
  final double animation;
  final AppThemeData theme;
  final double scale;

  _DonutChartPainter({
    required this.categories,
    required this.animation,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rOuter = size.width / 2 - 20;
    // 斜纹需要足够的环宽承载（原细描边环加厚为 12px 数据带）
    final rInner = rOuter - 12;
    final bounds = Offset.zero & size;
    // 段间小间隙（占总弧比例）
    final gapAngle = 2 * math.pi * 0.012;

    double cursor = -math.pi / 2; // 从顶部开始

    for (final category in categories) {
      final sweepAngle =
          (category.percentage / 100) * 2 * math.pi * animation - gapAngle;
      if (sweepAngle <= 0.01) {
        cursor += (category.percentage / 100) * 2 * math.pi * animation;
        continue;
      }

      final path = _sector(center, rInner, rOuter, cursor, cursor + sweepAngle);
      canvas.drawPath(
        path,
        Paint()..color = category.color.withValues(alpha: 0.28),
      );
      paintDiagonalStripes(
        canvas,
        path,
        bounds,
        color: category.color.withValues(alpha: 0.9),
        strokeWidth: 3 * scale,
        spacing: 6.5 * scale,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = category.color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );

      cursor += sweepAngle + gapAngle;
    }
  }

  /// 平直扇环路径（与 half_gauge_card 的 _sector 同款）
  Path _sector(Offset c, double rIn, double rOut, double a0, double a1) {
    final largeArc = (a1 - a0) > math.pi;
    final path = Path();
    path.moveTo(c.dx + rOut * math.cos(a0), c.dy + rOut * math.sin(a0));
    path.arcToPoint(
      Offset(c.dx + rOut * math.cos(a1), c.dy + rOut * math.sin(a1)),
      radius: Radius.circular(rOut),
      largeArc: largeArc,
      clockwise: true,
    );
    path.lineTo(c.dx + rIn * math.cos(a1), c.dy + rIn * math.sin(a1));
    path.arcToPoint(
      Offset(c.dx + rIn * math.cos(a0), c.dy + rIn * math.sin(a0)),
      radius: Radius.circular(rIn),
      largeArc: largeArc,
      clockwise: false,
    );
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}

/// 分类列表项
class _CategoryItem extends StatelessWidget {
  final String label;
  final double percentage;
  final Color color;
  final Animation<double> animation;
  final HomeWidgetSize size;
  final AppThemeData theme;

  const _CategoryItem({
    required this.label,
    required this.percentage,
    required this.color,
    required this.animation,
    required this.size,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(10 * (1 - animation.value), 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // 手绘色块指示器：数据色实底 + 墨线描边
                    Container(
                      width: 10,
                      height: 10,
                      decoration: dsSketchDecoration(
                        theme: theme,
                        radius: BorderRadius.circular(3),
                        fillColor: color,
                      ),
                    ),
                    SizedBox(width: size.getItemSpacing() * 1.5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: size.getSubtitleFontSize(),
                        fontWeight: FontWeight.w500,
                        color: theme.text,
                      ),
                    ),
                  ],
                ),
                AnimatedFlipCounter(
                  value: percentage * animation.value,
                  fractionDigits: 0,
                  suffix: '%',
                  duration: const Duration(milliseconds: 600),
                  textStyle: TextStyle(
                    fontSize: size.getSubtitleFontSize(),
                    fontWeight: FontWeight.w600,
                    color: theme.text,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
