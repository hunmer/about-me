/// Live2D 插件 - 图标组件注册
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/screens/home_screen/widgets/generic_plugin_widget.dart';

/// 注册 Live2D 图标小组件（1x1 简单图标组件）
void registerIconWidget(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'live2d_icon',
      pluginId: 'live2d',
      name: 'Live2D',
      description: 'live2d_settingsTitle'.tr,
      icon: Icons.face_retouching_natural,
      color: Colors.pink,
      defaultSize: const SmallSize(),
      supportedSizes: [const SmallSize()],
      category: 'home_categoryTools'.tr,
      builder:
          (context, config) => GenericIconWidget(
            icon: Icons.face_retouching_natural,
            color: Colors.pink,
            name: 'Live2D',
          ),
    ),
  );
}
