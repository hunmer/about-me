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

/// Tab：已解锁的成就（至少解锁一级），按最近达成时间倒序，双列徽章墙
class AchievementUnlockedScreen extends StatelessWidget {
  const AchievementUnlockedScreen({super.key, required this.controller});

  final AchievementController controller;

  static List<AchievementDefinition> itemsOf(AchievementController controller) {
    final items = kAchievementDefinitions
        .where((d) => controller.progressOf(d.id).unlockedLevel > 0)
        .toList();
    DateTime lastOf(AchievementDefinition d) =>
        controller.unlockedDateOf(d.id, controller.progressOf(d.id).unlockedLevel) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    items.sort((a, b) => lastOf(b).compareTo(lastOf(a)));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = itemsOf(controller);
    if (items.isEmpty) {
      return DSEmptyState(
        emoji: '🌱',
        title: 'achievement_emptyUnlocked'.tr,
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 172,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _UnlockedCard(
        def: items[index],
        controller: controller,
        seed: index,
      ),
    );
  }
}

/// 已解锁徽章卡：徽章 + 名称 + 等级 pill + 最近达成日期
class _UnlockedCard extends StatelessWidget {
  const _UnlockedCard({
    required this.def,
    required this.controller,
    required this.seed,
  });

  final AchievementDefinition def;
  final AchievementController controller;
  final int seed;

  static String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final level = controller.progressOf(def.id).unlockedLevel;
    final color = AchievementLevels.borderColor(level);
    final date = controller.unlockedDateOf(def.id, level);

    return Pressable(
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AchievementBadge(iconAsset: def.iconAsset, level: level, size: 64),
              const SizedBox(height: 10),
              Text(
                def.name,
                style: DsTypography.button.copyWith(
                  fontSize: 14,
                  color: theme.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: dsSketchDecoration(
                  theme: theme,
                  fillColor: color.withValues(alpha: 0.22),
                  stroke: color,
                  radius: BorderRadius.circular(999),
                  strokeWidth: 1.2,
                  seed: seed + 17,
                ),
                child: Text(
                  'Lv$level',
                  style: DsTypography.label.copyWith(fontSize: 11, color: color),
                ),
              ),
              const SizedBox(height: 6),
              if (date != null)
                Text(
                  '${'achievement_unlocked_at'.tr} ${_fmtDate(date)}',
                  style: DsTypography.caption.copyWith(
                    fontSize: 10,
                    color: theme.textSub,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        );
      },
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
