import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/todo/models/models.dart';
import 'package:aboutme/plugins/todo/models/task.dart';

/// 四象限视图（手绘纸墨风）
///
/// 四个大象限面板走 [DsSketchPanel]（纸底 + 象限语义色排线 + 墨线框），
/// 标签/子任务等小徽章走 [dsSketchDecoration]（纯色实底 + 墨线描边），
/// 挂载时经 [WiredDraw] 播墨线描画入场。
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

    // 经 CustomBottomBar/TabBarView 挂载，自备主题桥保证 DS 组件可用
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          // Tab 切换挂载时墨线描画入场
          return WiredDraw(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuadrant(
                            context,
                            titleKey: 'todo_q1',
                            icon: DsIconKind.fire,
                            color: theme.danger,
                            tasks: q1,
                            priority: TaskPriority.q1,
                            seed: 11,
                          ),
                        ),
                        Expanded(
                          child: _buildQuadrant(
                            context,
                            titleKey: 'todo_q2',
                            icon: DsIconKind.sprout,
                            color: theme.success,
                            tasks: q2,
                            priority: TaskPriority.q2,
                            seed: 22,
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
                            titleKey: 'todo_q3',
                            icon: DsIconKind.clock,
                            color: theme.warning,
                            tasks: q3,
                            priority: TaskPriority.q3,
                            seed: 33,
                          ),
                        ),
                        Expanded(
                          child: _buildQuadrant(
                            context,
                            titleKey: 'todo_q4',
                            icon: DsIconKind.coffee,
                            color: theme.primary,
                            tasks: q4,
                            priority: TaskPriority.q4,
                            seed: 44,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 悬浮底部栏遮挡区域预留
                  SizedBox(height: MediaQuery.paddingOf(context).bottom),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuadrant(
    BuildContext context, {
    required String titleKey,
    required DsIconKind icon,
    required Color color,
    required List<Task> tasks,
    TaskPriority? priority,
    int seed = 1,
  }) {
    final theme = DSThemeBridge.resolve(context);

    return Padding(
      padding: const EdgeInsets.all(4),
      // 大容器走手绘面板：纸底 + 象限语义色排线 + 墨线框
      child: DsSketchPanel(
        theme: theme,
        radius: theme.radii.lg,
        hachureColor: color.withValues(alpha: theme.isDark ? 0.22 : 0.10),
        seed: seed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildQuadrantHeader(
              context,
              titleKey: titleKey,
              icon: icon,
              color: color,
              tasks: tasks,
              priority: priority,
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
                              icon,
                              size: 28,
                              color: color.withValues(alpha: 0.35),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'todo_noTodoTasks'.tr,
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _buildTaskItem(
                            context,
                            task: task,
                            index: index,
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  /// 象限头：手绘图标 + 标题 + 数量徽章 + 添加按钮
  Widget _buildQuadrantHeader(
    BuildContext context, {
    required String titleKey,
    required DsIconKind icon,
    required Color color,
    required List<Task> tasks,
    TaskPriority? priority,
  }) {
    final theme = DSThemeBridge.resolve(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
      child: Row(
        children: [
          DsIcon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              titleKey.tr,
              style: DsTypography.label.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (tasks.isNotEmpty) ...[
            _buildCountBadge(context, count: tasks.length, color: color),
            const SizedBox(width: 4),
          ],
          if (onAddTask != null && priority != null)
            DSIconButton(
              icon: DsIconKind.plus,
              size: 30,
              color: theme.surfaceAlt,
              iconColor: color,
              onPressed: () => onAddTask!(priority),
            ),
        ],
      ),
    );
  }

  /// 数量徽章：小控件走纯色实底 + 墨线描边
  Widget _buildCountBadge(
    BuildContext context, {
    required int count,
    required Color color,
  }) {
    final theme = DSThemeBridge.resolve(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: color.withValues(alpha: 0.14),
        stroke: color.withValues(alpha: 0.6),
        strokeWidth: 1.2,
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

  /// 任务行：勾选框 + 标题/标签/子任务 + 计时区
  Widget _buildTaskItem(
    BuildContext context, {
    required Task task,
    required int index,
  }) {
    final theme = DSThemeBridge.resolve(context);

    return Pressable(
      onPressed: () => onTaskTap(task),
      builder: (context, states) => Opacity(
        opacity: states.contains(WidgetState.pressed) ? 0.7 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 任务标题
                    Text(
                      task.title,
                      style: DsTypography.body.copyWith(color: theme.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // 标签和子任务信息
                    if (task.tags.isNotEmpty || task.subtasks.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // 标签显示（最多 2 个 + 溢出计数）
                            ...task.tags.take(2).map(
                              (tag) => _buildTagChip(context, tag: tag),
                            ),
                            if (task.tags.length > 2)
                              _buildTagChip(
                                context,
                                label: '+${task.tags.length - 2}',
                                filled: false,
                              ),
                            // 子任务数量
                            if (task.subtasks.isNotEmpty)
                              _buildSubtaskBadge(context, task: task),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // 计时器显示区域（右上角）
              _buildTimerZone(context, task: task),
            ],
          ),
        ),
      ),
    );
  }

  /// 标签徽章：小控件走纯色实底 + 墨线描边
  Widget _buildTagChip(
    BuildContext context, {
    String? tag,
    String? label,
    bool filled = true,
  }) {
    final theme = DSThemeBridge.resolve(context);
    final text = label ?? tag!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor:
            filled
                ? theme.primary.withValues(alpha: 0.12)
                : theme.surface.withValues(alpha: 0.6),
        stroke: theme.primary.withValues(alpha: 0.55),
        strokeWidth: 1.2,
        radius: theme.radii.pill,
        seed: text.length,
      ),
      child: Text(
        text,
        style: DsTypography.caption.copyWith(
          fontSize: 10,
          color: theme.primary,
        ),
      ),
    );
  }

  /// 子任务进度徽章
  Widget _buildSubtaskBadge(BuildContext context, {required Task task}) {
    final theme = DSThemeBridge.resolve(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surfaceAlt,
        stroke: theme.ink.withValues(alpha: 0.5),
        strokeWidth: 1.2,
        radius: theme.radii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIcon(DsIconKind.check, size: 10, color: theme.textSub),
          const SizedBox(width: 2),
          Text(
            '${task.subtasks.where((s) => s.isCompleted).length}/${task.subtasks.length}',
            style: DsTypography.caption.copyWith(
              fontSize: 10,
              color: theme.textSub,
            ),
          ),
        ],
      ),
    );
  }

  /// 计时区：点击切换计时状态，进行中/已完成显示时长
  Widget _buildTimerZone(BuildContext context, {required Task task}) {
    final theme = DSThemeBridge.resolve(context);

    final bool inProgress = task.status == TaskStatus.inProgress;
    final bool doneWithDuration =
        task.status == TaskStatus.done && task.duration != null;
    final Color timerColor =
        inProgress
            ? theme.primary
            : doneWithDuration
            ? theme.success
            : theme.textSub;

    return Pressable(
      onPressed: () {
        if (inProgress) {
          // 进行中任务点击直接标记为完成
          onTaskStatusChanged(task, TaskStatus.done);
        } else {
          // 待办或已完成任务点击开始计时
          onTaskStatusChanged(task, TaskStatus.inProgress);
        }
      },
      builder:
          (context, states) => Container(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                DsIcon(
                  inProgress
                      ? DsIconKind.clock
                      : doneWithDuration
                      ? DsIconKind.check
                      : DsIconKind.play,
                  size: 16,
                  color: timerColor,
                ),
                const SizedBox(height: 2),
                Text(
                  inProgress || doneWithDuration ? task.formattedDuration : '00:00',
                  style: DsTypography.caption.copyWith(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: timerColor,
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
