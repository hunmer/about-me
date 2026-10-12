import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/achievement/controllers/achievement_controller.dart';
import 'package:aboutme/plugins/achievement/data/achievement_definitions.dart';
import 'package:aboutme/plugins/achievement/models/achievement_definition.dart';
import 'package:aboutme/plugins/achievement/screens/achievement_detail_screen.dart';
import 'package:aboutme/plugins/achievement/widgets/achievement_badge.dart';

/// Tab：正在解锁的成就（还有等级未解锁），按「距下一级进度」降序排列
class AchievementInProgressScreen extends StatelessWidget {
  const AchievementInProgressScreen({super.key, required this.controller});

  final AchievementController controller;

  /// 进行中的系列：已解锁等级 < 最高等级
  static List<AchievementDefinition> itemsOf(AchievementController controller) {
    final items = kAchievementDefinitions
        .where((d) => controller.progressOf(d.id).unlockedLevel < d.maxLevel)
        .toList();
    double ratio(AchievementDefinition d) {
      final p = controller.progressOf(d.id);
      return p.value / d.thresholds[p.unlockedLevel];
    }

    items.sort((a, b) => ratio(b).compareTo(ratio(a)));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = itemsOf(controller);
    if (items.isEmpty) {
      return DSEmptyState(
        emoji: '🎉',
        title: 'achievement_emptyInProgress'.tr,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: items.length,
      itemBuilder: (context, index) => _InProgressTile(
        def: items[index],
        controller: controller,
        seed: index,
      ),
    );
  }
}

/// 进行中的成就行：徽章 + 名称/条件 + 下一级进度条
class _InProgressTile extends StatelessWidget {
  const _InProgressTile({
    required this.def,
    required this.controller,
    required this.seed,
  });

  final AchievementDefinition def;
  final AchievementController controller;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final progress = controller.progressOf(def.id);
    final level = progress.unlockedLevel;
    final revealed = !def.hidden || level > 0;
    final nextThreshold = def.thresholds[level];
    final ratio = (progress.value / nextThreshold).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Pressable(
        onPressed: () => _openDetail(context),
        builder: (context, states) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: theme.surface,
              radius: BorderRadius.circular(16),
              seed: seed + 2,
            ),
            child: Row(
              children: [
                AchievementBadge(
                  iconAsset: def.iconAsset,
                  level: level,
                  size: 50,
                  showLevelTag: level > 0,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              revealed ? def.name : '???',
                              style: DsTypography.button.copyWith(
                                fontSize: 14,
                                color: theme.text,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (def.hidden && !revealed) ...[
                            const SizedBox(width: 5),
                            DsIcon(
                              DsIconKind.eyeOff,
                              size: 13,
                              color: theme.textSub,
                            ),
                          ],
                          if (kPendingAchievementIds.contains(def.id)) ...[
                            const SizedBox(width: 6),
                            _PendingTag(theme: theme, seed: seed),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        revealed ? def.condition : 'achievement_hiddenHint'.tr,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DSLinearProgress(
                              value: ratio,
                              height: 8,
                              color: theme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${progress.value}/$nextThreshold${def.unit}',
                            style: DsTypography.label.copyWith(
                              fontSize: 11,
                              color: theme.textSub,
                            ),
                          ),
                        ],
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

  void _openDetail(BuildContext context) {
    NavigationHelper.push(
      context,
      AchievementDetailScreen(def: def, controller: controller),
      routeName: '/achievement_detail/${def.id}',
    );
  }
}

/// 数据源未接入标记
class _PendingTag extends StatelessWidget {
  const _PendingTag({required this.theme, required this.seed});

  final AppThemeData theme;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surfaceAlt,
        radius: BorderRadius.circular(4),
        strokeWidth: 1,
        seed: seed + 31,
      ),
      child: Text(
        'achievement_pending'.tr,
        style: DsTypography.label.copyWith(fontSize: 9, color: theme.textSub),
      ),
    );
  }
}
