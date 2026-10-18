/// 成就插件 - 图标组件注册
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/screens/home_screen/widgets/generic_plugin_widget.dart';

/// 注册成就图标小组件（1x1 简单图标组件）
void registerIconWidget(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'achievement_icon',
      pluginId: 'achievement',
      name: 'achievement_widgetName'.tr,
      description: 'achievement_widgetDescription'.tr,
      icon: Icons.emoji_events_outlined,
      color: const Color(0xFFE6A817),
      defaultSize: const SmallSize(),
      supportedSizes: [const SmallSize()],
      category: 'home_categoryTools'.tr,
      builder:
          (context, config) => GenericIconWidget(
            icon: Icons.emoji_events_outlined,
            color: const Color(0xFFE6A817),
            name: 'achievement_widgetName'.tr,
          ),
    ),
  );
}
