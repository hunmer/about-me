import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/todo/models/task.dart';

/// 待办单日卡片 - 展示某一天的待办事项
///
/// 从周视图的单日卡片抽取的独立组件，
/// 同时供插件页（周视图）和主页待办日卡使用，保持 UI 一致。
class TodoDayCard extends StatelessWidget {
  /// 卡片对应的日期
  final DateTime date;

  /// 该日的未完成任务列表（由调用方按日期过滤）
  final List<Task> tasks;

  /// 点击任务回调（打开详情）
  final Function(Task) onTaskTap;

  /// 任务状态变化回调（勾选完成/取消完成）
  final Function(Task, TaskStatus) onTaskStatusChanged;

  /// 添加任务回调（预填该日日期），为 null 时不显示 ＋ 按钮
  final Function(DateTime)? onAddTask;

  const TodoDayCard({
    super.key,
    required this.date,
    required this.tasks,
    required this.onTaskTap,
    required this.onTaskStatusChanged,
    this.onAddTask,
  });

  static const List<String> _dayNames = [
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  @override
  Widget build(BuildContext context) {
    // 同时供插件页与主页日卡使用，自备主题桥保证 DS 组件可用
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final dayName = _dayNames[date.weekday - 1];
          final isToday = _isSameDay(date, DateTime.now());
          final isPast = date.isBefore(DateTime.now());

          // 根据任务状态设置卡片颜色（语义色令牌随明暗自适应）
          Color cardColor;

          if (tasks.isEmpty) {
            // 无任务
            cardColor = theme.textSub;
          } else if (isToday) {
            // 今天有任务
            cardColor = theme.primary;
          } else if (isPast) {
            // 过期未完成
            cardColor = theme.warning;
          } else {
            // 未来
            cardColor = theme.success;
          }

          final headerBgColor = cardColor.withValues(alpha: 0.1);
          final headerBorderColor = cardColor.withValues(alpha: 0.3);
          final titleColor = cardColor;

          return Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(8),
              border:
                  isToday
                      ? Border.all(color: headerBorderColor, width: 2)
                      : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 卡片标题
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: headerBgColor,
                    border: Border(
                      bottom: BorderSide(color: headerBorderColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dayName,
                              style: DsTypography.label.copyWith(
                                color: titleColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${date.month}/${date.day}',
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (tasks.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cardColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${tasks.length}',
                            style: DsTypography.caption.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (onAddTask != null)
                        DSIconButton(
                          icon: DsIconKind.plus,
                          size: 30,
                          color: theme.surfaceAlt,
                          iconColor: titleColor,
                          onPressed: () => onAddTask!(date),
                        ),
                    ],
                  ),
                ),
                // 任务列表
                Expanded(
                  child:
                      tasks.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                DsIcon(
                                  DsIconKind.check,
                                  size: 32,
                                  color: theme.success.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '无待办',
                                  style: DsTypography.caption.copyWith(
                                    color: theme.textSub.withValues(alpha: 0.4),
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
                            itemCount: tasks.length,
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              return InkWell(
                                onTap: () => onTaskTap(task),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      DSCheckbox(
                                        value: task.status == TaskStatus.done,
                                        onChanged: (val) {
                                          onTaskStatusChanged(
                                            task,
                                            val == true
                                                ? TaskStatus.done
                                                : TaskStatus.todo,
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          task.title,
                                          style: DsTypography.caption.copyWith(
                                            color: theme.text,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // 优先级指示器（模型持久化数据色）
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: task.priorityColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 判断两个日期是否是同一天
  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
