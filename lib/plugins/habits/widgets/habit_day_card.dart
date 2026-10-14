import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/widgets/day_card_header.dart';
import 'package:aboutme/plugins/habits/models/habit.dart';
import 'package:aboutme/plugins/habits/models/completion_record.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 习惯在某个日期的完成情况
class HabitDayStatus {
  final Habit habit;
  final List<CompletionRecord> records;

  const HabitDayStatus({required this.habit, required this.records});
}

/// 习惯单日卡片 - 展示某一天各习惯的完成情况
///
/// 供主页习惯日卡使用：习惯名/次数/时长，
/// 点击习惯进入习惯详情（与插件页一致）。
class HabitDayCard extends StatelessWidget {
  /// 卡片对应的日期
  final DateTime date;

  /// 各习惯当日完成情况（包含全部习惯，无记录的显示未完成）
  final List<HabitDayStatus> statuses;

  /// 点击习惯回调（进入习惯详情）
  final Function(Habit habit) onHabitTap;

  /// 头部主题色
  final Color color;

  const HabitDayCard({
    super.key,
    required this.date,
    required this.statuses,
    required this.onHabitTap,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final completed =
        statuses.where((status) => status.records.isNotEmpty).length;

    // 手绘墨线卡片容器(design.md §9),裁剪改外包 ClipRRect(参考 date_view_grid._buildCard)
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surface,
          radius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DayCardHeader(
              color: color,
              date: date,
              count: statuses.isEmpty ? null : completed,
              summary: statuses.isEmpty
                  ? null
                  : '$completed/${statuses.length}',
            ),
            Expanded(
              child: statuses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.self_improvement,
                            size: 32,
                            color: theme.textSub.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'habits_dayCardEmpty'.tr,
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      itemCount: statuses.length,
                      itemBuilder: (context, index) {
                        return _buildHabitItem(context, statuses[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 单条习惯行：图标 + 名称/完成情况 + 状态
  Widget _buildHabitItem(BuildContext context, HabitDayStatus status) {
    final theme = DSThemeBridge.resolve(context);
    final habit = status.habit;
    final done = status.records.isNotEmpty;

    return InkWell(
      onTap: () => onHabitTap(habit),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            _buildHabitIcon(context, habit, done),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: DsTypography.caption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: done ? theme.text : theme.textSub,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    done
                        ? '${status.records.length}次 · ${_formatDuration(status.totalMinutes)}'
                        : 'habits_dayCardNotDone'.tr,
                    style: DsTypography.caption.copyWith(
                      fontSize: 11,
                      color: theme.textSub,
                    ),
                  ),
                ],
              ),
            ),
            if (done)
              DsIcon(DsIconKind.check, size: 16, color: color)
            else
              Icon(
                Icons.radio_button_unchecked,
                size: 16,
                color: theme.textSub.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }

  /// 习惯图标（icon 为 codePoint 字符串）
  Widget _buildHabitIcon(BuildContext context, Habit habit, bool done) {
    final theme = DSThemeBridge.resolve(context);
    final codePoint = habit.icon == null ? null : int.tryParse(habit.icon!);
    if (codePoint == null) {
      return Icon(
        done ? Icons.check_circle_outline : Icons.circle_outlined,
        size: 18,
        color: done ? color : theme.textSub,
      );
    }
    return Icon(
      dynamicIconData(codePoint, fontFamily: 'MaterialIcons'),
      size: 18,
      color: done ? color : theme.textSub,
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes分钟';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours小时' : '$hours小时$rest分';
  }
}

extension on HabitDayStatus {
  /// 当日完成总时长（分钟）
  int get totalMinutes {
    return records.fold(0, (sum, record) => sum + record.duration.inMinutes);
  }
}
