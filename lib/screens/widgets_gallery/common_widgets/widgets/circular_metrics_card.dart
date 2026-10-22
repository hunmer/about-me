/// 环形指标卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题 + 指标列表（斜纹环形进度条：淡墨轨道环垫底、数据色扇环扫描
/// 扫入，中央手绘图标；扫描动画保留）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 指标数据模型
class MetricData {
  final IconData icon;
  final String value;
  final String label;
  final double progress;
  final Color color;

  const MetricData({
    required this.icon,
    required this.value,
    required this.label,
    required this.progress,
    required this.color,
  });

  /// 从 JSON 创建
  factory MetricData.fromJson(Map<String, dynamic> json) {
    final iconValue = json['icon'] as int?;
    // 处理 value 可能是 int 或 String 的情况
    final valueStr = json['value'];
    final value = valueStr is int ? '$valueStr' : (valueStr as String? ?? '');
    return MetricData(
      icon: dynamicIconData(iconValue ?? Icons.info.codePoint, fontFamily: 'MaterialIcons'),
      value: value,
      label: json['label'] as String? ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      color: Color((json['color'] as int?) ?? 0xFF2196F3),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'icon': icon.codePoint,
      'value': value,
      'label': label,
      'progress': progress,
      'color': color.value,
    };
  }
}

/// 环形指标卡片小组件
class CircularMetricsCardWidget extends StatefulWidget {
  /// 标题
  final String title;

  /// 指标数据列表
  final List<MetricData> metrics;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const CircularMetricsCardWidget({
    super.key,
    required this.title,
    required this.metrics,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory CircularMetricsCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final metricsList = props['metrics'] as List<dynamic>?;
    final metrics = metricsList?.map((item) {
      return MetricData.fromJson(item as Map<String, dynamic>);
    }).toList() ?? [];

    return CircularMetricsCardWidget(
      title: props['title'] as String? ?? 'Overview',
      metrics: metrics,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<CircularMetricsCardWidget> createState() =>
      _CircularMetricsCardWidgetState();
}

class _CircularMetricsCardWidgetState extends State<CircularMetricsCardWidget>
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
    Widget panel = DsSketchPanel(
      theme: theme,
      width: widget.inline ? double.maxFinite : 380,
      height: widget.inline ? double.maxFinite : null,
      radius: BorderRadius.circular(24 * scale),
      padding: widget.size.getPadding(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Text(
            widget.title,
            style: TextStyle(
              color: theme.textSub,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: widget.size.getTitleSpacing()),
          // 指标列表（支持滚动）
          Expanded(child: _buildMetricsList(context, theme)),
        ],
      ),
    );
    if (!widget.inline) {
      // 非内联模式沿用尺寸档的高度约束（min~max）
      panel = ConstrainedBox(
        constraints: widget.size.getHeightConstraints(),
        child: panel,
      );
    }
    return WiredDraw(child: panel);
  }

  /// 构建可滚动的指标列表
  Widget _buildMetricsList(BuildContext context, AppThemeData theme) {
    final metrics = widget.metrics;

    if (metrics.isEmpty) {
      return Center(
        child: Text('暂无数据', style: TextStyle(color: theme.textSub)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: widget.size.getItemSpacing()),
          child: _MetricItemWidget(
            data: metrics[index],
            animation: _animation,
            index: index,
            size: widget.size,
          ),
        );
      },
    );
  }
}

/// 单个指标项组件
class _MetricItemWidget extends StatelessWidget {
  final MetricData data;
  final Animation<double> animation;
  final int index;
  final HomeWidgetSize size;

  const _MetricItemWidget({
    required this.data,
    required this.animation,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final start = index * 0.1;
    final end = (0.6 + index * 0.1).clamp(0.0, 1.0);
    final itemAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(
        start,
        end,
        curve: Curves.easeOutCubic,
      ),
    );

    // 根据 size 计算各元素尺寸
    final iconSize = size.getIconSize();
    final containerSize = iconSize * size.iconContainerScale;
    // 环厚沿用原描边宽度，并设下限保证斜纹可读
    final ringThickness = math.max(
      size.getStrokeWidth() * size.progressStrokeScale,
      containerSize * 0.1,
    );
    final valueFontSize = size.getLargeFontSize() * 0.35;
    final labelFontSize = size.getSubtitleFontSize();
    final itemSpacing = size.getSmallSpacing() * 2;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 斜纹环形进度条 + 手绘图标
        SizedBox(
          width: containerSize,
          height: containerSize,
          child: CustomPaint(
            painter: _CircularProgressPainter(
              progress: data.progress * itemAnimation.value,
              color: data.color,
              theme: theme,
              thickness: ringThickness,
              scale: size.scale,
            ),
            child: Center(
              child: WiredIcon(
                icon: data.icon,
                size: iconSize * 0.8,
                color: data.color,
                drawConfig: theme.wired.drawConfig,
              ),
            ),
          ),
        ),
        SizedBox(width: itemSpacing),
        // 数值和标签
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: valueFontSize * 1.2,
              child: Text(
                data.value,
                style: TextStyle(
                  color: theme.text,
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ),
            SizedBox(height: size.getSmallSpacing()),
            SizedBox(
              height: labelFontSize * 1.2,
              child: Text(
                data.label,
                style: TextStyle(
                  color: theme.textSub,
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 斜纹环形进度绘制器
///
/// 淡墨轨道环（surfaceAlt 底 + 低透明度墨线斜纹 + 淡墨描边）垫底，
/// 数据色进度扇环（浅底 alpha 0.28 + 数据色浓斜纹 alpha 0.9 +
/// 数据色描边 alpha 0.85）自顶部顺时针扫入；颜色一律取 [theme] 语义色，
/// 进度色 [color] 为数据色 props。
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final AppThemeData theme;
  final double thickness;
  final double scale;

  const _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.theme,
    this.thickness = 4.0,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final rOut = size.shortestSide / 2 - 1;
    final rIn = math.max(0.0, rOut - thickness);

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

    // 进度扇环：数据色浅底 + 浓斜纹 + 数据色描边
    final s = progress.clamp(0.0, 1.0);
    if (s > 0.004) {
      final start = -math.pi / 2; // 从顶部开始
      final span = 2 * math.pi * s;
      final fullCircle = span >= 2 * math.pi - 0.01;
      final path = fullCircle
          ? _annulus(center, rIn, rOut)
          : _sector(center, rIn, rOut, start, start + span);
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.28));
      paintDiagonalStripes(
        canvas,
        path,
        Offset.zero & size,
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
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.theme != theme ||
        oldDelegate.thickness != thickness ||
        oldDelegate.scale != scale;
  }
}
