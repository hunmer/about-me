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
    this.autoOpen = false,
    this.currentRouteName,
  });

  /// 圆盘停靠方向
  final ArcWheelDirection direction;

  /// 放手后自动打开：拖动/滚轮松手转轮停稳后自动打开停住的插件
  final bool autoOpen;

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

  PluginBase _pluginAt(int index) =>
      _plugins[index.clamp(0, _plugins.length - 1)];

  void _openPlugin(PluginBase plugin) {
    if (!mounted) return;
    debugPrint('[圆盘启动器] 打开插件: ${plugin.id}');
    // 目标即来源路由：下层就是该插件页，直接返回即可
    if (widget.currentRouteName == '/plugin/${plugin.id}') {
      debugPrint('[圆盘启动器] 与来源路由相同，仅返回');
      Navigator.of(context).pop();
      return;
    }
    // 先在栈顶推出插件页（此时本页 context 仍存活），再把启动器路由
    // 从栈中移除——避免「先 pop 再用本页 context 推路由」的竞态，
    // 插件页返回时落在启动器的下层页面
    final navigator = Navigator.of(context);
    final launcherRoute = ModalRoute.of(context);
    PluginManager.instance.openPlugin(context, plugin);
    if (launcherRoute != null) {
      navigator.removeRoute(launcherRoute);
    }
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
                      onItemTap: (index) => _openPlugin(_pluginAt(index)),
                      onUserSettled:
                          widget.autoOpen
                              ? (index) => _openPlugin(_pluginAt(index))
                              : null,
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
