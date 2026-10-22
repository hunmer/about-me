/// 甜甜圈图统计小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 斜纹甜甜圈环形图（淡墨轨道环垫底，各分类数据色浅底 + 浓斜纹 +
/// 数据色描边的扇环按扫描进度逐段扫入）/ 翻牌总数值 /
/// 图例列表（手绘色块指示器 + 标签，逐项错峰入场）。
library;

import 'dart:math' as math;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 甜甜圈图统计小组件
class DonutChartStatsCardWidget extends StatefulWidget {
  /// 总数值
  final double totalValue;

  /// 单位
  final String unit;

  /// 总数值标签
  final String totalLabel;

  /// 分类数据列表
  final List<ChartCategoryData> categories;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const DonutChartStatsCardWidget({
    super.key,
    required this.totalValue,
    this.unit = '',
    this.totalLabel = 'Total',
    required this.categories,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory DonutChartStatsCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    // 解析颜色（数据色 props，支持 hex）
    Color parseColor(dynamic colorValue) {
      if (colorValue == null) return const Color(0xFF2196F3);
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
      return const Color(0xFF2196F3);
    }

    // 解析分类数据
    List<ChartCategoryData> parseCategories(dynamic categoriesData) {
      if (categoriesData == null) return [];
      if (categoriesData is List) {
        return categoriesData.map((item) {
          if (item is Map<String, dynamic>) {
            return ChartCategoryData(
              label: item['label'] as String? ?? '',
              value: (item['value'] as num?)?.toDouble() ?? 0.0,
              color: parseColor(item['color']),
            );
          }
          return ChartCategoryData(
            label: '',
            value: 0.0,
            color: const Color(0xFF2196F3),
          );
        }).toList();
      }
      return [];
    }

    return DonutChartStatsCardWidget(
      totalValue: (props['totalValue'] as num?)?.toDouble() ?? 0.0,
      unit: props['unit'] as String? ?? '',
      totalLabel: props['totalLabel'] as String? ?? 'Total',
      categories: parseCategories(props['categories']),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<DonutChartStatsCardWidget> createState() =>
      _DonutChartStatsCardWidgetState();
}

class _DonutChartStatsCardWidgetState extends State<DonutChartStatsCardWidget>
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
    // 添加监听器确保 UI 更新
    _animationController.addListener(() {
      setState(() {});
    });
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
        width: widget.inline ? double.maxFinite : 384 * scale,
        height: widget.inline ? double.maxFinite : 200 * scale,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child:
            widget.size is SmallSize || widget.size is MediumSize
                ? _buildCompactLayout(theme)
                : _buildWideLayout(theme),
      ),
    );
  }

  /// 紧凑布局：上方甜甜圈图 + 总金额，下方分类列表（可滚动）
  Widget _buildCompactLayout(AppThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 甜甜圈图
            Center(
              child: SizedBox(
                width: 80 * widget.size.scale,
                height: 80 * widget.size.scale,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    categories: widget.categories,
                    progress: _animation.value,
                    theme: theme,
                    scale: widget.size.scale,
                  ),
                ),
              ),
            ),
            // Small 尺寸下隐藏总金额，其他尺寸显示
            if (widget.size is! SmallSize) ...[
              SizedBox(height: widget.size.getTitleSpacing()),
              // 总金额
              _buildTotalBlock(theme, wide: false),
            ],
          ],
        ),
        // 下方：分类列表（可滚动）
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildCategoryItems(theme),
            ),
          ),
        ),
      ],
    );
  }

  /// 宽敞布局：左侧甜甜圈图 + 总金额，右侧分类列表
  Widget _buildWideLayout(AppThemeData theme) {
    final scale = widget.size.scale;
    return Row(
      children: [
        // 左侧：圆环图 + 总金额
        Expanded(
          flex: 45,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 甜甜圈图
              SizedBox(
                width: 96 * scale,
                height: 96 * scale,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    categories: widget.categories,
                    progress: _animation.value,
                    theme: theme,
                    scale: scale,
                  ),
                ),
              ),
              SizedBox(height: widget.size.getTitleSpacing()),
              // 总金额
              _buildTotalBlock(theme, wide: true),
            ],
          ),
        ),
        SizedBox(width: 16 * scale),
        // 右侧：分类列表
        Expanded(
          flex: 55,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: _buildCategoryItems(theme),
          ),
        ),
      ],
    );
  }

  /// 总金额块（wide 模式左对齐并缩放适配，紧凑模式居中）
  Widget _buildTotalBlock(AppThemeData theme, {required bool wide}) {
    final scale = widget.size.scale;
    final counterTextStyle = TextStyle(
      color: theme.text,
      fontSize: widget.size.getTitleFontSize() * 0.8,
      fontWeight: FontWeight.w700,
      height: 1.0,
    );
    final labelStyle = TextStyle(
      color: theme.textSub,
      fontSize: widget.size.getLegendFontSize(),
      fontWeight: FontWeight.w500,
      height: 1.0,
    );

    final counter = AnimatedFlipCounter(
      value: widget.totalValue * _animation.value,
      fractionDigits: 2,
      textStyle: counterTextStyle,
    );
    final label = Text(
      widget.totalLabel,
      style: labelStyle,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );

    if (!wide) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          counter,
          SizedBox(height: widget.size.getSmallSpacing()),
          label,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 28 * scale,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: counter,
          ),
        ),
        SizedBox(height: widget.size.getSmallSpacing()),
        SizedBox(height: 16 * scale, child: label),
      ],
    );
  }

  List<Widget> _buildCategoryItems(AppThemeData theme) {
    final items = <Widget>[];
    final step = 0.08; // 确保 0.5 + 3 * 0.08 = 0.74 < 1.0

    for (int i = 0; i < widget.categories.length; i++) {
      final category = widget.categories[i];
      final itemAnimation = CurvedAnimation(
        parent: _animationController,
        curve: Interval(i * step, 0.5 + i * step, curve: Curves.easeOutCubic),
      );

      if (i > 0) {
        items.add(SizedBox(height: widget.size.getItemSpacing() * 2.5));
      }

      items.add(
        AnimatedBuilder(
          animation: itemAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: itemAnimation.value,
              child: Transform.translate(
                offset: Offset(
                  10 * widget.size.scale * (1 - itemAnimation.value),
                  0,
                ),
                child: _CategoryItem(
                  label: category.label,
                  color: category.color,
                  theme: theme,
                  size: widget.size,
                ),
              ),
            );
          },
        ),
      );
    }

    return items;
  }
}

