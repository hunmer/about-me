/// 目标选择器小组件（显示单个目标的详细信息和进度）
library;

import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/services/plugin_data_selector/models/selector_result.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/widgets/event_listener_container.dart';
import '../../tracker_plugin.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 渲染目标数据
Widget renderGoalData(
  BuildContext context,
  SelectorResult result,
  Map<String, dynamic> config,
) {
  // 从初始化数据中获取目标ID
  final goalData = result.data as Map<String, dynamic>;
  final goalId = goalData['id'] as String?;

  if (goalId == null) {
    return HomeWidget.buildErrorWidget(context, 'tracker_goalNotFound'.tr);
  }

  // 使用 StatefulBuilder 和 EventListenerContainer 实现动态更新
  return StatefulBuilder(
    builder: (context, setState) {
      return EventListenerContainer(
        events: const ['tracker_record_added'],
        onEvent: () => setState(() {}),
        child: TrackerGoalSelectorWidget(goalId: goalId),
      );
    },
  );
}

/// 目标选择器小组件组件
class TrackerGoalSelectorWidget extends StatelessWidget {
  final String goalId;

  const TrackerGoalSelectorWidget({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // 主页小组件容器内无 AppTheme，DS 组件先过桥
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          // 从 PluginManager 获取最新的目标数据
          final plugin =
              PluginManager.instance.getPlugin('tracker') as TrackerPlugin?;
          if (plugin == null) {
            return HomeWidget.buildErrorWidget(
              context,
              'tracker_pluginNotAvailable'.tr,
            );
          }

          // 查找对应目标
          final goal = plugin.controller.goals.firstWhere(
            (g) => g.id == goalId,
            orElse: () => throw Exception('tracker_goalNotFound'.tr),
          );

          // 使用最新的目标数据
          final name = goal.name;
          final currentValue = goal.currentValue;
          final targetValue = goal.targetValue;
          final unitType = goal.unitType;
          final iconCode = goal.icon;
          final iconColorValue = goal.iconColor;

          final progress = (targetValue > 0 ? (currentValue / targetValue) : 0)
              .clamp(0.0, 1.0);
          final goalColor = Color(iconColorValue ?? 4283215696);

          return Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 目标名称和图标
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: goalColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      // goal.icon 为持久化 codePoint 字符串，保留 Material IconData
                      child: Icon(
                        dynamicIconData(
                          int.tryParse(iconCode) ?? 57455,
                          fontFamily: 'MaterialIcons',
                        ),
                        color: goalColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: DsTypography.heading.copyWith(
                              color: theme.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$currentValue / $targetValue $unitType',
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 进度条和百分比
                Row(
                  children: [
                    Expanded(
                      child: DSLinearProgress(
                        value: progress.toDouble(),
                        height: 8,
                        color: goalColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: DsTypography.caption.copyWith(
                        color: progress >= 1.0 ? theme.success : goalColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
