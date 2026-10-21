import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/achievement/controllers/achievement_controller.dart';
import 'package:aboutme/plugins/achievement/data/achievement_definitions.dart';
import 'package:aboutme/plugins/achievement/models/achievement_definition.dart';
import 'package:aboutme/widgets/pseudo_3d_flip_card.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 成就详情页：居中大徽章 + 达成信息 + 下一里程碑卡 + 各等级达成明细
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
            _buildHeader(context, theme, progress, level, revealed, maxed),
            if (!maxed) _buildMilestoneCard(theme, progress, level, nextThreshold!),
            if (maxed) _buildMaxedCard(theme, level),
            _buildLevelDetails(theme),
          ],
        ),
      ),
    );
  }

  /// 头部：大徽章 + 等级/未解锁 + 达成时间胶囊 + 标题 + 描述
  Widget _buildHeader(
    BuildContext context,
    AppThemeData theme,
    AchievementProgress progress,
    int level,
    bool revealed,
    bool maxed,
  ) {
    final lastDate = level > 0 ? controller.unlockedDateOf(def.id, level) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Pseudo3DFlipCard(
            image: AssetImage(def.iconAsset),
            width: 160,
            height: 160,
            thickness: 0,
            embossBack: false,
            mode: Pseudo3DMode.spin360,
          ),
          const SizedBox(height: 12),
          Text(
            level > 0 ? 'Lv$level' : 'achievement_locked'.tr,
            style: DsTypography.label.copyWith(
              fontSize: 12,
              letterSpacing: 3,
              color: level > 0 ? theme.primary : theme.textSub,
            ),
          ),
          if (lastDate != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: theme.surfaceAlt,
                radius: BorderRadius.circular(999),
                strokeWidth: 1.2,
                seed: 9,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DsIcon(
                    DsIconKind.calendarCheck,
                    size: 12,
                    color: theme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${'achievement_unlocked_at'.tr} ${_fmtDate(lastDate)}',
                    style: DsTypography.label.copyWith(
                      fontSize: 11,
                      color: theme.textSub,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            revealed ? def.name : '???',
            textAlign: TextAlign.center,
            style: DsTypography.heading.copyWith(
              fontSize: 24,
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
          if (kPendingAchievementIds.contains(def.id)) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: theme.surfaceAlt,
                radius: BorderRadius.circular(999),
                strokeWidth: 1,
                seed: 13,
              ),
              child: Text(
                'achievement_pending'.tr,
                style: DsTypography.label.copyWith(
                  fontSize: 10,
                  color: theme.textSub,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 下一里程碑卡：目标等级 + 条件 + 进度百分比
  Widget _buildMilestoneCard(
    AppThemeData theme,
    AchievementProgress progress,
    int level,
    int nextThreshold,
  ) {
    final ratio = (progress.value / nextThreshold).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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
                WiredIcon(
                  icon: Icons.emoji_events_outlined,
                  size: 16,
                  color: theme.primary,
                  drawConfig: theme.wired.drawConfig,
                ),
                const SizedBox(width: 8),
                Text(
                  'Lv${level + 1}',
                  style: DsTypography.button.copyWith(
                    fontSize: 14,
                    color: theme.text,
                  ),
                ),
                const Spacer(),
                Text(
                  'achievement_nextMilestone'.tr,
                  style: DsTypography.label.copyWith(
                    fontSize: 11,
                    color: theme.textSub,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${def.condition} $nextThreshold${def.unit}',
                    style: DsTypography.caption.copyWith(
                      color: theme.textSub,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(ratio * 100).round()}%',
                  style: DsTypography.title.copyWith(color: theme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DSLinearProgress(value: ratio, height: 8, color: theme.primary),
          ],
        ),
      ),
    );
  }

  /// 已满级卡：全部等级达成 + 最近达成时间
  Widget _buildMaxedCard(AppThemeData theme, int level) {
    final lastDate = controller.unlockedDateOf(def.id, level);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(14),
        seed: 5,
        child: Row(
          children: [
            WiredIcon(
              icon: Icons.emoji_events_outlined,
              size: 16,
              color: theme.primary,
              drawConfig: theme.wired.drawConfig,
            ),
            const SizedBox(width: 8),
            Text(
              'achievement_maxed'.tr,
              style: DsTypography.button.copyWith(
                fontSize: 14,
                color: theme.text,
              ),
            ),
            const Spacer(),
            if (lastDate != null)
              Text(
                _fmtDate(lastDate),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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
