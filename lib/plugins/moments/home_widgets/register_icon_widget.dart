/// 朋友圈插件 - 图标组件注册
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/screens/home_screen/widgets/generic_plugin_widget.dart';

/// 注册朋友圈图标小组件（1x1 简单图标组件）
void registerIconWidget(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'moments_icon',
      pluginId: 'moments',
      name: 'moments_widgetName'.tr,
      description: 'moments_widgetDescription'.tr,
      icon: Icons.photo_camera_outlined,
      color: const Color(0xFF0088FF),
      defaultSize: const SmallSize(),
      supportedSizes: [const SmallSize()],
      category: 'home_categoryRecord'.tr,
      builder:
          (context, config) => GenericIconWidget(
            icon: Icons.photo_camera_outlined,
            color: const Color(0xFF0088FF),
            name: 'moments_widgetName'.tr,
          ),
    ),
  );
}
