import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/tracker/tracker_plugin.dart';

class GoalDetailScreen extends StatelessWidget {
  final Goal? goal;
  final String? goalId;

  const GoalDetailScreen({super.key, this.goal, this.goalId});

  @override
  Widget build(BuildContext context) {
    // 始终使用单例 controller
    final controller = TrackerPlugin.instance.controller;

    // 如果传入了 goalId，则通过 ID 查找目标
    final targetGoal =
        goal ??
        (goalId != null
            ? controller.goals.firstWhere(
              (g) => g.id == goalId,
              orElse: () => throw Exception('目标不存在'),
            )
            : null);
    if (targetGoal == null) {
      return const Scaffold(body: Center(child: Text('目标不存在')));
    }
    final currentValue =
        controller.goals.firstWhere((g) => g.id == targetGoal.id).currentValue;
    final isCompleted = currentValue >= targetGoal.targetValue;

    return Scaffold(
      appBar: AppBar(
        title: Text(targetGoal.name),
        actions: [
          // 清空记录
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.trash,
                  size: 40,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  onPressed:
                      () =>
                          _confirmClearRecords(context, controller, targetGoal),
                );
              },
            ),
          ),
          // 编辑目标
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.edit,
                  size: 40,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  onPressed: () {
                    NavigationHelper.push(
                      context,
                      GoalEditPage(controller: controller, goal: targetGoal),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      body: DSThemeBridge(
        // DS 组件需要 AppTheme 子树
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${'tracker_goalsTitle'.tr}: ${targetGoal.name}',
                    style: DsTypography.heading.copyWith(color: theme.text),
                  ),
                  const SizedBox(height: 16),
                  DSLinearProgress(
                    value: controller.calculateProgress(targetGoal),
                    height: 8,
                    color:
                        isCompleted
                            ? theme.success
                            : targetGoal.progressColor != null
                            ? Color(targetGoal.progressColor!)
                            : theme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'tracker_currentProgress'.tr
                        .replaceFirst('{currentValue}', currentValue.toString())
                        .replaceFirst(
                          '{targetValue}',
                          targetGoal.targetValue.toString(),
                        ),
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                  const SizedBox(height: 16),
                  if (targetGoal.reminderTime != null)
                    Text(
                      'tracker_reminderTime'.tr.replaceFirst(
                        '{reminderTime}',
                        targetGoal.reminderTime.toString(),
                      ),
                      style: DsTypography.body.copyWith(color: theme.text),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'tracker_recordHistory'.tr,
                    style: DsTypography.heading.copyWith(color: theme.text),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: FutureBuilder<List<Record>>(
                      future: controller.getRecordsForGoal(targetGoal.id),
                      builder: (context, initialSnapshot) {
                        if (initialSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(child: DSLoadingDots());
                        }

                        return StreamBuilder<List<Record>>(
                          stream: controller.watchRecordsForGoal(targetGoal.id),
                          initialData: initialSnapshot.data,
                          builder: (context, snapshot) {
                            final records = snapshot.data ?? [];
                            if (records.isEmpty) {
                              return Center(
                                child: Text(
                                  'tracker_noRecords'.tr,
                                  style: DsTypography.body.copyWith(
                                    color: theme.textSub,
                                  ),
                                ),
                              );
                            }
                            return ListView.builder(
                              itemCount: records.length,
                              itemBuilder: (context, index) {
                                final record = records[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: DSListItem(
                                    title: 'tracker_recordValueDisplay'
                                        .trParams({
                                          'value': record.value.toString(),
                                        }),
                                    subtitle:
                                        record.recordedAt
                                            .toLocal()
                                            .toString()
                                            .split('.')
                                            .first,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if ((record.note ?? '').isNotEmpty)
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 80,
                                            ),
                                            child: Text(
                                              record.note ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: DsTypography.caption
                                                  .copyWith(
                                                    color: theme.textSub,
                                                  ),
                                            ),
                                          ),
                                        SizedBox(width: theme.spacing.xs),
                                        DSIconButton(
                                          icon: DsIconKind.trash,
                                          size: 32,
                                          color: theme.surfaceAlt,
                                          iconColor: theme.textSub,
                                          onPressed:
                                              () => _confirmDeleteRecord(
                                                context,
                                                controller,
                                                record,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: DSThemeBridge(
        // FAB 位于 Scaffold 层，DS 组件先过桥
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return DSFab(
              icon: DsIconKind.plus,
              onPressed: () {
                showDSDialog(
                  context: context,
                  theme: theme,
                  builder:
                      (context) => RecordDialog(
                        goal: targetGoal,
                        controller: controller,
                      ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// 确认清空该目标的全部记录
  Future<void> _confirmClearRecords(
    BuildContext context,
    TrackerController controller,
    Goal targetGoal,
  ) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'tracker_confirmClear'.tr,
                    message: 'tracker_confirmClearMessage'.tr,
                    cancelText: 'app_cancel'.tr,
                    confirmText: 'app_ok'.tr,
                  ),
            ),
          ),
    );
    if (confirmed == true) {
      await controller.clearRecordsForGoal(targetGoal.id);
      if (context.mounted) {
        Toast.success('tracker_recordsCleared'.tr);
      }
    }
  }

  /// 确认删除单条记录
  Future<void> _confirmDeleteRecord(
    BuildContext context,
    TrackerController controller,
    Record record,
  ) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'tracker_confirmDelete'.tr,
                    message: 'tracker_confirmDeleteRecordMessage'.tr,
                    cancelText: 'app_cancel'.tr,
                    confirmText: 'app_ok'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                  ),
            ),
          ),
    );
    if (confirmed == true) {
      await controller.deleteRecord(record.id);
      if (context.mounted) {
        Toast.success('tracker_recordDeleted'.tr);
      }
    }
  }
}