/// 分类列表项
class _CategoryItem extends StatelessWidget {
  final String label;
  final Color color;
  final AppThemeData theme;
  final HomeWidgetSize size;

  const _CategoryItem({
    required this.label,
    required this.color,
    required this.theme,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final indicatorSize = size.getLegendIndicatorWidth();

    return Row(
      children: [
        // 手绘色块指示器：数据色实底 + 墨线描边
        Container(
          width: indicatorSize,
          height: indicatorSize,
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(indicatorSize / 4),
            fillColor: color,
          ),
        ),
        SizedBox(width: 12 * size.scale),
        // 标签文本
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: theme.text,
              fontSize: size.getLegendFontSize(),
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

/// 斜纹甜甜圈绘制器
///
/// 淡墨轨道环（surfaceAlt 底 + 低透明度墨线斜纹 + 淡墨描边）垫底，
/// 各分类按占比以数据色浅底（alpha 0.28）+ 数据色浓斜纹（alpha 0.9）+
/// 数据色描边（alpha 0.85）的平直扇环逐段扫入（[progress] 为 0~1 扫描
/// 插值），中心镂空露出纸底；颜色一律取 [theme] 语义色，
/// 分类色为数据色 props。
class _DonutChartPainter extends CustomPainter {
  final List<ChartCategoryData> categories;
  final double progress;
  final AppThemeData theme;
  final double scale;

  const _DonutChartPainter({
    required this.categories,
    required this.progress,
    required this.theme,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final rOut = size.shortestSide / 2 - 2;
    final rIn = rOut * 0.56;

    // 轨道环：淡墨底 + 低透明度斜纹 + 淡墨描边
    final trackPath = _annulus(center, rIn, rOut);
    canvas.drawPath(trackPath, Paint()..color = theme.surfaceAlt);
    paintDiagonalStripes(
      canvas,
      trackPath,
      Offset.zero & size,
      color: theme.ink.withValues(alpha: 0.28),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawPath(
      trackPath,
      Paint()
        ..color = theme.ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );

    // 各分类扇环按扫描进度逐段绘入（从顶部顺时针）
    final totalAngle = 2 * math.pi;
    var startAngle = -math.pi / 2;
    var drawnAngle = 0.0;

    for (final category in categories) {
      final categorySweepAngle = totalAngle * category.value; // 扇形的完整角度
      final remainingAngle = totalAngle * progress - drawnAngle; // 剩余可绘制角度

      if (remainingAngle <= 0) break; // 进度已用完，停止绘制

      // 计算本次要绘制的角度（取扇形完整角度和剩余角度的较小值）
      final sweepAngle =
          categorySweepAngle < remainingAngle
              ? categorySweepAngle
              : remainingAngle;

      if (sweepAngle > 0.004) {
        _paintSegment(
          canvas,
          size,
          center,
          rIn,
          rOut,
          startAngle,
          startAngle + sweepAngle,
          category.color,
        );
      }

      startAngle += categorySweepAngle; // 使用完整角度更新起始位置
      drawnAngle += sweepAngle; // 累加已绘制的角度
    }
  }

  /// 单个分类扇环：数据色浅底 + 浓斜纹 + 数据色描边
  void _paintSegment(
    Canvas canvas,
    Size canvasSize,
    Offset center,
    double rIn,
    double rOut,
    double a0,
    double a1,
    Color color,
  ) {
    final fullCircle = (a1 - a0) >= 2 * math.pi - 0.01;
    final path = fullCircle
        ? _annulus(center, rIn, rOut)
        : _sector(center, rIn, rOut, a0, a1);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.28));
    paintDiagonalStripes(
      canvas,
      path,
      Offset.zero & canvasSize,
      color: color.withValues(alpha: 0.9),
      strokeWidth: 3 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  /// 完整环形（evenOdd 镂空）
  Path _annulus(Offset c, double rIn, double rOut) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: c, radius: rOut))
      ..addOval(Rect.fromCircle(center: c, radius: rIn));
  }

  /// 扇环：外弧顺时针进、径向边、内弧逆时针回（同半圆仪表盘 _sector）
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
    return oldDelegate.progress != progress ||
        oldDelegate.theme != theme ||
        oldDelegate.categories != categories ||
        oldDelegate.scale != scale;
  }
}

/// 图表分类数据模型
class ChartCategoryData {
  final String label;
  final double value; // 占比 0-1
  final Color color;

  const ChartCategoryData({
    required this.label,
    required this.value,
    required this.color,
  });
}
