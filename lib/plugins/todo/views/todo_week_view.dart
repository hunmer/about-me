import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/todo/models/task.dart';
import 'package:aboutme/plugins/todo/widgets/todo_day_card.dart';

/// 周视图 - 展示从周一到周日的待办事项（手绘纸墨风）
///
/// 周信息头与七张日卡均走手绘面板，挂载时经 [WiredDraw] 播墨线描画入场。
class TodoWeekView extends StatefulWidget {
  final List<Task> tasks;
  final Function(Task) onTaskTap;
  final Function(Task, TaskStatus) onTaskStatusChanged;
  final Function(DateTime)? onAddTask;

  const TodoWeekView({
    super.key,
    required this.tasks,
    required this.onTaskTap,
    required this.onTaskStatusChanged,
    this.onAddTask,
  });

  @override
  State<TodoWeekView> createState() => _TodoWeekViewState();
}

class _TodoWeekViewState extends State<TodoWeekView> {
  /// 相对本周的偏移周数，负数为过去周
  int _weekOffset = 0;

  @override
  Widget build(BuildContext context) {
    // 获取当前展示周的日期范围
    final weekDates = _getWeekDates(_weekOffset);
    // 按日期分组任务
    final tasksByDate = _groupTasksByDate(widget.tasks, weekDates);
    // 本周未完成任务总数
    final weekTaskCount = tasksByDate.values
        .fold(0, (sum, list) => sum + list.length);

    // 经 CustomBottomBar/TabBarView 挂载，自备主题桥保证 DS 组件可用
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          // Tab 切换挂载时墨线描画入场
          return WiredDraw(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                children: [
                  // 顶部周信息
                  _buildWeekHeader(context, taskCount: weekTaskCount),
                  const SizedBox(height: 8),
                  // 七天的卡片布局
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 0.8,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      padding: EdgeInsets.fromLTRB(
                        4,
                        4,
                        4,
                        4 + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: List.generate(7, (index) {
                        return _buildDayCard(
                          context,
                          dayIndex: index,
                          date: weekDates[index],
                          dayTasks: tasksByDate[index] ?? [],
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建周标题（大容器走手绘面板：纸底 + 淡排线 + 墨线框）
  Widget _buildWeekHeader(
    BuildContext context, {
    required int taskCount,
  }) {
    final theme = DSThemeBridge.resolve(context);

    return Padding(
      padding: const EdgeInsets.all(4),
      child: DsSketchPanel(
        theme: theme,
        radius: theme.radii.lg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            DsIcon(DsIconKind.calendar, size: 18, color: theme.primary),
            const SizedBox(width: 8),
            _buildWeekSwitcher(context, theme: theme),
            const SizedBox(width: 8),
            // 回到今天：切走本周后显示，一键返回
            if (_weekOffset != 0) ...[
              _buildBackToTodayButton(theme),
              const SizedBox(width: 8),
            ],
            // 任务数徽章：小控件走纯色实底 + 墨线描边
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: theme.primary.withValues(alpha: 0.12),
                stroke: theme.primary.withValues(alpha: 0.55),
                strokeWidth: 1.2,
                radius: theme.radii.pill,
              ),
              child: Text(
                'todo_weekTaskCount'.trParams({'count': '$taskCount'}),
                style: DsTypography.caption.copyWith(
                  fontSize: 10,
                  color: theme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 周切换器：左右箭头 + 日期范围，点击切换上/下周
  Widget _buildWeekSwitcher(
    BuildContext context, {
    required AppThemeData theme,
  }) {
    final start = _formatShortDate(_getWeekDates(_weekOffset).first);
    final end = _formatShortDate(_getWeekDates(_weekOffset).last);

    return Expanded(
      child: Row(
        children: [
          _buildArrowButton(
            theme,
            icon: DsIconKind.chevronLeft,
            onPressed: () => setState(() => _weekOffset--),
          ),
          Expanded(
            child: Text(
              'todo_weekDateRange'.trParams({'start': start, 'end': end}),
              style: DsTypography.label.copyWith(
                color: theme.text,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildArrowButton(
            theme,
            icon: DsIconKind.chevronRight,
            onPressed: () => setState(() => _weekOffset++),
          ),
        ],
      ),
    );
  }

  /// 「回到今天」按钮：小 chip 走纯色实底 + 墨线描边
  Widget _buildBackToTodayButton(AppThemeData theme) {
    return Pressable(
      onPressed: () => setState(() => _weekOffset = 0),
      semanticLabel: 'todo_backToToday'.tr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.primary.withValues(alpha: 0.12),
          stroke: theme.primary.withValues(alpha: 0.55),
          strokeWidth: 1.2,
          radius: theme.radii.pill,
        ),
        child: Text(
          'todo_backToToday'.tr,
          style: DsTypography.caption.copyWith(
            fontSize: 10,
            color: theme.primary,
          ),
        ),
      ),
    );
  }

  /// 箭头按钮：轻量可点击图标，按压变淡提示
  Widget _buildArrowButton(
    AppThemeData theme, {
    required DsIconKind icon,
    required VoidCallback onPressed,
  }) {
    return Pressable(
      onPressed: onPressed,
      semanticLabel: icon == DsIconKind.chevronLeft ? '上一周' : '下一周',
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: DsIcon(icon, size: 16, color: theme.primary),
      ),
    );
  }

  /// 本地化短日期（如 zh「10月6日」/ en「10/6」）
  String _formatShortDate(DateTime date) {
    return 'todo_monthDay'.trParams({
      'month': '${date.month}',
      'day': '${date.day}',
    });
  }

  /// 构建单日卡片
  Widget _buildDayCard(
    BuildContext context, {
    required int dayIndex,
    required DateTime date,
    required List<Task> dayTasks,
  }) {
    // 排除已完成的任务
    final activeTasks =
        dayTasks.where((t) => t.status != TaskStatus.done).toList();

    return TodoDayCard(
      date: date,
      tasks: activeTasks,
      onTaskTap: widget.onTaskTap,
      onTaskStatusChanged: widget.onTaskStatusChanged,
      onAddTask: widget.onAddTask,
    );
  }

  /// 获取指定周的日期列表（周一到周日），offset 为相对本周的偏移周数
  List<DateTime> _getWeekDates(int offset) {
    final now = DateTime.now();
    // 找到本周一
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final target =
        DateTime(monday.year, monday.month, monday.day + offset * 7);

    // 生成周一到周日的日期
    return List.generate(7, (index) {
      return target.add(Duration(days: index));
    });
  }

  /// 按日期分组任务
  Map<int, List<Task>> _groupTasksByDate(
    List<Task> allTasks,
    List<DateTime> weekDates,
  ) {
    final Map<int, List<Task>> grouped = {};

    for (int i = 0; i < 7; i++) {
      grouped[i] = [];
    }

    for (final task in allTasks) {
      if (task.status == TaskStatus.done) continue;

      // 检查任务的开始日期或截止日期是否在本周的某一天
      final taskDate = task.startDate ?? task.dueDate;
      if (taskDate == null) continue;

      for (int i = 0; i < 7; i++) {
        if (_isSameDay(taskDate, weekDates[i])) {
          grouped[i]!.add(task);
          break;
        }
      }
    }

    return grouped;
  }

  /// 判断两个日期是否是同一天
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
