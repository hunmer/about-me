import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/todo/models/models.dart';
import 'package:aboutme/plugins/todo/models/task.dart';

class TodoFourQuadrantView extends StatelessWidget {
  final List<Task> tasks;
  final Function(Task) onTaskTap;
  final Function(Task, TaskStatus) onTaskStatusChanged;
  final Function(TaskPriority)? onAddTask;

  const TodoFourQuadrantView({
    super.key,
    required this.tasks,
    required this.onTaskTap,
    required this.onTaskStatusChanged,
    this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    // Categorize tasks
    final q1 = <Task>[]; // Urgent & Important
    final q2 = <Task>[]; // Important & Not Urgent
    final q3 = <Task>[]; // Urgent & Not Important
    final q4 = <Task>[]; // Not Urgent & Not Important

    for (final task in tasks) {
      if (task.status == TaskStatus.done) continue;

      // 根据优先级直接分类到对应象限
      if (task.priority == TaskPriority.q1) {
        q1.add(task);
      } else if (task.priority == TaskPriority.q2) {
        q2.add(task);
      } else if (task.priority == TaskPriority.q3) {
        q3.add(task);
      } else {
        q4.add(task);
      }
    }

    return DSThemeBridge(
      // 经 CustomBottomBar/TabBarView 挂载，自备主题桥保证 DS 组件可用
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildQuadrant(
                          context,
                          title: '紧急且重要', // Urgent & Important
                          color: theme.danger,
                          tasks: q1,
                          priority: TaskPriority.q1,
                        ),
                      ),
                      Expanded(
                        child: _buildQuadrant(
                          context,
                          title: '重要但不紧急', // Important & Not Urgent
                          color: theme.success,
                          tasks: q2,
                          priority: TaskPriority.q2,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildQuadrant(
                          context,
                          title: '紧急但不重要', // Urgent & Not Important
                          color: theme.warning,
                          tasks: q3,
                          emptyIcon: Icons.inbox,
                          priority: TaskPriority.q3,
                        ),
                      ),
                      Expanded(
                        child: _buildQuadrant(
                          context,
                          title: '不紧急不重要', // Not Urgent & Not Important
                          color: theme.primary,
                          tasks: q4,
                          emptyIcon: Icons.archive,
                          priority: TaskPriority.q4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuadrant(
    BuildContext context, {
    required String title,
    required Color color,
    required List<Task> tasks,
    IconData? emptyIcon,
    TaskPriority? priority,
  }) {
    final theme = DSThemeBridge.resolve(context);

    // Colors derived from tailwind logic in HTML
    // header bg: color/10
    // header border: color/30
    // text: 象限语义色（令牌已随明暗自适应）

    final headerBgColor = color.withValues(alpha: 0.1);
    final headerBorderColor = color.withValues(alpha: 0.3);
    final titleColor = color;

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerBgColor,
              border: Border(bottom: BorderSide(color: headerBorderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: DsTypography.label.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onAddTask != null && priority != null)
                  DSIconButton(
                    icon: DsIconKind.plus,
                    size: 30,
                    color: theme.surfaceAlt,
                    iconColor: titleColor,
                    onPressed: () => onAddTask!(priority),
                  ),
              ],
            ),
          ),
          // List
          Expanded(
            child:
                tasks.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (emptyIcon != null)
                            // inbox/archive 无自绘图标等价物，保留 Material 图标
                            Icon(
                              emptyIcon,
                              size: 40,
                              color: theme.textSub.withValues(alpha: 0.2),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            '无待办事项',
                            style: DsTypography.label.copyWith(
                              color: theme.textSub.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return InkWell(
                          onTap: () => onTaskTap(task),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
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
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 任务标题
                                      Text(
                                        task.title,
                                        style: DsTypography.body.copyWith(
                                          color: theme.text,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      // 标签和子任务信息
                                      if (task.tags.isNotEmpty ||
                                          task.subtasks.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              // 标签显示
                                              if (task.tags.isNotEmpty) ...[
                                                ...task.tags
                                                    .take(2)
                                                    .map(
                                                      (tag) => Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              right: 4,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: theme.primary
                                                              .withValues(
                                                                alpha: 0.1,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                          border: Border.all(
                                                            color: theme.primary
                                                                .withValues(
                                                                  alpha: 0.3,
                                                                ),
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          tag,
                                                          style: DsTypography
                                                              .caption
                                                              .copyWith(
                                                                fontSize: 10,
                                                                color:
                                                                    theme
                                                                        .primary,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                if (task.tags.length > 2)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: theme.primary
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '+${task.tags.length - 2}',
                                                      style: DsTypography
                                                          .caption
                                                          .copyWith(
                                                            fontSize: 10,
                                                            color:
                                                                theme.primary,
                                                          ),
                                                    ),
                                                  ),
                                              ],
                                              // 子任务数量
                                              if (task.subtasks.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: theme.surfaceAlt,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      // 空心复选框无自绘图标等价物，保留 Material 图标
                                                      Icon(
                                                        Icons
                                                            .check_box_outline_blank,
                                                        size: 10,
                                                        color: theme.textSub,
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        '${task.subtasks.where((s) => s.isCompleted).length}/${task.subtasks.length}',
                                                        style: DsTypography
                                                            .caption
                                                            .copyWith(
                                                              fontSize: 10,
                                                              color:
                                                                  theme.textSub,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // 计时器显示区域（右上角）
                                GestureDetector(
                                  onTap: () {
                                    if (task.status == TaskStatus.inProgress) {
                                      // 进行中任务点击直接标记为完成
                                      onTaskStatusChanged(
                                        task,
                                        TaskStatus.done,
                                      );
                                    } else {
                                      // 待办或已完成任务点击开始计时
                                      onTaskStatusChanged(
                                        task,
                                        TaskStatus.inProgress,
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (task.status ==
                                            TaskStatus.inProgress) ...[
                                          DsIcon(
                                            DsIconKind.clock,
                                            size: 16,
                                            color: theme.primary,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            task.formattedDuration,
                                            style: DsTypography.caption
                                                .copyWith(
                                                  fontSize: 10,
                                                  fontFamily: 'monospace',
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.primary,
                                                ),
                                          ),
                                        ] else if (task.status ==
                                                TaskStatus.done &&
                                            task.duration != null) ...[
                                          DsIcon(
                                            DsIconKind.check,
                                            size: 16,
                                            color: theme.success,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            task.formattedDuration,
                                            style: DsTypography.caption
                                                .copyWith(
                                                  fontSize: 10,
                                                  fontFamily: 'monospace',
                                                  color: theme.success,
                                                ),
                                          ),
                                        ] else ...[
                                          DsIcon(
                                            DsIconKind.play,
                                            size: 16,
                                            color: theme.textSub,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '00:00',
                                            style: DsTypography.caption
                                                .copyWith(
                                                  fontSize: 10,
                                                  fontFamily: 'monospace',
                                                  color: theme.textSub,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
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
  }
}
