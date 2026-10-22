/// 活动热力图小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题 + 手绘箭头 / 24 小时热力图格子（标签档位色实底 + 淡墨格描边，
/// 细粒度模式逐格错峰描画，不做斜纹）/ 手绘色块图例 / 统计信息。
/// 支持不同时间粒度（5/10/15/30/60分钟），颜色深浅表示活动密集程度。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 活动热力图小组件
class ActivityHeatmapCardWidget extends StatefulWidget {
  /// 时间粒度（分钟）：5, 10, 15, 30, 60
  final int timeGranularity;

  /// 热力图数据列表
  final List<TimeSlotData> timeSlots;

  /// 总时长（分钟）
  final int totalMinutes;

  /// 活跃小时数
  final int activeHours;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const ActivityHeatmapCardWidget({
    super.key,
    required this.timeGranularity,
    required this.timeSlots,
    required this.totalMinutes,
    required this.activeHours,
    this.size = const Large3Size(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory ActivityHeatmapCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final timeGranularity = props['timeGranularity'] as int? ?? 60;

    // 解析时间槽数据
    final timeSlotsList =
        (props['timeSlots'] as List<dynamic>?)
            ?.map((e) => TimeSlotData.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ActivityHeatmapCardWidget(
      timeGranularity: timeGranularity,
      timeSlots: timeSlotsList,
      totalMinutes: props['totalMinutes'] as int? ?? 0,
      activeHours: props['activeHours'] as int? ?? 0,
      size: size,
    );
  }

  @override
  State<ActivityHeatmapCardWidget> createState() =>
      _ActivityHeatmapCardWidgetState();
}

class _ActivityHeatmapCardWidgetState extends State<ActivityHeatmapCardWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(24 * widget.size.scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '今日活动热力图',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.text,
                    fontSize: widget.size.getSubtitleFontSize(),
                  ),
                ),
                DsIcon(
                  DsIconKind.chevronRight,
                  size: 18,
                  color: theme.primary.withValues(alpha: 0.6),
                ),
              ],
            ),
            SizedBox(height: widget.size.getTitleSpacing()),

            // 24小时热力图网格
            Expanded(child: _buildHeatmap(theme)),

            SizedBox(height: widget.size.getItemSpacing()),

            // 图例
            _buildLegend(theme),

            SizedBox(height: widget.size.getSmallSpacing()),

            // 统计信息
            _buildStats(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmap(AppThemeData theme) {
    final granularity = widget.timeGranularity;

    switch (granularity) {
      case 5:
        return _buildGranularHeatmap(theme, 5);
      case 10:
        return _buildGranularHeatmap(theme, 10);
      case 15:
        return _buildGranularHeatmap(theme, 15);
      case 30:
        return _buildGranularHeatmap(theme, 30);
      case 60:
      default:
        return _build60MinHeatmap(theme);
    }
  }

  // 通用的细粒度热力图（5/10/15/30分钟）：单 painter 逐格错峰描画
  Widget _buildGranularHeatmap(AppThemeData theme, int granularity) {
    final columns = 12;
    final rows = (widget.timeSlots.length / columns).ceil();

    // 确保至少有1行
    final actualRows = rows > 0 ? rows : 1;

    // 预计算每格档位色（null = 无数据格，不画）
    final cellColors = List<Color?>.generate(actualRows * columns, (index) {
      if (index >= widget.timeSlots.length) return null;
      final data = widget.timeSlots[index];
      return _getSlotColor(
        theme,
        data.durationMinutes,
        granularity,
        data.tagDurations,
      );
    });
    final cellActive = List<bool>.generate(actualRows * columns, (index) {
      return index < widget.timeSlots.length &&
          widget.timeSlots[index].durationMinutes > 0;
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth / columns;
        final ch = constraints.maxHeight / math.max(actualRows, 1);
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: CustomPaint(
            painter: _GranularHeatmapPainter(
              cells: cellColors,
              active: cellActive,
              columns: columns,
              cellWidth: cw,
              cellHeight: ch,
              theme: theme,
              // 外层无 WiredDraw（或动画被禁用）时为 null = 全部直接画完
              progress: WiredDrawTransition.progressOf(context),
            ),
          ),
        );
      },
    );
  }

  // 60分钟粒度（24小时，4行6列）- 显示文本
  Widget _build60MinHeatmap(AppThemeData theme) {
    return Column(
      children: List.generate(4, (row) {
        return Expanded(
          child: Row(
            children: List.generate(6, (col) {
              final index = row * 6 + col;
              final data =
                  index < widget.timeSlots.length
                      ? widget.timeSlots[index]
                      : TimeSlotData(hour: col + row * 6, minute: 0, durationMinutes: 0);
              return Expanded(
                child: _buildHeatmapCell(
                  theme,
                  hour: data.hour,
                  durationMinutes: data.durationMinutes,
                  label: '${data.hour}',
                  showLabel: true,
                  tagDurations: data.tagDurations,
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildHeatmapCell(
    AppThemeData theme, {
    required int hour,
    required int durationMinutes,
    required String label,
    bool showLabel = true,
    Map<String, int> tagDurations = const {},
  }) {
    final color = _getSlotColor(
      theme,
      durationMinutes,
      widget.timeGranularity,
      tagDurations,
    );
    final isActive = durationMinutes > 0;

    return Container(
      margin: const EdgeInsets.all(1),
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(4),
        fillColor: color,
        stroke: theme.ink.withValues(alpha: isActive ? 0.4 : 0.2),
        strokeWidth: 1,
      ),
      child:
          showLabel
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: widget.size.getLegendFontSize(),
                    fontWeight: FontWeight.w500,
                    color: _getTextColor(theme, color),
                  ),
                ),
                if (isActive) ...[
                  SizedBox(height: widget.size.getSmallSpacing()),
                  Text(
                    _formatMinutes(durationMinutes),
                    style: TextStyle(
                      fontSize: widget.size.getLegendFontSize() - 2,
                      color: _getTextColor(theme, color),
                    ),
                  ),
                ],
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  Color _getSlotColor(
    AppThemeData theme,
    int minutes,
    int granularity,
    Map<String, int> tagDurations,
  ) {
    if (minutes == 0) {
      return theme.surfaceAlt;
    }

    // 如果有标签，使用主要标签的颜色（数据色：由标签名派生，保留）
    if (tagDurations.isNotEmpty) {
      final primaryTag = tagDurations.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      final tagColor = _getColorFromTag(primaryTag);

      // 根据占时间槽的比例来调整颜色的透明度
      final ratio = minutes / granularity;
      final alpha = _getAlphaFromRatio(ratio);

      return tagColor.withValues(alpha: alpha);
    }

    // 没有标签时，使用主题色（档位透明度）
    final ratio = minutes / granularity;
    final alpha = _getAlphaFromRatio(ratio);
    return theme.primary.withValues(alpha: alpha);
  }

  double _getAlphaFromRatio(double ratio) {
    if (ratio < 0.25) {
      return 0.3;
    } else if (ratio < 0.5) {
      return 0.5;
    } else if (ratio < 0.75) {
      return 0.7;
    } else {
      return 1.0;
    }
  }

  Color _getTextColor(AppThemeData theme, Color background) {
    if (background == theme.surfaceAlt) {
      return theme.textSub;
    }
    return background.computeLuminance() > 0.5 ? theme.text : theme.surface;
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return mins > 0 ? '${hours}h${mins}m' : '${hours}h';
    }
  }

  Widget _buildLegend(AppThemeData theme) {
    // 收集所有标签
    final allTags = <String>{};
    for (final slot in widget.timeSlots) {
      allTags.addAll(slot.tagDurations.keys);
    }

    // 统计标签使用情况
    final tagStats = <String, int>{};
    for (final slot in widget.timeSlots) {
      for (final entry in slot.tagDurations.entries) {
        tagStats[entry.key] = (tagStats[entry.key] ?? 0) + entry.value;
      }
    }

    // 取前3个标签
    final topTags = tagStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final displayTags = topTags.take(3).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children:
          displayTags.map((entry) {
            final color = _getColorFromTag(entry.key);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 手绘色块指示器：数据色实底 + 墨线描边
                Container(
                  width: 8,
                  height: 8,
                  decoration: dsSketchDecoration(
                    theme: theme,
                    radius: BorderRadius.circular(2),
                    fillColor: color,
                    strokeWidth: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: widget.size.getLegendFontSize(),
                    color: theme.textSub,
                  ),
                ),
              ],
            );
          }).toList(),
    );
  }

  Color _getColorFromTag(String tag) {
    final baseHue = (tag.hashCode % 360).abs().toDouble();
    return HSLColor.fromAHSL(1.0, baseHue, 0.6, 0.5).toColor();
  }

  Widget _buildStats(AppThemeData theme) {
    if (widget.timeSlots.isEmpty) {
      return Text(
        '今日暂无活动',
        style: TextStyle(
          fontSize: widget.size.getLegendFontSize(),
          color: theme.textSub,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '总时长: ${_formatMinutes(widget.totalMinutes)}',
          style: TextStyle(
            fontSize: widget.size.getLegendFontSize(),
            color: theme.textSub,
          ),
        ),
        Text(
          '活跃: ${widget.activeHours}小时',
          style: TextStyle(
            fontSize: widget.size.getLegendFontSize(),
            color: theme.textSub,
          ),
        ),
      ],
    );
  }
}

/// 细粒度热力图绘制器：rough 墨线格，逐格错峰描画（消费外层 WiredDraw 进度）
///
/// 每格档位色实底 + 淡墨描边（热力图格子不做斜纹）；
/// cells 中 null 表示无数据格（不画）。
class _GranularHeatmapPainter extends CustomPainter {
  final List<Color?> cells;
  final List<bool> active;
  final int columns;
  final double cellWidth;
  final double cellHeight;
  final AppThemeData theme;
  final Animation<double>? progress;

  _GranularHeatmapPainter({
    required this.cells,
    required this.active,
    required this.columns,
    required this.cellWidth,
    required this.cellHeight,
    required this.theme,
    required this.progress,
  }) : super(repaint: progress);

  /// 每格 rough 绘图缓存（painter 随尺寸变化重建，动画帧间复用）
  late final List<RoughDrawing?> _drawings = _buildDrawings();

  List<RoughDrawing?> _buildDrawings() {
    final cw = cellWidth;
    final ch = cellHeight;
    final inset = math.min(1.0, math.min(cw, ch) * 0.08);

    final config = theme.wired.drawConfig;
    config.randomizer.reset();
    final solidGen = Generator(config, SolidFiller());

    Paint stroke(double width, Color color) =>
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = width
          ..color = color;

    return List.generate(cells.length, (i) {
      final color = cells[i];
      if (color == null) return null;
      final r = i ~/ columns;
      final c = i % columns;
      final x = c * cw + inset;
      final y = r * ch + inset;
      final w = cw - inset * 2;
      final h = ch - inset * 2;
      final radius = math.min(2.0, math.min(w, h) * 0.12);

      final borderPaint = stroke(
        1,
        theme.ink.withValues(alpha: active[i] ? 0.45 : 0.22),
      );
      final fillPaint = stroke(1, color);
      return RoughDrawing(
        solidGen.roundedRectangle(x, y, w, h, radius, radius, radius, radius),
        borderPaint,
        fillPaint,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || cells.isEmpty) return;

    final total = cells.length;
    final p = progress?.value ?? 1;
    for (var i = 0; i < total; i++) {
      final drawing = _drawings[i];
      if (drawing == null) continue;
      // 依次错峰描画：前半段总进度用于铺开全部格子的起点
      final start = 0.5 * (i / total);
      final local = ((p - start) / 0.5).clamp(0.0, 1.0);
      if (local <= 0) continue;
      drawing.paint(canvas, progress: local, pressure: 0);
    }
  }

  @override
  bool shouldRepaint(covariant _GranularHeatmapPainter oldDelegate) {
    return oldDelegate.cells != cells ||
        oldDelegate.active != active ||
        oldDelegate.columns != columns ||
        oldDelegate.cellWidth != cellWidth ||
        oldDelegate.cellHeight != cellHeight ||
        oldDelegate.theme != theme;
  }
}

/// 时间槽数据
class TimeSlotData {
  final int hour;
  final int minute;
  final int durationMinutes;

  /// 标签到时长的映射（用于确定主要标签颜色）
  final Map<String, int> tagDurations;

  TimeSlotData({
    required this.hour,
    required this.minute,
    required this.durationMinutes,
    this.tagDurations = const {},
  });

  /// 从 Map 创建实例
  factory TimeSlotData.fromMap(Map<String, dynamic> map) {
    return TimeSlotData(
      hour: map['hour'] as int? ?? 0,
      minute: map['minute'] as int? ?? 0,
      durationMinutes: map['durationMinutes'] as int? ?? 0,
      tagDurations: (map['tagDurations'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          const {},
    );
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'hour': hour,
      'minute': minute,
      'durationMinutes': durationMinutes,
      'tagDurations': tagDurations,
    };
  }

  /// 获取持续时间最长的标签
  String? get primaryTag {
    if (tagDurations.isEmpty) return null;
    return tagDurations.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}
