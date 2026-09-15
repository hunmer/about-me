import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/todo/views/todo_item_detail.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/plugins/todo/models/task.dart';
import 'package:aboutme/plugins/todo/controllers/task_controller.dart';

class HistoryCompletedView extends StatefulWidget {
  final List<Task> completedTasks;
  final TaskController taskController;

  const HistoryCompletedView({
    super.key,
    required this.completedTasks,
    required this.taskController,
  });

  @override
  State<HistoryCompletedView> createState() => _HistoryCompletedViewState();
}

class _HistoryCompletedViewState extends State<HistoryCompletedView> {
  @override
  Widget build(BuildContext context) {
    // 经 CustomBottomBar/TabBarView 挂载，自备主题桥保证 DS 组件可用
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          if (widget.completedTasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // history 系图标无自绘等价物，保留 Material 图标
                  Icon(
                    Icons.history_outlined,
                    size: 64,
                    color: theme.textSub.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'todo_noCompletedTasks'.tr,
                    style: DsTypography.body.copyWith(color: theme.textSub),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: ListView.builder(
              padding: EdgeInsets.only(
                top: 8,
                bottom: 8 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: widget.completedTasks.length,
              itemBuilder: (context, index) {
                final task = widget.completedTasks[index];
                return _buildTaskCard(context, task);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, Task task) {
    final theme = DSThemeBridge.resolve(context);

    // 格式化日期
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final createdAtStr = dateFormat.format(task.createdAt.toLocal());
    final completedAtStr =
        task.completedDate != null
            ? dateFormat.format(task.completedDate!.toLocal())
            : '-';

    // 计算完成耗时
    String? durationStr;
    if (task.completedDate != null) {
      final duration = task.completedDate!.difference(task.createdAt);
      durationStr = _formatDuration(duration);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: DSCard(
        onTap: () {
          SmoothBottomSheet.show(
            context: context,
            isScrollControlled: true,
            builder:
                (context) => TodoItemDetail(
                  task: task,
                  taskController: widget.taskController,
                  isReadOnly: true,
                ),
          );
        },
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：图标 + 标题 + 删除按钮
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 任务图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: task.priorityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  // task.icon 为持久化 IconData，保留 Material 图标
                  child: Icon(
                    task.icon ?? Icons.check_circle,
                    color: task.priorityColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // 标题和描述
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: DsTypography.heading.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.lineThrough,
                          color: theme.text.withValues(alpha: 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (task.description != null &&
                          task.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description!,
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // 删除按钮
                DSIconButton(
                  icon: DsIconKind.trash,
                  size: 32,
                  color: theme.surfaceAlt,
                  iconColor: theme.danger,
                  tooltip: 'todo_delete'.tr,
                  onPressed: () async {
                    await widget.taskController.removeFromHistory(task.id);
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 分隔线
            Divider(height: 1, color: theme.stroke),
            const SizedBox(height: 10),
            // 底部：时间信息
            Row(
              children: [
                // 创建时间
                Expanded(
                  child: _buildTimeInfo(
                    context,
                    icon: DsIconKind.plus,
                    label: 'todo_createdAt'.tr,
                    value: createdAtStr,
                    color: theme.primary,
                  ),
                ),
                // 完成时间
                Expanded(
                  child: _buildTimeInfo(
                    context,
                    icon: DsIconKind.check,
                    label: 'todo_completedOn'.tr,
                    value: completedAtStr,
                    color: theme.success,
                  ),
                ),
              ],
            ),
            // 耗时和标签信息
            if (durationStr != null || task.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  // 耗时
                  if (durationStr != null)
                    _buildChip(
                      context,
                      icon: DsIconKind.clock,
                      label: durationStr,
                      color: theme.secondary,
                    ),
                  if (durationStr != null && task.tags.isNotEmpty)
                    const SizedBox(width: 8),
                  // 标签
                  if (task.tags.isNotEmpty)
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              task.tags
                                  .take(3)
                                  .map(
                                    (tag) => Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: _buildChip(
                                        context,
                                        icon: DsIconKind.tag,
                                        label: tag,
                                        color: theme.primary,
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo(
    BuildContext context, {
    required DsIconKind icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = DSThemeBridge.resolve(context);

    return Row(
      children: [
        DsIcon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: DsTypography.caption.copyWith(
                  color: theme.textSub,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: DsTypography.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: theme.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required DsIconKind icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIcon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: DsTypography.caption.copyWith(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '<1m';
    }
  }
}
