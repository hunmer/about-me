/// 七日周报小组件 - 公共组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题 + 七天便签卡（今日 = 数据色浅底徽章 + 数据色描边，
/// 其余 surfaceAlt 底；星期 / 日期数字 / 心情 emoji / 标题）。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:intl/intl.dart';

/// 七日周报小组件
///
/// 显示本周七天日记的概览，包括日期、心情和标题
class WeeklyDiaryWidget extends StatelessWidget {
  /// 组件标题
  final String title;

  /// 是否显示标题
  final bool showTitle;

  /// 主色调
  final int? primaryColorValue;

  /// 七天卡片数据列表
  final List<dynamic>? daysData;

  const WeeklyDiaryWidget({
    super.key,
    this.title = '本周日记',
    this.showTitle = true,
    this.primaryColorValue,
    this.daysData,
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory WeeklyDiaryWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return WeeklyDiaryWidget(
      title: props['title'] as String? ?? '本周日记',
      showTitle: props['showTitle'] as bool? ?? true,
      primaryColorValue: props['primaryColor'] as int?,
      daysData: props['daysData'] as List<dynamic>?,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // 主色调（数据色 props，缺省回落主题色）
    final primaryColor = primaryColorValue != null
        ? Color(primaryColorValue!)
        : theme.primary;

    final days = daysData ?? _getDefaultDaysData();

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle) ...[
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 16),
            ],
            // 七天卡片
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: days.map((dayData) {
                  return _buildDayCard(context, theme, dayData, primaryColor);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建周报中的单日卡片组件
  Widget _buildDayCard(
    BuildContext context,
    AppThemeData theme,
    dynamic dayData,
    Color primaryColor,
  ) {
    final isToday = dayData['isToday'] as bool? ?? false;
    final weekday = dayData['weekday'] as String? ?? '';
    final dayNumber = dayData['dayNumber'] as String? ?? '';
    final mood = dayData['mood'] as String?;
    final title = dayData['title'] as String? ?? '';
    final hasEntry = dayData['hasEntry'] as bool? ?? false;
    final dateStr = dayData['date'] as String? ?? '';

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        // 今日 = 数据色浅底徽章 + 数据色描边；其余次级纸底
        decoration: dsSketchDecoration(
          theme: theme,
          radius: BorderRadius.circular(8),
          fillColor: isToday
              ? primaryColor.withValues(alpha: 0.28)
              : theme.surfaceAlt,
          stroke: isToday ? primaryColor : null,
        ),
        child: InkWell(
          onTap: () => _openDiaryEditor(context, dateStr),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 星期几
                Text(
                  weekday,
                  style: TextStyle(
                    fontSize: 11,
                    color: isToday ? primaryColor : theme.textSub,
                    fontWeight:
                        isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                // 日期数字
                Text(
                  dayNumber,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isToday ? primaryColor : theme.text,
                  ),
                ),
                const SizedBox(height: 4),
                // 心情
                if (mood != null)
                  Text(mood, style: const TextStyle(fontSize: 18))
                else
                  const SizedBox(height: 18),
                // 标题（如果有）
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: hasEntry ? theme.text : theme.textSub,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 打开日记编辑器
  Future<void> _openDiaryEditor(BuildContext context, String dateStr) async {
    if (dateStr.isEmpty) return;

    try {
      final date = DateTime.parse(dateStr);

      // 使用路由导航到日记编辑器
      Navigator.of(context).pushNamed(
        '/diary/editor',
        arguments: {
          'date': date.toIso8601String(),
          // 注意：标题和内容由日记编辑器从存储加载
        },
      );
    } catch (e) {
      debugPrint('[WeeklyDiaryWidget] 打开日记编辑器失败: $e');
    }
  }

  /// 获取默认的七天数据（用于预览）
  List<dynamic> _getDefaultDaysData() {
    final now = DateTime.now();
    // Monday = 1, Sunday = 7
    final weekday = now.weekday;
    // 计算周一
    final monday = now.subtract(Duration(days: weekday - 1));
    // 生成周一到周日的日期列表
    return List.generate(7, (index) {
      final date = monday.add(Duration(days: index));
      return {
        'date': date.toIso8601String(),
        'isToday': DateUtils.isSameDay(date, now),
        'weekday': DateFormat('E').format(date),
        'dayNumber': DateFormat('d').format(date),
        'mood': null,
        'title': null,
        'hasEntry': false,
      };
    });
  }
}
