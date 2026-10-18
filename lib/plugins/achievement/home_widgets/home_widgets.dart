/// 成就插件 - 主页小组件
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
export 'register_icon_widget.dart';

import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/achievement/achievement_plugin.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/widgets/event_listener_container.dart';
import 'register_icon_widget.dart';

/// 注册成就插件的主页小组件
void register() {
  final registry = HomeWidgetRegistry();
  registerIconWidget(registry);
  registry.register(
    HomeWidget(
      id: 'achievement_overview',
      pluginId: 'achievement',
      name: 'achievement_name'.tr,
      description: 'achievement_overviewWidgetDescription'.tr,
      icon: Icons.emoji_events_outlined,
      color: const Color(0xFFE6A817),
      defaultSize: const SmallSize(),
      supportedSizes: const [SmallSize(), MediumSize()],
      category: 'home_categoryTools'.tr,
      builder: (context, config) => buildAchievementOverviewWidget(context, config),
    ),
  );
}

/// 成就概览卡片：解锁进度环 + 累计积分 + 最近达成
Widget buildAchievementOverviewWidget(
  BuildContext context,
  Map<String, dynamic> config,
) {
  final plugin = PluginManager.instance.getPlugin('achievement');
  if (plugin is! AchievementPlugin) {
    return HomeWidget.buildErrorWidget(context, 'AchievementPlugin not ready');
  }
  final controller = plugin.controller;
  final theme = Theme.of(context);

  return EventListenerContainer(
    events: const ['achievement_level_up', 'store_cache_updated'],
    onEvent: () {},
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final unlocked = controller.unlockedLevels;
        final total = controller.totalLevels;
        final progress = controller.overallProgress;

        return InkWell(
          onTap: () => PluginManager.instance.openPlugin(context, plugin),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(70),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events_outlined,
                        size: 18, color: plugin.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'achievement_name'.tr,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$unlocked/$total',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: plugin.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // 进度环
                Expanded(
                  child: Center(
                    child: SizedBox.expand(
                      child: CustomPaint(
                        painter: _ProgressRingPainter(
                          progress: progress,
                          color: plugin.color,
                          trackColor: theme
                              .colorScheme.surfaceContainerHighest,
                          strokeWidth: 8,
                        ),
                        child: Center(
                          child: Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.stars, size: 13, color: theme.hintColor),
                    const SizedBox(width: 3),
                    Text(
                      '+${controller.totalEarnedPoints}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.hintColor),
                    ),
                    const Spacer(),
                    Icon(Icons.emoji_events, size: 13, color: plugin.color),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        controller.lastUnlockedAt == null
                            ? 'achievement_none'.tr
                            : '${controller.lastUnlockedAt!.month}/${controller.lastUnlockedAt!.day}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.hintColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// 圆环进度画笔
class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    this.strokeWidth = 8,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = size.shortestSide / 2 - strokeWidth / 2;
    final center = rect.center;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
