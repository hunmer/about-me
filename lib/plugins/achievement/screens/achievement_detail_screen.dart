import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/achievement/controllers/achievement_controller.dart';
import 'package:aboutme/plugins/achievement/data/achievement_definitions.dart';
import 'package:aboutme/plugins/achievement/models/achievement_definition.dart';
import 'package:aboutme/plugins/achievement/widgets/achievement_badge.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 成就详情页：徽章大图 + 当前进度面板 + 各等级达成明细
class AchievementDetailScreen extends StatelessWidget {
  const AchievementDetailScreen({
    super.key,
    required this.def,
    required this.controller,
  });

  final AchievementDefinition def;
  final AchievementController controller;

  static String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final progress = controller.progressOf(def.id);
    final level = progress.unlockedLevel;
    final revealed = !def.hidden || level > 0;
    final maxed = level >= def.maxLevel;
    final nextThreshold = maxed ? null : def.thresholds[level];
    final title = revealed ? def.name : '???';
    final category = kAchievementCategories.firstWhere(
      (c) => c.id == def.category,
    );

    return SuperCupertinoNavigationWrapper(
      title: Text(title),
      largeTitle: title,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, theme, category, level, revealed),
            _buildProgressPanel(theme, progress, level, maxed, nextThreshold),
            _buildLevelDetails(theme),
          ],
        ),
      ),
    );
  }

  /// 头部：徽章 + 名称 + 条件 + 分类/隐藏/待接入标签
  Widget _buildHeader(
    BuildContext context,
    AppThemeData theme,
    AchievementCategory category,
    int level,
    bool revealed,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          AchievementBadge(iconAsset: def.iconAsset, level: level, size: 96),
          const SizedBox(height: 14),
          Text(
            revealed ? def.name : '???',
            textAlign: TextAlign.center,
            style: DsTypography.heading.copyWith(
              fontSize: 22,
              color: theme.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            revealed
                ? '${def.condition} · ${'achievement_unit'.tr}: ${def.unit}'
                : 'achievement_hiddenHint'.tr,
            textAlign: TextAlign.center,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _TagPill(
                theme: theme,
                seed: 9,
                children: [
                  WiredIcon(
                    icon: category.icon,
                    size: 13,
                    color: theme.primary,
                    drawConfig: theme.wired.drawConfig,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    category.nameKey.tr,
                    style: DsTypography.label.copyWith(
                      fontSize: 11,
                      color: theme.textSub,
                    ),
                  ),
                ],
              ),
              if (def.hidden)
                _TagPill(
                  theme: theme,
                  seed: 13,
                  children: [
                    DsIcon(DsIconKind.eyeOff, size: 13, color: theme.textSub),
                    const SizedBox(width: 4),
                    Text(
                      'achievement_hiddenHint'.tr,
                      style: DsTypography.label.copyWith(
                        fontSize: 11,
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ),
              if (kPendingAchievementIds.contains(def.id))
                _TagPill(
                  theme: theme,
                  seed: 21,
                  children: [
                    Text(
                      'achievement_pending'.tr,
                      style: DsTypography.label.copyWith(
                        fontSize: 11,
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 当前进度面板
  Widget _buildProgressPanel(
    AppThemeData theme,
    AchievementProgress progress,
    int level,
    bool maxed,
    int? nextThreshold,
  ) {
    final ratio = maxed
        ? 1.0
        : (progress.value / nextThreshold!).clamp(0.0, 1.0);
    final lastDate = level > 0 ? controller.unlockedDateOf(def.id, level) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(14),
        seed: 5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'achievement_detailCurrentProgress'.tr,
                  style:
                      DsTypography.heading.copyWith(color: theme.text),
                ),
                const Spacer(),
                Text(
                  maxed
                      ? 'achievement_maxed'.tr
                      : '${progress.value} / $nextThreshold${def.unit}',
                  style: DsTypography.title.copyWith(color: theme.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DSLinearProgress(
              value: ratio,
              height: 12,
              thumb: DsIcon(DsIconKind.star, size: 22, color: theme.primary),
            ),
            const SizedBox(height: 10),
            Text(
              maxed
                  ? (lastDate != null
                      ? '${'achievement_unlocked_at'.tr} ${_fmtDate(lastDate)}'
                      : '')
                  : '${'achievement_nextLevel'.tr}: ${def.condition} $nextThreshold${def.unit}',
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
        ),
      ),
    );
  }

  /// 等级明细：Lv1~LvN 各级阈值 / 积分 / 达成日期
  Widget _buildLevelDetails(AppThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'achievement_detailLevelDetails'.tr,
            style: DsTypography.heading.copyWith(color: theme.text),
          ),
          const SizedBox(height: 10),
          ...List.generate(def.maxLevel, (i) {
            final lv = i + 1;
            final threshold = def.thresholds[i];
            final date = controller.unlockedDateOf(def.id, lv);
            final isUnlocked = date != null;
            final color = AchievementLevels.borderColor(lv);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: isUnlocked
                    ? color.withValues(alpha: 0.14)
                    : theme.surfaceAlt.withValues(alpha: 0.5),
                stroke: isUnlocked ? color : null,
                radius: BorderRadius.circular(14),
                strokeWidth: 1.6,
                seed: lv + 20,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: dsSketchDecoration(
                      theme: theme,
                      fillColor: isUnlocked
                          ? color.withValues(alpha: 0.25)
                          : theme.surfaceAlt,
                      stroke: isUnlocked ? color : null,
                      radius: BorderRadius.circular(999),
                      strokeWidth: 1.2,
                      seed: lv + 40,
                    ),
                    child: Text(
                      'Lv$lv',
                      style: DsTypography.label.copyWith(
                        fontSize: 11,
                        color: isUnlocked ? color : theme.textSub,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${def.condition} $threshold${def.unit}',
                      style: DsTypography.body.copyWith(
                        fontSize: 13,
                        color: isUnlocked ? theme.text : theme.textSub,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+${def.rewardFor(lv)}',
                    style: DsTypography.button.copyWith(
                      fontSize: 12,
                      color: theme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  isUnlocked
                      ? Row(
                          children: [
                            DsIcon(
                              DsIconKind.calendarCheck,
                              size: 13,
                              color: color,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _fmtDate(date),
                              style: DsTypography.label.copyWith(
                                fontSize: 11,
                                color: color,
                              ),
                            ),
                          ],
                        )
                      : DsIcon(
                          DsIconKind.lock,
                          size: 14,
                          color: theme.disabled,
                        ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// 详情页标签 pill：纯色实底 + 细墨线
class _TagPill extends StatelessWidget {
  const _TagPill({required this.theme, required this.seed, required this.children});

  final AppThemeData theme;
  final int seed;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.hatch.withValues(alpha: 0.4),
        radius: BorderRadius.circular(999),
        strokeWidth: 1.2,
        seed: seed,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
