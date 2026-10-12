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
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        mainAxisExtent: 104,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _UnlockedCard(
        def: items[index],
        controller: controller,
      ),
    );
  }
}

/// 已解锁徽章格：六边形贴纸 + 名称（Lv 角标随徽章显示）
class _UnlockedCard extends StatelessWidget {
  const _UnlockedCard({required this.def, required this.controller});

  final AchievementDefinition def;
  final AchievementController controller;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final level = controller.progressOf(def.id).unlockedLevel;

    return Pressable(
      onPressed: () => _openDetail(context),
      builder: (context, states) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AchievementBadge(
              iconAsset: def.iconAsset,
              level: level,
              size: 62,
              showLevelTag: true,
            ),
            const SizedBox(height: 6),
            Text(
              def.name,
              style: DsTypography.label.copyWith(
                fontSize: 11,
                color: theme.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
