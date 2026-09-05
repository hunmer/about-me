import 'package:flutter/material.dart' hide Row, SizedBox, ListTile;
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart' as flutter show Row, SizedBox, ListTile;
import 'package:aboutme/plugins/tracker/models/goal.dart';
import 'package:aboutme/plugins/tracker/controllers/tracker_controller.dart';
import 'record_dialog.dart';
import 'goal_edit_page.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

class GoalDetailPage extends StatelessWidget {
  final Goal goal;
  final TrackerController controller;

  const GoalDetailPage({
    super.key,
    required this.goal,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // 死代码文件：仅做轻量令牌化（无外部引用，供后续评估删除）
    final theme = DSThemeBridge.resolve(context);
    final records =
        controller.records
            .where((r) => r.goalId == goal.id)
            .toList()
            .reversed
            .toList();
    final progress = controller.calculateProgress(goal);

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _navigateToEditPage(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                flutter.Row(
                  children: [
                    Icon(
                      dynamicIconData(
                        int.parse(goal.icon),
                        fontFamily: 'MaterialIcons',
                      ),
                      size: 32,
                    ),
                    const flutter.SizedBox(width: 8),
                    Text(
                      '${goal.targetValue}${goal.unitType}',
                      style: DsTypography.heading.copyWith(color: theme.text),
                    ),
                  ],
                ),
                const flutter.SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: theme.surfaceAlt,
                  color:
                      goal.progressColor != null
                          ? Color(goal.progressColor!)
                          : theme.primary,
                ),
                const flutter.SizedBox(height: 8),
                Text(
                  '${(progress * 100).toInt()}% 完成',
                  style: DsTypography.body.copyWith(color: theme.text),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                return flutter.ListTile(
                  leading: Text(
                    '+${record.value}${goal.unitType}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  title: Text(
                    record.note ?? '无备注',
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                  subtitle: Text(
                    _formatDateTime(record.recordedAt),
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRecordDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month}-${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showRecordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => RecordDialog(goal: goal, controller: controller),
    );
  }

  void _navigateToEditPage(BuildContext context) {
    NavigationHelper.push(
      context,
      GoalEditPage(controller: controller, goal: goal),
    );
  }
}
