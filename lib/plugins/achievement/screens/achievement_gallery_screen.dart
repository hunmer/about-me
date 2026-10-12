import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:skribble/skribble.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/achievement/achievement_plugin.dart';
import 'package:aboutme/plugins/achievement/controllers/achievement_controller.dart';
import 'package:aboutme/plugins/achievement/screens/achievement_in_progress_screen.dart';
import 'package:aboutme/plugins/achievement/screens/achievement_unlocked_screen.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 成就展览界面：概览卡 + 底部双 tab（正在解锁 / 已解锁）
class AchievementGalleryScreen extends StatefulWidget {
  const AchievementGalleryScreen({super.key});

  @override
  State<AchievementGalleryScreen> createState() =>
      _AchievementGalleryScreenState();
}

class _AchievementGalleryScreenState extends State<AchievementGalleryScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // 打开成就页时做一次全量快照结算（幂等，异步不阻塞渲染）
    AchievementPlugin.instance.resolveStats();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AchievementController>();
    return SuperCupertinoNavigationWrapper(
      title: Text('achievement_name'.tr),
      largeTitle: 'achievement_name'.tr,
      body: Column(
        children: [
          _OverviewCard(controller: controller),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                AchievementInProgressScreen(controller: controller),
                AchievementUnlockedScreen(controller: controller),
              ],
            ),
          ),
          _BottomTabs(
            selected: _tab,
            inProgressCount:
                AchievementInProgressScreen.itemsOf(controller).length,
            unlockedCount: AchievementUnlockedScreen.itemsOf(controller).length,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ],
      ),
    );
  }
}

/// 顶部概览卡：解锁进度 / 累计积分 / 最近达成
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.controller});

  final AchievementController controller;

  static String _fmtDate(DateTime? d) => d == null
      ? 'achievement_none'.tr
      : '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final unlocked = controller.unlockedLevels;
    final total = controller.totalLevels;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(14),
        seed: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                WiredIcon(
                  icon: Icons.emoji_events_outlined,
                  size: 18,
                  color: theme.primary,
                  drawConfig: theme.wired.drawConfig,
                ),
                const SizedBox(width: 6),
                Text(
                  'achievement_progressTitle'.tr,
                  style: DsTypography.heading.copyWith(color: theme.text),
                ),
                const Spacer(),
                Text(
                  '$unlocked / $total ${'achievement_levels'.tr}',
                  style: DsTypography.title.copyWith(color: theme.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DSLinearProgress(
              value: controller.overallProgress,
              height: 12,
              thumb: DsIcon(DsIconKind.star, size: 22, color: theme.primary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                DsIcon(DsIconKind.star, size: 14, color: theme.textSub),
                const SizedBox(width: 4),
                Text(
                  '+${controller.totalEarnedPoints} ${'achievement_points'.tr}',
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
                const SizedBox(width: 16),
                DsIcon(DsIconKind.clock, size: 14, color: theme.textSub),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${'achievement_recentUnlock'.tr} ${_fmtDate(controller.lastUnlockedAt)}',
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部手绘 tab 栏：正在解锁 / 已解锁（带计数）
class _BottomTabs extends StatelessWidget {
  const _BottomTabs({
    required this.selected,
    required this.inProgressCount,
    required this.unlockedCount,
    required this.onChanged,
  });

  final int selected;
  final int inProgressCount;
  final int unlockedCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Container(
          height: 56,
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: theme.surface,
            radius: BorderRadius.circular(999),
            strokeWidth: 2,
            seed: 7,
          ),
          child: Row(
            children: [
              _segment(
                theme,
                0,
                DsIconKind.sprout,
                'achievement_tabInProgress'.tr,
                inProgressCount,
              ),
              _segment(
                theme,
                1,
                DsIconKind.star,
                'achievement_filterUnlocked'.tr,
                unlockedCount,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segment(
    AppThemeData theme,
    int index,
    DsIconKind icon,
    String label,
    int count,
  ) {
    final active = selected == index;
    return Expanded(
      child: Pressable(
        onPressed: () => onChanged(index),
        semanticLabel: label,
        builder: (context, states) {
          final fg = active ? theme.onPrimary : theme.textSub;
          return Container(
            margin: const EdgeInsets.all(5),
            alignment: Alignment.center,
            decoration: active
                ? dsSketchDecoration(
                    theme: theme,
                    fillColor: theme.primary,
                    radius: BorderRadius.circular(999),
                    strokeWidth: 1.2,
                    seed: index + 11,
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DsIcon(icon, size: 17, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: DsTypography.button.copyWith(
                    fontSize: 13,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: DsTypography.label.copyWith(
                    fontSize: 11,
                    color: fg.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
