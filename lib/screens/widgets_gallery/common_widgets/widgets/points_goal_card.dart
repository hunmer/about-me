/// 积分目标进度公共小组件（手绘纸卡风格）
///
/// 显示今日积分与目标的进度
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘图标 + 标题行 / 斜纹高进度条（主题色斜纹数据段 + 淡墨轨道，
/// 文字内嵌条中）。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 积分目标进度小组件
class PointsGoalCardWidget extends StatefulWidget {
  /// 今日积分
  final int todayPoints;

  /// 目标积分
  final int goal;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const PointsGoalCardWidget({
    super.key,
    required this.todayPoints,
    required this.goal,
    required this.size,
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory PointsGoalCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return PointsGoalCardWidget(
      todayPoints: (props['todayPoints'] as num?)?.toInt() ?? 0,
      goal: (props['goal'] as num?)?.toInt() ?? 100,
      size: size,
    );
  }

  @override
  State<PointsGoalCardWidget> createState() => _PointsGoalCardWidgetState();
}

class _PointsGoalCardWidgetState extends State<PointsGoalCardWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final progress =
        widget.goal > 0 ? (widget.todayPoints / widget.goal).clamp(0.0, 1.0) : 0.0;
    final isCompleted = widget.todayPoints >= widget.goal;
    final barHeight = widget.size.isCardSized ? 56.0 : 48.0;
    final iconSize = widget.size.isCardSized ? 24.0 : 20.0;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(24 * widget.size.scale),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                WiredIcon(
                  icon: isCompleted ? Icons.emoji_events : Icons.flag,
                  size: iconSize,
                  color: theme.text,
                  drawConfig: theme.wired.drawConfig,
                ),
                const SizedBox(width: 8),
                Text(
                  '今日积分目标',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.text,
                  ),
                ),
                const Spacer(),
                if (isCompleted)
                  DsIcon(
                    DsIconKind.check,
                    color: theme.success,
                    size: iconSize,
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // 斜纹高进度条 + 文字内嵌显示（见 design.md §9.5）
            Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PointsBarPainter(
                      fill: progress,
                      barHeight: barHeight,
                      barColor: theme.primary,
                      theme: theme,
                      scale: widget.size.scale,
                    ),
                  ),
                ),
                SizedBox(
                  height: barHeight,
                  child: Center(
                    child: Text(
                      '${widget.todayPoints} / ${widget.goal}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 斜纹进度条绘制器（见 design.md §9.5）
///
/// 轨道：surfaceAlt 底 + 淡墨斜纹（0.28）+ 淡墨描边（0.45）；
/// 数据段：主题色浅底（0.28）+ 浓斜纹（0.9）+ 描边（0.85）。
class _PointsBarPainter extends CustomPainter {
  final double fill;
  final double barHeight;
  final Color barColor;
  final AppThemeData theme;
  final double scale;

  const _PointsBarPainter({
    required this.fill,
    required this.barHeight,
    required this.barColor,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final trackRect = Rect.fromLTWH(0, (size.height - barHeight) / 2,
        size.width, barHeight);
    final trackRRect = RRect.fromRectAndRadius(
      trackRect,
      Radius.circular(12 * scale),
    );

    // 轨道
    canvas.drawRRect(trackRRect, Paint()..color = theme.surfaceAlt);
    paintDiagonalStripes(
      canvas,
      Path()..addRRect(trackRRect),
      trackRect,
      color: theme.ink.withValues(alpha: 0.28),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRRect(
      trackRRect,
      Paint()
        ..color = theme.ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );

    // 数据段
    final f = fill.clamp(0.0, 1.0);
    if (f > 0.004) {
      final fillRect = Rect.fromLTWH(
        0,
        (size.height - barHeight) / 2,
        size.width * f,
        barHeight,
      );
      final fillRRect = RRect.fromRectAndRadius(
        fillRect,
        Radius.circular(12 * scale),
      );
      canvas.drawRRect(
        fillRRect,
        Paint()..color = barColor.withValues(alpha: 0.28),
      );
      paintDiagonalStripes(
        canvas,
        Path()..addRRect(fillRRect),
        fillRect,
        color: barColor.withValues(alpha: 0.9),
        strokeWidth: 3 * scale,
        spacing: 6.5 * scale,
      );
      canvas.drawRRect(
        fillRRect,
        Paint()
          ..color = barColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PointsBarPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.barHeight != barHeight ||
        oldDelegate.barColor != barColor ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}
