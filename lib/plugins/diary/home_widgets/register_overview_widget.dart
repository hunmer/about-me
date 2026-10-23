/// 日记插件 - 概览组件注册
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/screens/home_screen/widgets/generic_plugin_widget.dart';
import 'package:aboutme/screens/home_screen/models/plugin_widget_config.dart';
import 'utils.dart';
import '../widgets/diary_query_guard.dart';
import '../models/diary_entry.dart';

/// 注册日记概览小组件（2x2 详细卡片 - 显示统计信息）
void registerOverviewWidget(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'diary_overview',
      pluginId: 'diary',
      name: 'diary_overviewName'.tr,
      description: 'diary_overviewDescription'.tr,
      icon: Icons.menu_book,
      color: Colors.indigo,
      defaultSize: const LargeSize(),
      supportedSizes: [const LargeSize()],
      category: 'home_categoryRecord'.tr,
      builder: (context, config) => DiarySnapshotBuilder(
        builder: (context, entries) =>
            _buildOverviewWidget(context, config, entries),
      ),
      availableStatsProvider: _getAvailableStats,
    ),
  );
}

/// 获取可用的统计项数据
List<StatItemData> _getAvailableStats(BuildContext context) {
  return getAvailableStats(context);
}

/// 构建 2x2 详细卡片组件
Widget _buildOverviewWidget(
  BuildContext context,
  Map<String, dynamic> config,
  Map<DateTime, DiaryEntry> entries,
) {
  try {
    // 解析插件配置
    PluginWidgetConfig widgetConfig;
    try {
      if (config.containsKey('pluginWidgetConfig')) {
        widgetConfig = PluginWidgetConfig.fromJson(
          config['pluginWidgetConfig'] as Map<String, dynamic>,
        );
      } else {
        widgetConfig = PluginWidgetConfig();
      }
    } catch (e) {
      widgetConfig = PluginWidgetConfig();
    }

    // 获取可用的统计项数据
    final availableItems = getAvailableStats(context, entries: entries);

    // 使用通用小组件
    return GenericPluginWidget(
      pluginId: 'diary',
      pluginName: 'diary_name'.tr,
      pluginIcon: Icons.menu_book,
      pluginDefaultColor: Colors.indigo,
      availableItems: availableItems,
      config: widgetConfig,
    );
  } catch (e) {
    return HomeWidget.buildErrorWidget(context, e.toString());
  }
}
