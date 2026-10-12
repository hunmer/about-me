import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/todo/models/task.dart';
import 'package:aboutme/plugins/todo/controllers/task_controller.dart';
import 'package:aboutme/plugins/todo/widgets/task_form.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/todo/todo_plugin.dart';
import 'package:aboutme/core/route/route_history_manager.dart';

class TodoItemDetail extends StatefulWidget {
  final Task task;
  final TaskController taskController;
  final bool isReadOnly;

  const TodoItemDetail({
    super.key,
    required this.task,
    required this.taskController,
    this.isReadOnly = false,
  });

  @override
  State<TodoItemDetail> createState() => _TodoItemDetailState();
}

class _TodoItemDetailState extends State<TodoItemDetail> {
  Timer? _timer;
  late Task _task;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    if (_task.status == TaskStatus.inProgress) {
      _startTimerUpdate();
    }

    // 更新路由上下文，使"询问当前上下文"功能能获取到当前查看的任务
    _updateRouteContext();
  }

  /// 更新路由上下文
  void _updateRouteContext() {
    RouteHistoryManager.updateCurrentContext(
      pageId: '/todo_detail',
      title: 'todo_routeDetailTitle'.trParams({'title': _task.title}),
      params: {
        'taskId': _task.id,
        'taskTitle': _task.title,
        'taskStatus': _task.status.toString(),
        'priority': _task.priority.toString(),
        'isReadOnly': widget.isReadOnly,
      },
    );
  }

  @override
  void didUpdateWidget(TodoItemDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task != oldWidget.task) {
      _task = widget.task;
      if (_task.status == TaskStatus.inProgress) {
        _startTimerUpdate();
      } else {
        _timer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimerUpdate() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        // Refresh UI to show updated duration
      });
    });
  }

  String get _priorityText {
    switch (_task.priority) {
      case TaskPriority.q1:
        return 'todo_q1'.tr;
      case TaskPriority.q2:
        return 'todo_q2'.tr;
      case TaskPriority.q3:
        return 'todo_q3'.tr;
      case TaskPriority.q4:
        return 'todo_q4'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to controller changes to update the task object
    return AnimatedBuilder(
      animation: widget.taskController,
      builder: (context, child) {
        // Find the task in the controller's list to get the latest state
        try {
          if (widget.isReadOnly) {
            _task = widget.task;
          } else {
            _task = widget.taskController.tasks.firstWhere(
              (t) => t.id == widget.task.id,
            );
          }
        } catch (e) {
          if (widget.isReadOnly) {
            _task = widget.task;
          } else {
            // Task might have been deleted
            return const SizedBox.shrink();
          }
        }

        // 经 SmoothBottomSheet 展示（主题树之外），自备主题桥
        return DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);

              // 优先级语义色（令牌随明暗自适应）
              final Color priorityColor = switch (_task.priority) {
                TaskPriority.q1 => theme.danger,
                TaskPriority.q2 => theme.success,
                TaskPriority.q3 => theme.warning,
                TaskPriority.q4 => theme.primary,
              };

              // 大容器走手绘面板：纸底 + 淡排线 + 墨线框（顶部大圆角，
              // 纸色铺满 sheet）
              return DsSketchPanel(
                theme: theme,
                radius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Only take needed height
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            DSIconButton(
                              icon: DsIconKind.close,
                              size: 32,
                              color: theme.surfaceAlt,
                              iconColor: theme.textSub,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title Section
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      JellyBox(
                                        width: 40,
                                        height: 40,
                                        radius: theme.radii.md,
                                        color: theme.surfaceAlt,
                                        alignment: Alignment.center,
                                        // _task.icon 为持久化 IconData，保留 Material 图标
                                        child: Icon(
                                          _task.icon ?? Icons.work,
                                          color: theme.primary,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _task.title,
                                          style: DsTypography.display.copyWith(
                                            color: theme.text,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!widget.isReadOnly) ...[
                                  const SizedBox(width: 16),
                                  Pressable(
                                    onPressed: () {
                                      if (_task.status ==
                                          TaskStatus.inProgress) {
                                        // If running, complete the task (and stop timer)
                                        widget.taskController.updateTaskStatus(
                                          _task.id,
                                          TaskStatus.done,
                                        );
                                        _timer?.cancel();
                                      } else {
                                        // If not running, start the timer
                                        widget.taskController.updateTaskStatus(
                                          _task.id,
                                          TaskStatus.inProgress,
                                        );
                                        _startTimerUpdate();
                                      }
                                    },
                                    // 小控件走实底 + 墨线描边（pill 自动胶囊）
                                    child: JellyBox(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      radius: theme.radii.pill,
                                      color:
                                          _task.status == TaskStatus.inProgress
                                              ? theme.success
                                              : theme.primary,
                                      child: Row(
                                        children: [
                                          DsIcon(
                                            _task.status ==
                                                    TaskStatus.inProgress
                                                ? DsIconKind.check
                                                : DsIconKind.play,
                                            color:
                                                _task.status ==
                                                        TaskStatus.inProgress
                                                    ? theme.onSuccess
                                                    : theme.onPrimary,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _task.status ==
                                                    TaskStatus.inProgress
                                                ? 'todo_done'.tr
                                                : 'todo_start'.tr,
                                            style: DsTypography.button.copyWith(
                                              color:
                                                  _task.status ==
                                                          TaskStatus.inProgress
                                                      ? theme.onSuccess
                                                      : theme.onPrimary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Tags
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_task.status == TaskStatus.inProgress)
                                  _buildTag(
                                    context,
                                    dot: true,
                                    text: 'todo_statusInProgress'.tr,
                                    color: theme.primary,
                                    iconSize: 14,
                                  ),
                                _buildTag(
                                  context,
                                  dsIcon: DsIconKind.flag,
                                  text: _priorityText,
                                  color: priorityColor,
                                  iconSize: 14,
                                ),
                                _buildTag(
                                  context,
                                  dsIcon: DsIconKind.clock,
                                  text: _task.formattedDuration,
                                  color: theme.textSub,
                                  iconSize: 14,
                                ),
                                ..._task.tags.map(
                                  (tag) => _buildTag(
                                    context,
                                    dsIcon: DsIconKind.tag,
                                    text: tag,
                                    color: theme.textSub,
                                    iconSize: 14,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Description
                            if (_task.description != null &&
                                _task.description!.isNotEmpty)
                              Text(
                                _task.description!,
                                style: DsTypography.body.copyWith(
                                  color: theme.text,
                                  fontSize: 16,
                                ),
                              ),

                            const SizedBox(height: 16),

                            // Subtasks
                            if (_task.subtasks.isNotEmpty) ...[
                              Text(
                                'todo_subtasks'.tr,
                                style: DsTypography.body.copyWith(
                                  color: theme.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._task.subtasks.map(
                                (subtask) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      DSCheckbox(
                                        value: subtask.isCompleted,
                                        onChanged:
                                            widget.isReadOnly
                                                ? null
                                                : (value) {
                                                  widget.taskController
                                                      .updateSubtaskStatus(
                                                        _task.id,
                                                        subtask.id,
                                                        value ?? false,
                                                      );
                                                },
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          subtask.title,
                                          style: DsTypography.body.copyWith(
                                            color:
                                                subtask.isCompleted
                                                    ? theme.textSub
                                                    : theme.text,
                                            fontSize: 16,
                                            decoration:
                                                subtask.isCompleted
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                            decorationColor: theme.textSub,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Add Subtask or Edit (Optional, based on "Edit" button in original dialog)
                            if (!widget.isReadOnly)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  DSButton(
                                    label: 'todo_editTask'.tr,
                                    icon: DsIconKind.edit,
                                    variant: DSButtonVariant.ghost,
                                    onPressed: () {
                                      Navigator.of(
                                        context,
                                      ).pop(); // Close detail first
                                      NavigationHelper.push(
                                        context,
                                        TaskForm(
                                          task: _task,
                                          taskController: widget.taskController,
                                          reminderController:
                                              TodoPlugin
                                                  .instance
                                                  .reminderController,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),

                            const SizedBox(height: 16),
                            Divider(color: theme.stroke),
                            const SizedBox(height: 16),

                            // Metadata
                            _buildMetadataRow(
                              context,
                              'todo_created'.tr,
                              _formatFullDate(_task.createdAt),
                            ),
                            if (_task.dueDate != null)
                              _buildMetadataRow(
                                context,
                                'todo_dueDate'.tr,
                                _formatFullDate(_task.dueDate!),
                              ),
                            // Assuming reminders is a list of DateTime
                            if (_task.reminders.isNotEmpty)
                              _buildMetadataRow(
                                context,
                                'todo_reminders'.tr,
                                _formatFullDateTime(_task.reminders.first),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTag(
    BuildContext context, {
    DsIconKind? dsIcon,
    bool dot = false,
    required String text,
    required Color color,
    required double iconSize,
  }) {
    final theme = DSThemeBridge.resolve(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      // 小控件走纯色实底 + 墨线描边（pill 自动胶囊）
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: color.withValues(alpha: 0.12),
        stroke: color.withValues(alpha: 0.55),
        strokeWidth: 1.2,
        radius: theme.radii.pill,
        seed: text.length,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            // 手绘小墨点
            Container(
              width: iconSize,
              height: iconSize,
              decoration: dsSketchDecoration(
                theme: theme,
                circle: true,
                fillColor: color,
                strokeWidth: 1.0,
              ),
            )
          else if (dsIcon != null)
            DsIcon(dsIcon, color: color, size: iconSize),
          const SizedBox(width: 6),
          Text(
            text,
            style: DsTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 本地化完整日期（如 zh「2026年10月12日」/ en「2026/10/12」）
  String _formatFullDate(DateTime date) {
    return 'todo_fullDate'.trParams({
      'y': '${date.year}',
      'm': '${date.month}',
      'd': '${date.day}',
    });
  }

  /// 本地化完整日期时间
  String _formatFullDateTime(DateTime date) {
    return 'todo_fullDateTime'.trParams({
      'y': '${date.year}',
      'm': '${date.month}',
      'd': '${date.day}',
      'hh': date.hour.toString().padLeft(2, '0'),
      'mm': date.minute.toString().padLeft(2, '0'),
    });
  }

  Widget _buildMetadataRow(BuildContext context, String label, String value) {
    final theme = DSThemeBridge.resolve(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: DsTypography.body.copyWith(color: theme.textSub)),
          Text(
            value,
            style: DsTypography.body.copyWith(
              color: theme.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
