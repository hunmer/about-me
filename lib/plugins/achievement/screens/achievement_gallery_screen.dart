import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:aboutme/plugins/achievement/controllers/achievement_controller.dart';
import 'package:aboutme/plugins/achievement/data/achievement_definitions.dart';
import 'package:aboutme/plugins/achievement/models/achievement_definition.dart';
import 'package:aboutme/plugins/achievement/widgets/achievement_badge.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 成就筛选
enum AchievementFilter { all, unlocked, locked }

/// 成就展览界面：五大分类 × 74 个成就系列，含等级进度与获得日期
class AchievementGalleryScreen extends StatelessWidget {
  const AchievementGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AchievementController>();
    return SuperCupertinoNavigationWrapper(
      title: Text(
        'achievement_name'.tr,
        style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color),
      ),
      largeTitle: 'achievement_name'.tr,
      body: _GalleryBody(controller: controller),
    );
  }
}

class _GalleryBody extends StatefulWidget {
  const _GalleryBody({required this.controller});

  final AchievementController controller;

  @override
  State<_GalleryBody> createState() => _GalleryBodyState();
}

class _GalleryBodyState extends State<_GalleryBody> {
  AchievementFilter _filter = AchievementFilter.all;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OverviewCard(controller: widget.controller),
        _FilterBar(
          current: _filter,
          onChanged: (f) => setState(() => _filter = f),
        ),
        Expanded(child: _buildCategoryList(context)),
      ],
    );
  }

  Widget _buildCategoryList(BuildContext context) {
    final controller = widget.controller;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: kAchievementCategories.length,
      itemBuilder: (context, index) {
        final category = kAchievementCategories[index];
        final achievements = kAchievementDefinitions
            .where((d) => d.category == category.id)
            .toList();

        // 应用筛选（隐藏成就仅在"全部/未解锁"下以 ??? 形式出现，已解锁则正常显示）
        final visible = achievements.where((def) {
          final level = controller.progressOf(def.id).unlockedLevel;
          switch (_filter) {
            case AchievementFilter.unlocked:
              return level > 0;
            case AchievementFilter.locked:
              return level == 0;
            case AchievementFilter.all:
              return true;
          }
        }).toList();

        return _CategorySection(
          category: category,
          achievements: visible,
          controller: controller,
        );
      },
    );
  }
}

/// 顶部概览卡：解锁进度 / 累计积分 / 最近达成
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.controller});

  final AchievementController controller;

  static String _fmtDate(DateTime? d) => d == null
      ? 'achievement_none'.tr
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = controller.unlockedLevels;
    final total = controller.totalLevels;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech_outlined,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 6),
              Text(
                'achievement_progressTitle'.tr,
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                '$unlocked / $total ${'achievement_levels'.tr}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: controller.overallProgress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.stars, size: 15, color: theme.hintColor),
              const SizedBox(width: 4),
              Text(
                '+${controller.totalEarnedPoints} ${'achievement_points'.tr}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(width: 16),
              Icon(Icons.schedule, size: 15, color: theme.hintColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${'achievement_recentUnlock'.tr} ${_fmtDate(controller.lastUnlockedAt)}',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 筛选栏
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.current, required this.onChanged});

  final AchievementFilter current;
  final ValueChanged<AchievementFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget chip(AchievementFilter value, String label) {
      final selected = current == value;
      return GestureDetector(
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest.withAlpha(120),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: selected ? theme.colorScheme.onPrimary : theme.hintColor,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          chip(AchievementFilter.all, 'achievement_filterAll'.tr),
          const SizedBox(width: 8),
          chip(AchievementFilter.unlocked, 'achievement_filterUnlocked'.tr),
          const SizedBox(width: 8),
          chip(AchievementFilter.locked, 'achievement_filterLocked'.tr),
        ],
      ),
    );
  }
}

/// 分类分区
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.achievements,
    required this.controller,
  });

  final AchievementCategory category;
  final List<AchievementDefinition> achievements;
  final AchievementController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (achievements.isEmpty) return const SizedBox.shrink();

    final unlockedInCategory = achievements
        .fold<int>(0, (sum, d) => sum + controller.progressOf(d.id).unlockedLevel);
    final totalInCategory =
        achievements.fold<int>(0, (sum, d) => sum + d.maxLevel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(category.icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(category.nameKey.tr, style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              Text(
                '$unlockedInCategory/$totalInCategory',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        ),
        ...achievements.map(
          (def) => _AchievementTile(def: def, controller: controller),
        ),
      ],
    );
  }
}

