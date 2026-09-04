import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/plugins/tracker/controllers/tracker_controller.dart';

/// 死代码文件：无外部引用，仅做轻量令牌化（供后续评估删除）
class TrackerSummaryCard extends StatelessWidget {
  const TrackerSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final controller = TrackerController();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              context,
              theme,
              icon: Icons.flag,
              value: controller.getGoalCount(),
              label: '目标数',
            ),
            _buildStatItem(
              context,
              theme,
              icon: Icons.note_add,
              value: controller.getTodayRecordCount(),
              label: '今日记录',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    AppThemeData theme, {
    required IconData icon,
    required int value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32, color: theme.primary),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: DsTypography.title.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.text,
          ),
        ),
        Text(label, style: DsTypography.caption.copyWith(color: theme.textSub)),
      ],
    );
  }
}
