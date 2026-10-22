/// 习惯每日热力图卡片 - 公共小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘方形图标徽章 + 标题 / 数据色时长徽章 / 每日热力图格子
/// （习惯色档位透明度实底 + 淡墨格描边，不做斜纹），
/// 支持过去7天和当月两种视图模式。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 习惯热力图每日数据
class HabitHeatmapDailyData {
  final int day;
  final int minutes;

  const HabitHeatmapDailyData({required this.day, required this.minutes});

  /// 从 JSON 创建
  factory HabitHeatmapDailyData.fromJson(Map<String, dynamic> json) {
    return HabitHeatmapDailyData(
      day: json['day'] as int? ?? 0,
      minutes: json['minutes'] as int? ?? 0,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {'day': day, 'minutes': minutes};
  }
}

/// 习惯每日热力图卡片小组件
class HabitHeatmapCardWidget extends StatelessWidget {
  /// 习惯标题
  final String title;

  /// 分组名称（可选）
  final String? group;

  /// 图标代码（MaterialIcons codePoint 字符串）
  final String? iconCode;

  /// 习惯颜色
  final Color color;

  /// 总时长（分钟）
  final int totalMinutes;

  /// 每日数据列表
  final List<HabitHeatmapDailyData> dailyData;

  /// 视图模式：'week' 表示过去7天，'month' 表示当月
  final String viewMode;

  /// 点击回调
  final VoidCallback? onTap;

  const HabitHeatmapCardWidget({
    super.key,
    required this.title,
    this.group,
    this.iconCode,
    required this.color,
    required this.totalMinutes,
    required this.dailyData,
    this.viewMode = 'week',
    this.onTap,
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory HabitHeatmapCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final dailyDataList =
        (props['dailyData'] as List<dynamic>?)
            ?.map(
              (e) => HabitHeatmapDailyData.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        const [];

    return HabitHeatmapCardWidget(
      title: props['title'] as String? ?? '',
      group: props['group'] as String?,
      iconCode: props['iconCode'] as String?,
      color: Color(props['color'] as int? ?? 0xFFFFB300),
      totalMinutes: props['totalMinutes'] as int? ?? 0,
      dailyData: dailyDataList,
      viewMode: props['viewMode'] as String? ?? 'week',
      onTap: null, // props 中不包含回调
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final isMedium = viewMode == 'week';
    final showNumbers = !isMedium;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return GestureDetector(
      onTap: onTap,
      child: WiredDraw(
        child: DsSketchPanel(
          theme: theme,
          radius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 8),
              Expanded(child: _buildHeatmapGrid(theme, isMedium, showNumbers)),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建头部
  Widget _buildHeader(AppThemeData theme) {
    final icon =
        iconCode != null
            ? dynamicIconData(int.parse(iconCode!), fontFamily: 'MaterialIcons')
            : Icons.auto_awesome;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(8),
            fillColor: theme.surfaceAlt,
          ),
          child: Center(
            child: WiredIcon(
              icon: icon,
              size: 18,
              color: color,
              drawConfig: theme.wired.drawConfig,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (group != null)
                Text(
                  group!,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textSub,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        // 统计信息
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(6),
            fillColor: theme.surfaceAlt,
          ),
          child: Text(
            '$totalMinutes分钟',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建热力图网格：习惯色档位透明度实底 + 淡墨格描边（不做斜纹）
  Widget _buildHeatmapGrid(
    AppThemeData theme,
    bool isMedium,
    bool showNumbers,
  ) {
    final spacing = isMedium ? 4.0 : 3.0;
    final crossAxisCount = 7;

    // 计算最大分钟数
    final maxMinutes = dailyData
        .where((d) => d.minutes > 0)
        .fold<int>(0, (max, d) => d.minutes > max ? d.minutes : max);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;

        final totalWidthSpacing = (crossAxisCount - 1) * spacing;
        final cellWidth = (maxWidth - totalWidthSpacing) / crossAxisCount;

        final totalItems = dailyData.length;
        final rows = (totalItems / crossAxisCount).ceil();

        final totalHeightSpacing = (rows - 1) * spacing;
        final cellHeight = (maxHeight - totalHeightSpacing) / rows;

        final cellSize = cellWidth < cellHeight ? cellWidth : cellHeight;
        final fontSize = cellSize * 0.35;

        final totalHeight = rows * cellSize + (rows - 1) * spacing;

        return SizedBox(
          height: totalHeight.clamp(0.0, maxHeight),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            alignment: WrapAlignment.start,
            runAlignment: WrapAlignment.end,
            children:
                dailyData.map((item) {
                  // 根据时长计算档位透明度（数据色保留）
                  final double opacity;
                  if (maxMinutes > 0) {
                    opacity = 0.1 + (item.minutes / maxMinutes) * 0.7;
                  } else {
                    opacity = 0.1;
                  }

                  if (item.day == 0) {
                    return SizedBox(width: cellSize, height: cellSize);
                  }

                  final active = item.minutes > 0;
                  return SizedBox(
                    width: cellSize,
                    height: cellSize,
                    child: Container(
                      decoration: dsSketchDecoration(
                        theme: theme,
                        radius: BorderRadius.circular(cellSize / 3),
                        fillColor: color.withValues(
                          alpha: active ? opacity.clamp(0.2, 0.9) : 0.08,
                        ),
                        stroke: theme.ink.withValues(alpha: active ? 0.4 : 0.2),
                        strokeWidth: 1,
                      ),
                      child:
                          showNumbers
                              ? Center(
                                child: Text(
                                  '${item.day}',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    color: active ? theme.text : theme.textSub,
                                    fontWeight:
                                        active
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                  ),
                                ),
                              )
                              : null,
                    ),
                  );
                }).toList(),
          ),
        );
      },
    );
  }
}
