/// 签到项目卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 数据色图标徽章 + 打卡状态徽章（墨线描边）/ 周·月热力图（数据色格）。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 签到项目卡片小组件
///
/// 显示签到项目的名称、图标、今日打卡状态和热力图
class CheckinItemCardWidget extends StatelessWidget {
  final Map<String, dynamic> props;
  final HomeWidgetSize size;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  const CheckinItemCardWidget({
    super.key,
    required this.props,
    required this.size,
    this.inline = false,
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory CheckinItemCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return CheckinItemCardWidget(
      props: props,
      size: size,
      inline: props['inline'] as bool? ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = size.scale;

    // 从 props 获取数据
    final name = props['title'] as String? ??
                props['name'] as String? ??
                '签到项目';
    final group = props['subtitle'] as String? ??
                props['group'] as String?;
    final colorValue = props['color'] as int? ?? 0xFF007AFF;
    final iconCode = props['iconCodePoint'] as int? ??
                    props['icon'] as int? ??
                    Icons.checklist.codePoint;
    final isCheckedToday = props['isCheckedToday'] as bool? ?? false;

    final itemColor = Color(colorValue);
    final showHeatmap = size.isAtLeast(const MediumSize());

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: ConstrainedBox(
        constraints: size.getHeightConstraints(),
        child: DsSketchPanel(
          theme: theme,
          width: inline ? double.maxFinite : null,
          height: inline ? double.maxFinite : null,
          radius: BorderRadius.circular(24 * scale),
          padding: size.getPadding(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 习惯图标和标题
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 图标徽章：数据色浅底 + 墨线描边
                  Container(
                    width: size.getIconSize() * 1.6,
                    height: size.getIconSize() * 1.6,
                    decoration: dsSketchDecoration(
                      theme: theme,
                      radius: BorderRadius.circular(size.getIconSize() * 0.3),
                      fillColor: itemColor.withValues(alpha: 0.15),
                    ),
                    child: Center(
                      child: WiredIcon(
                        icon: dynamicIconData(
                          iconCode,
                          fontFamily: 'MaterialIcons',
                        ),
                        size: size.getIconSize(),
                        color: itemColor,
                        drawConfig: theme.wired.drawConfig,
                      ),
                    ),
                  ),
                  SizedBox(width: size.getItemSpacing() * 1.5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: theme.text,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (group != null)
                          Text(
                            group,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textSub,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // 右上角打卡状态徽章
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.getSmallSpacing() * 2,
                      vertical: size.getSmallSpacing(),
                    ),
                    decoration: dsSketchDecoration(
                      // 大圆角被 rough 引擎自动钳制成胶囊
                      theme: theme,
                      radius: BorderRadius.circular(999),
                      fillColor: (isCheckedToday
                              ? theme.success
                              : theme.textSub)
                          .withValues(alpha: 0.14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        WiredIcon(
                          icon: isCheckedToday
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: size.getLegendFontSize(),
                          color: isCheckedToday
                              ? theme.success
                              : theme.textSub,
                          drawConfig: theme.wired.drawConfig,
                        ),
                        SizedBox(width: size.getSmallSpacing()),
                        Text(
                          isCheckedToday ? '已打卡' : '未打卡',
                          style: TextStyle(
                            color: isCheckedToday
                                ? theme.success
                                : theme.textSub,
                            fontSize: size.getLegendFontSize() - 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // 热力图（根据卡片大小显示不同范围）
              if (showHeatmap) ...[
                SizedBox(height: size.getItemSpacing() * 1.5),
                _buildHeatmapGrid(theme, itemColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建热力图网格
  Widget _buildHeatmapGrid(AppThemeData theme, Color itemColor) {
    // 从 props 获取热力图数据
    final weekData = props['weekData'] as List<dynamic>?;
    final daysData = props['daysData'] as List<dynamic>?;

    // 根据尺寸决定使用哪个数据
    // large(2,2) 或更高尺寸：优先显示月数据
    if (size.isAtLeast(const LargeSize()) &&
        daysData != null &&
        daysData.isNotEmpty) {
      return _buildMonthHeatmap(
        theme,
        daysData.cast<Map<String, dynamic>>(),
        itemColor,
      );
    }
    // medium(2,1) 或更高尺寸：显示周数据
    else if (size.isAtLeast(const MediumSize()) &&
        weekData != null &&
        weekData.isNotEmpty) {
      return _buildWeekHeatmap(
        theme,
        weekData.cast<Map<String, dynamic>>(),
        itemColor,
      );
    }

    return const SizedBox.shrink();
  }

  /// 构建周热力图
  Widget _buildWeekHeatmap(
    AppThemeData theme,
    List<Map<String, dynamic>> weekData,
    Color itemColor,
  ) {
    const crossAxisCount = 7;
    const spacing = 4.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final totalWidthSpacing = (crossAxisCount - 1) * spacing;
        final cellSize = (maxWidth - totalWidthSpacing) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: weekData.map((data) {
            final isChecked = data['isChecked'] as bool? ?? false;
            return SizedBox(
              width: cellSize,
              height: cellSize,
              child: DecoratedBox(
                // 数据色格 + 墨线描边
                decoration: dsSketchDecoration(
                  theme: theme,
                  radius: BorderRadius.circular(cellSize / 3),
                  fillColor: isChecked
                      ? itemColor.withValues(alpha: 0.6)
                      : itemColor.withValues(alpha: 0.08),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// 构建月热力图
  Widget _buildMonthHeatmap(
    AppThemeData theme,
    List<Map<String, dynamic>> daysData,
    Color itemColor,
  ) {
    const crossAxisCount = 7;
    const spacing = 3.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final totalWidthSpacing = (crossAxisCount - 1) * spacing;
        final cellSize = (maxWidth - totalWidthSpacing) / crossAxisCount;

        final totalItems = daysData.length;
        final rows = (totalItems / crossAxisCount).ceil();

        final totalHeightSpacing = (rows - 1) * spacing;
        final totalHeight = rows * cellSize + totalHeightSpacing;

        return SizedBox(
          height: totalHeight,
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: daysData.map((data) {
              final day = data['day'] as int? ?? 0;
              final isChecked = data['isChecked'] as bool? ?? false;
              final isToday = data['isToday'] as bool? ?? false;

              // day == 0 表示占位符
              if (day == 0) {
                return SizedBox(width: cellSize, height: cellSize);
              }

              return SizedBox(
                width: cellSize,
                height: cellSize,
                child: DecoratedBox(
                  // 数据色格 + 墨线描边；今日格用数据色描边强调
                  decoration: dsSketchDecoration(
                    theme: theme,
                    radius: BorderRadius.circular(cellSize / 3),
                    fillColor: isChecked
                        ? itemColor.withValues(alpha: 0.6)
                        : itemColor.withValues(alpha: 0.08),
                    stroke: isToday ? itemColor : null,
                    strokeWidth: 1.5,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: cellSize * 0.35,
                        color: isToday ? theme.text : theme.textSub,
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
