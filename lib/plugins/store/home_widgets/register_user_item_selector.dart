/// 积分商店插件 - 用户物品选择器注册（公共小组件）
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/screens/home_screen/widgets/base/live_selector_widget.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/common_widgets.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/store/store_plugin.dart';

/// 用户物品选择器小组件（基于 LiveSelectorWidget）
///
/// 默认显示 goodsItemSelector 公共小组件，支持实时更新
class _UserItemSelectorLiveWidget extends LiveSelectorWidget {
  const _UserItemSelectorLiveWidget({
    required super.config,
    required super.widgetDefinition,
  });

  @override
  List<String> get eventListeners => const [
    'store_cache_updated',
  ];

  @override
  Future<Map<String, Map<String, dynamic>>> getLiveData(Map<String, dynamic> config) async {
    return _provideCommonWidgets({});
  }

  @override
  String get widgetTag => 'UserItemSelectorWidget';

  @override
  Widget buildCommonWidget(
    BuildContext context,
    CommonWidgetId widgetId,
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return CommonWidgetBuilder.build(
      context,
      widgetId,
      props,
      size,
      inline: true,
    );
  }
}

/// 提供用户物品选择器公共小组件数据
Future<Map<String, Map<String, dynamic>>> _provideCommonWidgets(
  Map<String, dynamic> data,
) async {
  final plugin = PluginManager.instance.getPlugin('store') as StorePlugin?;
  if (plugin == null) return {};

  final controller = plugin.controller;
  final now = DateTime.now();

  // 默认显示前 3 个未过期物品（名称/图片走共用的商品基础数据）
  final displayedItems = controller.userItems
      .where((item) => item.expireDate.isAfter(now))
      .take(3)
      .map((item) {
        final remainingDays = item.expireDate.difference(now).inDays;

        return {
          'id': item.id,
          'productName': item.productName,
          'productImage': item.productImage,
          'purchasePrice': item.purchasePrice,
          'remaining': item.remaining,
          'expireDate': item.expireDate.toIso8601String(),
          'remainingDays': remainingDays,
          'isExpired': remainingDays < 0,
          'isExpiringSoon': remainingDays >= 0 && remainingDays <= 7,
        };
      })
      .toList();

  return {
    'storeUserItemSelector': {
      'items': displayedItems,
      'itemCount': displayedItems.length,
    },
  };
}

/// 注册用户物品选择器小组件（公共小组件，无配置）
void registerUserItemSelectorWidget(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'store_user_item_selector',
      pluginId: 'store',
      name: 'store_userItemQuickAccess'.tr,
      description: 'store_userItemQuickAccessDesc'.tr,
      icon: Icons.inventory_2,
      color: Colors.pinkAccent,
      defaultSize: const MediumSize(),
      supportedSizes: [const MediumSize(), const LargeSize()],
      category: 'home_categoryTools'.tr,
      commonWidgetsProvider: _provideCommonWidgets,
      builder: (context, config) {
        return _UserItemSelectorLiveWidget(
          config: _ensureConfigHasCommonWidget(config, CommonWidgetId.storeUserItemSelector),
          widgetDefinition: registry.getWidget('store_user_item_selector')!,
        );
      },
    ),
  );
}

/// 确保 config 包含默认的公共小组件配置
Map<String, dynamic> _ensureConfigHasCommonWidget(
  Map<String, dynamic> config,
  CommonWidgetId defaultWidgetId,
) {
  final newConfig = Map<String, dynamic>.from(config);
  if (!newConfig.containsKey('selectorWidgetConfig')) {
    newConfig['selectorWidgetConfig'] = {
      'commonWidgetId': defaultWidgetId.name,
      'usesCommonWidget': true,
      'commonWidgetProps': {},
    };
  }
  return newConfig;
}
