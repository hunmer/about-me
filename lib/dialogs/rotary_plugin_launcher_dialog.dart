import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/arc_rotary_wheel_card.dart';

/// 圆盘插件启动器：手绘弧形转轮选择并打开插件
///
/// 与 [showPluginListDialog] 同源的插件启动入口（网格 → 转轮），
/// 拖动转轮浏览、点击图标直接打开对应插件。
Future<void> showRotaryPluginLauncherDialog(
  BuildContext context, {
  bool sortByRecentlyOpened = true,
}) async {
  // showDialog 前捕获当前路由名（无名的 DialogRoute 会覆盖路由历史），
  // 用于点击插件时判断目标路由是否等于当前路由
  final currentRouteName = RouteHistoryManager.getCurrentContext()?.pageId;

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = AppTheme.of(context);
            final plugins = PluginManager.instance.getAllPlugins(
              sortByRecentlyOpened: sortByRecentlyOpened,
            );
            final screenWidth = MediaQuery.of(context).size.width;

            if (plugins.isEmpty) {
              return DsSketchPanel(
                theme: theme,
                radius: theme.radii.xxl,
                hachure: false,
                padding: const EdgeInsets.all(24),
                child: DSEmptyState(
                  icon: DsIconKind.extension,
                  title: 'core_noMatchingPlugins'.tr,
                ),
              );
            }

            final items = [
              for (final plugin in plugins)
                ArcWheelItemData(
                  id: plugin.id,
                  label: plugin.getPluginName(context) ?? plugin.id,
                  icon: plugin.icon ?? Icons.extension,
                  color: plugin.color,
                  value: plugin,
                ),
            ];

            void openPlugin(PluginBase plugin) {
              Navigator.of(dialogContext).pop();
              // 目标路由等于当前路由时无需跳转，只关对话框
              if (currentRouteName == '/plugin/${plugin.id}') return;
              PluginManager.instance.openPlugin(dialogContext, plugin);
            }

            return DsSketchPanel(
              theme: theme,
              radius: theme.radii.xxl,
              hachure: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 10, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'core_pluginList'.tr,
                            style: DsTypography.title.copyWith(
                              color: theme.text,
                            ),
                          ),
                        ),
                        DSIconButton(
                          icon: DsIconKind.close,
                          size: 36,
                          color: theme.surfaceAlt,
                          iconColor: theme.text,
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
                    child: Text(
                      'core_rotaryPluginHint'.tr,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: screenWidth * 0.8 > 340 ? 340 : screenWidth * 0.8,
                    child: ArcRotaryWheelSelector(
                      items: items,
                      height: 380,
                      onItemTap: (index) =>
                          openPlugin(plugins[index.clamp(0, plugins.length - 1)]),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
