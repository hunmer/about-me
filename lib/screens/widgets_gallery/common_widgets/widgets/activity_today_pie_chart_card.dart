/// 今日活动统计饼状图小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题 / 斜纹甜甜圈图（按标签统计时长，主题语义色板）/
/// 图例列表（手绘色块指示器）/ 总时长。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 今日活动统计饼状图小组件
///
/// 使用饼状图展示今日活动统计，按标签统计时长
class ActivityTodayPieChartCardWidget extends StatefulWidget {
  /// 标签到时长的映射（标签名 -> 时长分钟数）
  final Map<String, int> tagStats;

  /// 总时长（分钟）
  final int totalDuration;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const ActivityTodayPieChartCardWidget({
    super.key,
    required this.tagStats,
    required this.totalDuration,
    this.size = const Large3Size(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory ActivityTodayPieChartCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    // 解析标签统计数据
    final tagStatsMap = <String, int>{};
    if (props['tagStats'] is Map<String, dynamic>) {
      final stats = props['tagStats'] as Map<String, dynamic>;
      stats.forEach((key, value) {
        tagStatsMap[key] = value as int? ?? 0;
      });
    }

    return ActivityTodayPieChartCardWidget(
      tagStats: tagStatsMap,
      totalDuration: props['totalDuration'] as int? ?? 0,
      size: size,
    );
  }

  @override
  State<ActivityTodayPieChartCardWidget> createState() =>
      _ActivityTodayPieChartCardWidgetState();
}

class _ActivityTodayPieChartCardWidgetState
    extends State<ActivityTodayPieChartCardWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: double.maxFinite,
        height: double.maxFinite,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: widget.tagStats.isEmpty
            ? _buildNoActivityWidget(theme)
            : _buildContent(theme),
      ),
    );
  }

  Widget _buildContent(AppThemeData theme) {
    // 按时长排序，只显示前5个
    final sortedEntries =
        widget.tagStats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(5).toList();

    // 计算总时长
    final totalDuration = topEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.value,
    );

    // 为每个标签分配颜色（主题语义色板）
    final colors = [
      theme.primary,
      theme.secondary,
      theme.success,
      theme.warning,
      theme.danger,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Text(
          '今日活动统计',
          style: TextStyle(
            fontSize: widget.size.getSubtitleFontSize() + 1,
            fontWeight: FontWeight.bold,
            color: theme.text,
          ),
        ),
        SizedBox(height: widget.size.getItemSpacing()),

        // 饼状图（在上方）
        Expanded(
          flex: 3,
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = math.min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return SizedBox(
                  width: side,
                  height: side,
                    child: CustomPaint(
                      painter: _StripedPiePainter(
                        entries: topEntries,
                        totalDuration: totalDuration > 0 ? totalDuration : 1,
                        colors: colors,
                        theme: theme,
                        scale: widget.size.scale,
                        legendFontSize: widget.size.getLegendFontSize(),
                      ),
                    ),
                );
              },
            ),
          ),
        ),

        SizedBox(height: widget.size.getItemSpacing()),

        // 图例（在下方）
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildLegendItems(theme, topEntries, colors, totalDuration),
            ),
          ),
        ),

        SizedBox(height: widget.size.getSmallSpacing()),

        // 总时长
        Text(
          '总时长: ${_formatDuration(totalDuration)}',
          style: TextStyle(
            fontSize: widget.size.getLegendFontSize(),
            color: theme.textSub,
          ),
        ),
      ],
    );
  }

  /// 构建无数据时的占位Widget
  Widget _buildNoActivityWidget(AppThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 标题
          Text(
            '今日活动统计',
            style: TextStyle(
              fontSize: widget.size.getSubtitleFontSize() + 1,
              fontWeight: FontWeight.bold,
              color: theme.text,
            ),
          ),
          SizedBox(height: widget.size.getTitleSpacing()),

          // 占位内容，保持2x3布局
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                WiredIcon(
                  icon: Icons.pie_chart,
                  color: theme.textSub,
                  size: 64,
                  drawConfig: theme.wired.drawConfig,
                ),
                const SizedBox(height: 16),
                Text(
                  '今日暂无活动',
                  style: TextStyle(
                    fontSize: widget.size.getSubtitleFontSize(),
                    color: theme.textSub,
                  ),
                ),
                SizedBox(height: widget.size.getItemSpacing()),
                Text(
                  '添加活动后查看统计',
                  style: TextStyle(
                    fontSize: widget.size.getLegendFontSize(),
                    color: theme.textSub,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: widget.size.getItemSpacing()),

          // 底部占位文字（只在总时长>0时显示）
          if (widget.totalDuration > 0)
            Text(
              '总时长: ${_formatDuration(widget.totalDuration)}',
              style: TextStyle(
                fontSize: widget.size.getLegendFontSize(),
                color: theme.textSub,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildLegendItems(
    AppThemeData theme,
    List<MapEntry<String, int>> entries,
    List<Color> colors,
    int totalDuration,
  ) {
    return List.generate(entries.length, (index) {
      final entry = entries[index];
      final tag = entry.key;
      final duration = entry.value;
      final percentage =
          totalDuration > 0 ? (duration / totalDuration * 100).toInt() : 0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            // 手绘色块指示器：数据色实底 + 墨线描边
            Container(
              width: 12,
              height: 12,
              decoration: dsSketchDecoration(
                theme: theme,
                radius: BorderRadius.circular(3),
                fillColor: colors[index % colors.length],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: theme.textSub,
              ),
            ),
          ],
        ),
      );
    });
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours > 0) {
      return '$hours小时$mins分钟';
    } else {
      return '$mins分钟';
    }
  }
}