/// 单个成就行
class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.def, required this.controller});

  final AchievementDefinition def;
  final AchievementController controller;

  static String _fmtDate(DateTime? d) => d == null
      ? ''
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = controller.progressOf(def.id);
    final level = progress.unlockedLevel;
    final maxed = level >= def.maxLevel;
    final nextThreshold = maxed ? null : def.thresholds[level];
    final revealed = !def.hidden || level > 0;

    // 最近获得日期（最高已解锁等级的日期）
    final lastDate = controller.unlockedDateOf(def.id, level);

    return InkWell(
      onTap: () => _showDetail(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            AchievementBadge(
              iconAsset: def.iconAsset,
              level: level,
              size: 52,
              showLevelTag: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          revealed ? def.name : '???',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: revealed
                                ? theme.colorScheme.onSurface
                                : theme.hintColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (def.hidden) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.visibility_off_outlined,
                            size: 13, color: theme.hintColor),
                      ],
                      if (def.event == null) ...[
                        const SizedBox(width: 6),
                        _PendingTag(theme: theme),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    revealed
                        ? def.condition
                        : 'achievement_hiddenHint'.tr,
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // 进度条
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: nextThreshold == null
                                ? 1
                                : (progress.value / nextThreshold).clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(
                              level > 0
                                  ? AchievementLevels.borderColor(level)
                                  : theme.disabledColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        maxed
                            ? 'MAX'
                            : '${progress.value}/$nextThreshold${def.unit}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: maxed
                              ? AchievementLevels.borderColor(level)
                              : theme.hintColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 右侧：等级点 + 最近获得日期
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _LevelDots(maxLevel: def.maxLevel, unlocked: level),
                if (lastDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _fmtDate(lastDate),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.hintColor, fontSize: 10),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AchievementDetailSheet(def: def, controller: controller),
    );
  }
}

/// 数据源未接入标记
class _PendingTag extends StatelessWidget {
  const _PendingTag({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(140),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'achievement_pending'.tr,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 9,
          color: theme.hintColor,
        ),
      ),
    );
  }
}

/// 等级圆点列（Lv1~Lv5）
class _LevelDots extends StatelessWidget {
  const _LevelDots({required this.maxLevel, required this.unlocked});

  final int maxLevel;
  final int unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLevel, (i) {
        final level = i + 1;
        final isUnlocked = level <= unlocked;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUnlocked
                  ? AchievementLevels.borderColor(level)
                  : theme.colorScheme.surfaceContainerHighest,
              border: isUnlocked
                  ? null
                  : Border.all(color: theme.disabledColor.withAlpha(100), width: 1),
            ),
          ),
        );
      }),
    );
  }
}

/// 成就详情弹层：徽章 + 各等级阈值/积分/获得日期
class _AchievementDetailSheet extends StatelessWidget {
  const _AchievementDetailSheet({required this.def, required this.controller});

  final AchievementDefinition def;
  final AchievementController controller;

  static String _fmtDate(DateTime? d) => d == null
      ? ''
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = controller.progressOf(def.id);
    final level = progress.unlockedLevel;
    final revealed = !def.hidden || level > 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  AchievementBadge(iconAsset: def.iconAsset, level: level, size: 88),
                  const SizedBox(height: 12),
                  Text(
                    revealed ? def.name : '???',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    revealed
                        ? '${def.condition} · ${'achievement_unit'.tr}: ${def.unit}'
                        : 'achievement_hiddenHint'.tr,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 各等级明细
            ...List.generate(def.maxLevel, (i) {
              final lv = i + 1;
              final threshold = def.thresholds[i];
              final date = controller.unlockedDateOf(def.id, lv);
              final isUnlocked = date != null;
              final color = AchievementLevels.borderColor(lv);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? color.withAlpha(22)
                      : theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUnlocked ? color.withAlpha(120) : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isUnlocked ? color.withAlpha(50) : null,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Lv$lv',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isUnlocked ? color : theme.hintColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${def.condition} $threshold${def.unit}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isUnlocked
                              ? theme.colorScheme.onSurface
                              : theme.hintColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${def.rewardFor(lv)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 获得日期 / 未解锁
                    isUnlocked
                        ? Row(
                            children: [
                              Icon(Icons.event_available,
                                  size: 13, color: color),
                              const SizedBox(width: 3),
                              Text(
                                _fmtDate(date),
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: color),
                              ),
                            ],
                          )
                        : Icon(Icons.lock_outline,
                            size: 14, color: theme.disabledColor),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
