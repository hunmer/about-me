/// 圆盘插件启动器页面
///
/// 与插件列表对话框同源的插件启动入口（网格 → 手绘转轮）：
/// 拖动转轮浏览、点击图标直接打开对应插件；
/// 转轮可停靠在页面左半侧或右半侧（[direction]）。
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/arc_rotary_wheel_card.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

class RotaryPluginLauncherScreen extends StatefulWidget {
  const RotaryPluginLauncherScreen({
    super.key,
    this.direction = ArcWheelDirection.right,
    this.currentRouteName,
  });

  /// 圆盘停靠方向
  final ArcWheelDirection direction;

  /// 进入本页前的当前路由名（须在 push 前捕获），
  /// 用于点击插件时判断目标路由是否等于当前路由
  final String? currentRouteName;

  @override
  State<RotaryPluginLauncherScreen> createState() =>
      _RotaryPluginLauncherScreenState();
}

class _RotaryPluginLauncherScreenState
    extends State<RotaryPluginLauncherScreen> {
  List<PluginBase> get _plugins =>
      PluginManager.instance.getAllPlugins(sortByRecentlyOpened: true);

  void _openPlugin(PluginBase plugin) {
    // 先退出启动器页再打开插件，返回时不回到选择器（同插件列表对话框）
    Navigator.of(context).pop();
    if (widget.currentRouteName == '/plugin/${plugin.id}') return;
    PluginManager.instance.openPlugin(context, plugin);
  }

  @override
  Widget build(BuildContext context) {
    final plugins = _plugins;
    final hasPlugins = plugins.isNotEmpty;

    return SuperCupertinoNavigationWrapper(
      title: Text('core_pluginList'.tr),
      enableLargeTitle: false,
      body:
          hasPlugins
              ? Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: DSThemeBridge(
                      child: Builder(
                        builder: (context) {
                          final theme = AppTheme.of(context);
                          return Text(
                            'core_rotaryPluginHint'.tr,
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: ArcRotaryWheelSelector(
                      items: [
                        for (final plugin in plugins)
                          ArcWheelItemData(
                            id: plugin.id,
                            label: plugin.getPluginName(context) ?? plugin.id,
                            icon: plugin.icon ?? Icons.extension,
                            color: plugin.color,
                            value: plugin,
                          ),
                      ],
                      height: null,
                      direction: widget.direction,
                      onItemTap: (index) => _openPlugin(
                        plugins[index.clamp(0, plugins.length - 1)],
                      ),
                    ),
                  ),
                ],
              )
              : DSThemeBridge(
                child: Builder(
                  builder: (context) => Center(
                    child: DSEmptyState(
                      icon: DsIconKind.extension,
                      title: 'core_noMatchingPlugins'.tr,
                    ),
                  ),
                ),
              ),
    );
  }
}