/// 斜纹甜甜圈绘制器（平直几何 + 斜纹）
///
/// 按占比切分扇环（段间留小间隙）：每段铺数据色浅底 + 浓斜纹 +
/// 数据色描边，中心留孔显示纸底，段内标注百分比。
class _StripedPiePainter extends CustomPainter {
  final List<MapEntry<String, int>> entries;
  final int totalDuration;
  final List<Color> colors;
  final AppThemeData theme;
  final double scale;
  final double legendFontSize;

  const _StripedPiePainter({
    required this.entries,
    required this.totalDuration,
    required this.colors,
    required this.theme,
    required this.scale,
    required this.legendFontSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || entries.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final rOuter = size.width / 2;
    // 与原 fl_chart centerSpaceRadius 25 对应的中心孔
    final rInner = math.max(25.0, rOuter * 0.28);
    final bandOuter = rOuter - 4;
    final bandInner = rInner;
    final bounds = Offset.zero & size;
    final gapAngle = 2 * math.pi * 0.008;

    var cursor = -math.pi / 2;
    for (int i = 0; i < entries.length; i++) {
      final value = entries[i].value;
      final sweepAngle =
          totalDuration > 0 ? 2 * math.pi * (value / totalDuration) : 0.0;
      final segSweep = sweepAngle - gapAngle;
      if (segSweep > 0.01) {
        final path = _sector(
          center,
          bandInner,
          bandOuter,
          cursor,
          cursor + segSweep,
        );
        final color = colors[i % colors.length];
        canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.28));
        paintDiagonalStripes(
          canvas,
          path,
          bounds,
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

        // 段内百分比标注
        final percentage =
            totalDuration > 0 ? (value / totalDuration * 100).toInt() : 0;
        final labelRadius = (bandInner + bandOuter) / 2;
        final midAngle = cursor + sweepAngle / 2;
        final tp = TextPainter(
          text: TextSpan(
            text: '$percentage%',
            style: TextStyle(
              fontSize: legendFontSize,
              fontWeight: FontWeight.bold,
              color: theme.text,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          center +
              Offset(
                labelRadius * math.cos(midAngle),
                labelRadius * math.sin(midAngle),
              ) -
              Offset(tp.width / 2, tp.height / 2),
        );
      }
      cursor += sweepAngle;
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
  bool shouldRepaint(covariant _StripedPiePainter oldDelegate) {
    return oldDelegate.entries.length != entries.length ||
        oldDelegate.totalDuration != totalDuration ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale ||
        oldDelegate.legendFontSize != legendFontSize;
  }
}
