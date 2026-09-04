import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/screens/jelly_home/companion_controller.dart';

/// 小智的陪伴状态卡：情绪 / 精力 / 好感度 / 陪伴天数（2×2 数值格）
///
/// 点击卡片算一次互动：情绪 +2、好感度 +2（受每日上限约束）。
class JellyCompanionCard extends StatelessWidget {
  const JellyCompanionCard({super.key, required this.controller});

  final CompanionController controller;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return ListenableBuilder(
      listenable: controller,
      builder:
          (context, _) => Pressable(
            onPressed: () => controller.recordInteraction(),
            semanticLabel: '和小智互动',
            builder:
                (context, states) => Opacity(
                  opacity: states.contains(WidgetState.pressed) ? 0.88 : 1,
                  child: JellyBox(
                    radius: theme.radii.xl,
                    padding: EdgeInsets.all(theme.spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            DsIcon(
                              DsIconKind.bot,
                              size: 15,
                              color: theme.primary,
                            ),
                            SizedBox(width: theme.spacing.sm),
                            Text(
                              '小智状态',
                              style: DsTypography.heading.copyWith(
                                fontSize: 14,
                                color: theme.primaryText,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${controller.moodTier.emoji} ${controller.moodTier.label} · '
                              '戳一戳互动',
                              style: DsTypography.label.copyWith(
                                fontSize: 10,
                                color: theme.textSub,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: theme.spacing.md),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _StatTile(
                                icon: DsIconKind.heart,
                                iconColor: theme.secondary,
                                label: '情绪 · ${controller.moodTier.label}',
                                progress: controller.mood / 100,
                                progressColor: switch (controller.moodTier) {
                                  CompanionMoodTier.delighted ||
                                  CompanionMoodTier.calm => theme.secondary,
                                  CompanionMoodTier.neutral => theme.warning,
                                  CompanionMoodTier.gloomy => theme.danger,
                                },
                                value: '${controller.mood}/100',
                              ),
                            ),
                            SizedBox(width: theme.spacing.md),
                            Expanded(
                              child: _StatTile(
                                icon: DsIconKind.sun,
                                iconColor: theme.success,
                                label: '精力 · ${controller.energyTier.label}',
                                progress: controller.energy / 100,
                                progressColor: switch (controller.energyTier) {
                                  CompanionEnergyTier.full ||
                                  CompanionEnergyTier.good => theme.success,
                                  CompanionEnergyTier.tired => theme.warning,
                                  CompanionEnergyTier.drained => theme.danger,
                                },
                                value: '${controller.energy}/100',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: theme.spacing.md),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _StatTile(
                                icon: DsIconKind.star,
                                iconColor: theme.primary,
                                label:
                                    '好感 · ${controller.affectionTier.label}',
                                progress: controller.affectionTierProgress,
                                progressColor: theme.primary,
                                value:
                                    '${controller.affection} 点'
                                    '${controller.affectionRemainingToday > 0 ? '（今日还可 +${controller.affectionRemainingToday}）' : '（今日已满）'}',
                              ),
                            ),
                            SizedBox(width: theme.spacing.md),
                            Expanded(
                              child: _StatTile(
                                icon: DsIconKind.clock,
                                iconColor: theme.warning,
                                label: '陪伴 · 连续 ${controller.companionStreak} 天',
                                progress: null,
                                progressColor: theme.warning,
                                value: '累计 ${controller.totalCompanionDays} 天',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }
}

/// 单个数值格：图标标签行 + 进度条 + 数值（progress 为 null 时不显示进度条）
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.progressColor,
    required this.value,
    this.progress,
  });

  final DsIconKind icon;
  final Color iconColor;
  final String label;
  final double? progress;
  final Color progressColor;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DsIcon(icon, size: 13, color: iconColor),
            SizedBox(width: theme.spacing.xs),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 1,
                  style: DsTypography.label.copyWith(
                    fontSize: 10,
                    color: theme.textSub,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (progress case final double p) ...[
          SizedBox(height: theme.spacing.xs + 2),
          DSLinearProgress(value: p, height: 8, color: progressColor),
        ],
        SizedBox(height: theme.spacing.xs + 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: DsTypography.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.text,
            ),
          ),
        ),
      ],
    );
  }
}
