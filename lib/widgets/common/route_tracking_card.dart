import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 路线点数据模型
class RoutePoint {
  /// 城市/地点名称
  final String city;

  /// 日期标签
  final String date;

  /// 是否已完成
  final bool isCompleted;

  const RoutePoint({
    required this.city,
    required this.date,
    required this.isCompleted,
  });

  /// 从 JSON 创建
  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      city: json['city'] as String? ?? '',
      date: json['date'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {'city': city, 'date': date, 'isCompleted': isCompleted};
  }
}

/// 路线状态追踪卡片小组件
///
/// 用于显示运输路线、行程追踪等场景，包含起点、终点和当前状态的卡片。
/// 手绘纸墨风（纸底 + 淡排线 + rough 墨线框，WiredDraw 墨线描画入场）：
/// 时间轴节点为 ink 平直小几何（刻度档，见 design.md §9.5），
/// 虚线路线 + 手绘飞机图标，颜色一律走 AppTheme 语义色。
class RouteTrackingCardWidget extends StatefulWidget {
  /// 日期标签（如 "Wed, 8 Aug"）
  final String date;

  /// 起点信息
  final RoutePoint origin;

  /// 终点信息
  final RoutePoint destination;

  /// 当前状态文本（如 "Shipped"、"In Transit"）
  final String status;

  /// 卡片宽度，默认 176
  final double width;

  /// 卡片高度，默认 176
  final double height;

  /// 圆角半径，默认 28
  final double borderRadius;

  /// 是否启用入场动画，默认 true
  final bool enableAnimation;

  /// 小组件尺寸，用于调整所有元素大小
  final HomeWidgetSize size;

  const RouteTrackingCardWidget({
    super.key,
    required this.date,
    required this.origin,
    required this.destination,
    required this.status,
    this.width = 176,
    this.height = 176,
    this.borderRadius = 28,
    this.enableAnimation = true,
    this.size = const MediumSize(),
  });

  @override
  State<RouteTrackingCardWidget> createState() =>
      _RouteTrackingCardWidgetState();
}

class _RouteTrackingCardWidgetState extends State<RouteTrackingCardWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final size = widget.size;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 墨线描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.width,
        height: widget.height,
        radius: BorderRadius.circular(24 * size.scale),
        padding: size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.date,
              style: TextStyle(
                fontSize: size.getSubtitleFontSize(),
                fontWeight: FontWeight.w500,
                color: theme.textSub,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: size.getSmallSpacing() * 2),
            Expanded(
              child: Row(
                children: [
                  _buildTimeline(theme, size),
                  SizedBox(width: size.getSmallSpacing() * 3),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPoint(
                          theme,
                          widget.origin.city,
                          widget.origin.date,
                          size,
                        ),
                        _buildStatus(theme, size),
                        _buildPoint(
                          theme,
                          widget.destination.city,
                          widget.destination.date,
                          size,
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

  /// 构建时间轴线
  ///
  /// 节点为平直 ink 小几何（空心起点 / 实心终点），路线为淡墨虚线。
  Widget _buildTimeline(AppThemeData theme, HomeWidgetSize size) {
    final iconSize = size.getIconSize();
    final dotSize = iconSize * 0.4; // 约 7.2/9.6/11.2
    final strokeWidth = size.getStrokeWidth() * 0.25; // 约 1.5/2/2.5

    return Column(
      children: [
        // 起点节点：空心墨圈
        SizedBox(
          width: dotSize,
          height: dotSize,
          child: CustomPaint(
            painter: _RouteDotPainter(
              filled: false,
              color: theme.ink.withValues(alpha: 0.7),
              strokeWidth: strokeWidth,
            ),
          ),
        ),
        Expanded(
          child: Container(
            width: 1,
            margin: EdgeInsets.symmetric(vertical: size.getSmallSpacing()),
            child: CustomPaint(
              painter: _DashedLinePainter(
                color: theme.ink.withValues(alpha: 0.45),
                strokeWidth: strokeWidth,
              ),
            ),
          ),
        ),
        // 终点节点：实心墨点
        SizedBox(
          width: dotSize,
          height: dotSize,
          child: CustomPaint(
            painter: _RouteDotPainter(
              filled: true,
              color: theme.ink,
              strokeWidth: strokeWidth,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建路线点信息
  Widget _buildPoint(
    AppThemeData theme,
    String city,
    String date,
    HomeWidgetSize size,
  ) {
    final cityFontSize = size.getTitleFontSize() * 0.6; // 约 9.6/14.4/16.8
    final dateFontSize = size.getLegendFontSize();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          city,
          style: TextStyle(
            fontSize: cityFontSize,
            fontWeight: FontWeight.w600,
            color: theme.text,
            height: 1.2,
          ),
        ),
        SizedBox(height: size.getSmallSpacing()),
        Text(
          date,
          style: TextStyle(fontSize: dateFontSize, color: theme.textSub),
        ),
      ],
    );
  }

  /// 构建状态显示
  Widget _buildStatus(AppThemeData theme, HomeWidgetSize size) {
    final statusFontSize = size.getSubtitleFontSize();
    final iconSize = size.getIconSize() * 0.6; // 约 10.8/14.4/16.8

    return Row(
      children: [
        Text(
          widget.status,
          style: TextStyle(
            fontSize: statusFontSize,
            fontWeight: FontWeight.w500,
            color: theme.text,
          ),
        ),
        SizedBox(width: size.getSmallSpacing() * 1.5),
        Transform.rotate(
          angle: 45 * 3.14159 / 180,
          child: WiredIcon(
            icon: Icons.flight,
            size: iconSize,
            color: theme.text,
            drawConfig: theme.wired.drawConfig,
          ),
        ),
      ],
    );
  }
}

/// 时间轴节点绘制器：ink 平直小圆（空心/实心，刻度档几何）
class _RouteDotPainter extends CustomPainter {
  final bool filled;
  final Color color;
  final double strokeWidth;

  const _RouteDotPainter({
    required this.filled,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;
    final paint =
        Paint()
          ..color = color
          ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RouteDotPainter oldDelegate) {
    return oldDelegate.filled != filled ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// 虚线绘制器
class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _DashedLinePainter({required this.color, this.strokeWidth = 2.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth;

    final dashWidth = strokeWidth * 2;
    final dashSpace = strokeWidth * 2;
    double startY = 0;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashWidth),
        paint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
