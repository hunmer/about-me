import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cutout_stat_grid_card.dart';
import 'package:aboutme/plugins/todo/models/task.dart';

/// 待办单日卡片 - 展示某一天的待办事项（手绘纸墨风）
///
/// 从周视图的单日卡片抽取的独立组件，
/// 同时供插件页（周视图）和主页待办日卡使用，保持 UI 一致。
/// 容器走切角纸卡（[CutoutStatGridCardWidget]），头部按任务状态
/// 取语义色，徽章等小控件走 [dsSketchDecoration]（纯色实底 + 墨线描边）。
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

  static const List<String> _dayNameKeys = [
    'todo_monday',
    'todo_tuesday',
    'todo_wednesday',
    'todo_thursday',
    'todo_friday',
    'todo_saturday',
    'todo_sunday',
  ];

  @override
  Widget build(BuildContext context) {
    // 同时供插件页与主页日卡使用，自备主题桥保证 DS 组件可用
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final dayName = _dayNameKeys[date.weekday - 1].tr;
          final now = DateTime.now();
          final isToday = _isSameDay(date, now);
          final isPast = date.isBefore(now);

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

          // 切角纸卡容器：整卡状态色实底 + 左上切角徽章（cutout 设计）
          return CutoutStatGridCardWidget(
            inline: true,
            accentColor: cardColor,
            icon: Icons.event_available,
            header: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                dayName,
                                overflow: TextOverflow.ellipsis,
                                style: DsTypography.label.copyWith(
                                  color: theme.text,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 4),
                              _buildTodayBadge(context),
                            ],
                          ],
                        ),
                        Text(
                          _formatShortDate(date),
                          style: DsTypography.caption.copyWith(
                            color: theme.text.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (tasks.isNotEmpty)
                    _buildCountBadge(
                      context,
                      count: tasks.length,
                      color: cardColor,
                    ),
                  if (onAddTask != null)
                    DSIconButton(
                      icon: DsIconKind.plus,
                      size: 30,
                      color: theme.surfaceAlt,
                      iconColor: cardColor,
                      onPressed: () => onAddTask!(date),
                    ),
                ],
            ),
            // 任务列表
            child:
                tasks.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DsIcon(
                            DsIconKind.check,
                            size: 24,
                            color: theme.success.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'todo_dayNoTasks'.tr,
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return _buildTaskItem(context, task: task);
                      },
                    ),
          );
        },
      ),
    );
  }

  /// 今日徽章：小控件走纯色实底 + 墨线描边
  Widget _buildTodayBadge(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.primary,
        stroke: theme.onPrimary.withValues(alpha: 0.6),
        strokeWidth: 1.0,
        radius: theme.radii.pill,
      ),
      child: Text(
        'todo_today'.tr,
        style: DsTypography.caption.copyWith(
          fontSize: 9,
          color: theme.onPrimary,
        ),
      ),
    );
  }

  /// 任务数徽章（切角色块上：卡底色胶囊 + 状态色文字）
  Widget _buildCountBadge(
    BuildContext context, {
    required int count,
    required Color color,
  }) {
    final theme = DSThemeBridge.resolve(context);

    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surface,
        radius: theme.radii.pill,
      ),
      child: Text(
        '$count',
        style: DsTypography.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  /// 任务行：勾选框 + 标题 + 优先级墨点
  Widget _buildTaskItem(BuildContext context, {required Task task}) {
    final theme = DSThemeBridge.resolve(context);

    return Pressable(
      onPressed: () => onTaskTap(task),
      builder:
          (context, states) => Opacity(
            opacity: states.contains(WidgetState.pressed) ? 0.7 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  DSCheckbox(
                    value: task.status == TaskStatus.done,
                    onChanged: (val) {
                      onTaskStatusChanged(
                        task,
                        val == true ? TaskStatus.done : TaskStatus.todo,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.title,
                      style: DsTypography.caption.copyWith(color: theme.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 优先级指示器（模型持久化数据色，手绘小墨点）
                  Container(
                    width: 8,
                    height: 8,
                    decoration: dsSketchDecoration(
                      theme: theme,
                      circle: true,
                      fillColor: task.priorityColor,
                      strokeWidth: 1.0,
                      seed: task.title.length,
                    ),
                  ),
                ],
              ),
            ),
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

  /// 判断两个日期是否是同一天
  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
