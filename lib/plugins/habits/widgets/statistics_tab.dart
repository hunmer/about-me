import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/habits/controllers/completion_record_controller.dart';
import 'package:aboutme/plugins/habits/models/skill.dart';
import 'package:aboutme/plugins/habits/utils/habits_utils.dart';

class StatisticsTab extends StatelessWidget {
  final Skill skill;
  final CompletionRecordController recordController;

  const StatisticsTab({
    super.key,
    required this.skill,
    required this.recordController,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        recordController.getCompletionCount(skill.id),
        recordController.getTotalDuration(skill.id),
      ]),
      builder: (context, snapshot) {
        final count = snapshot.data?[0] ?? 0;
        final duration = snapshot.data?[1] ?? 0;

        return DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'habits_statistics'.tr,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                      const SizedBox(height: 16),
                      DSCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                DsIcon(
                                  DsIconKind.check,
                                  color: theme.primaryText,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'habits_totalCompletions'.tr,
                                    style: DsTypography.body.copyWith(
                                      color: theme.text,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${'habits_completions'.tr}: $count',
                                  style: DsTypography.body.copyWith(
                                    color: theme.textSub,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                DsIcon(
                                  DsIconKind.clock,
                                  color: theme.primaryText,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'habits_totalDuration'.tr,
                                    style: DsTypography.body.copyWith(
                                      color: theme.text,
                                    ),
                                  ),
                                ),
                                Text(
                                  HabitsUtils.formatDuration(duration),
                                  style: DsTypography.body.copyWith(
                                    color: theme.textSub,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // TODO: 添加统计图表
                      Center(
                        child: Text(
                          'habits_statisticsChartsPlaceholder'.tr,
                          style: DsTypography.body.copyWith(
                            color: theme.textSub,
                            fontStyle: FontStyle.italic,
                          ),
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
}
