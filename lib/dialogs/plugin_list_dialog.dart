import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/floating_ball/plugin_overlay_manager.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/route.dart';
import 'package:aboutme/screens/settings_screen/settings_screen.dart';
import 'package:aboutme/widgets/arc_context_menu.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 防重复弹窗标志位
bool _isDialogShowing = false;

class PluginListDialog extends StatefulWidget {
  final bool sortByRecentlyOpened;

  const PluginListDialog({
    super.key,
    this.sortByRecentlyOpened = true,
  });

  @override
  State<PluginListDialog> createState() => _PluginListDialogState();
}

class _PluginListDialogState extends State<PluginListDialog> {
  /// 当前搜索关键词
  String _searchQuery = '';

  /// 全部插件（已固定的按固定时间置顶）
  List<PluginBase> get _allPlugins => PluginManager.instance.getAllPlugins(
    sortByRecentlyOpened: widget.sortByRecentlyOpened,
  );

  /// 按名称/ID过滤后的插件列表
  List<PluginBase> _filterPlugins(List<PluginBase> plugins) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return plugins;
    return plugins.where((plugin) {
      final name = (plugin.getPluginName(context) ?? '').toLowerCase();
      return name.contains(query) || plugin.id.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // 获取屏幕宽度以计算合适的网格列数
    final screenWidth = MediaQuery.of(context).size.width;
    // 根据屏幕宽度计算合适的网格列数
    final crossAxisCount = (screenWidth / 120).floor().clamp(2, 5);

    return Dialog(
      child: Container(
        width: screenWidth * 0.85,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        // 去掉状态栏内边距，避免对话框内的导航栏被顶下来
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: SuperCupertinoNavigationWrapper(
            title: Text('core_pluginList'.tr),
            enableLargeTitle: false,
            enableSearchBar: true,
            searchPlaceholder: 'core_search'.tr,
            onSearchChanged: (query) => setState(() => _searchQuery = query),
            automaticallyImplyLeading: false,
            // 对话框叠在可能同样使用本组件的页面之上，必须关掉 Hero 转场
            transitionBetweenRoutes: false,
            stretch: false,
            // 对话框场景不透出全局自定义背景
            backgroundColor: theme.background,
            actions: [
              DSIconButton(
                icon: DsIconKind.gear,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.text,
                tooltip: 'app_settings'.tr,
                onPressed: () {
                  Navigator.of(context).pop();
                  NavigationHelper.push(
                    context,
                    const SettingsScreen(),
                    routeName: AppRoutes.settings,
                  );
                },
              ),
            ],
            body: _buildPluginGrid(context, _allPlugins, crossAxisCount),
            searchBody: _buildSearchBody(context, crossAxisCount),
          ),
        ),
      ),
    );
  }

  /// 搜索态内容：有过滤结果时显示网格，否则显示空态
  Widget _buildSearchBody(BuildContext context, int crossAxisCount) {
    final filtered = _filterPlugins(_allPlugins);
    if (filtered.isEmpty) {
      return Center(
        child: DSEmptyState(
          icon: DsIconKind.search,
          title: 'core_noMatchingPlugins'.tr,
        ),
      );
    }
    return _buildPluginGrid(context, filtered, crossAxisCount);
  }

  // 构建插件网格
  Widget _buildPluginGrid(
    BuildContext context,
    List<PluginBase> plugins,
    int crossAxisCount,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: plugins.length,
      itemBuilder: (context, index) =>
          _buildPluginCard(context, plugins[index]),
    );
  }

  // 构建插件卡片：手绘卡片 + 墨线圆形图标 + 挂载描画入场
  Widget _buildPluginCard(BuildContext context, PluginBase plugin) {
    final theme = AppTheme.of(context);
    final isPinned = PluginManager.instance.isPluginPinned(plugin.id);
    // 移动端长按弹圆盘快捷菜单（固定/浮窗）；桌面端右键直接弹完整 sheet
    return GestureDetector(
      onSecondaryTapUp: (_) => _showPluginMenu(context, plugin),
      child: ArcContextMenu.actions(
        actions: [
          ArcMenuItem(
            icon: DsIconKind.pin,
            label: isPinned ? 'core_unpinPlugin'.tr : 'core_pinPlugin'.tr,
            onTap: () {
              PluginManager.instance.togglePluginPin(plugin.id);
              // 刷新列表，固定项移动到最前
              setState(() {});
            },
          ),
          ArcMenuItem(
            icon: DsIconKind.pictureInPicture,
            label: 'core_openInOverlay'.tr,
            onTap: () {
              Navigator.of(context).pop(); // 关闭插件列表对话框
              PluginOverlayManager().showPluginOverlay(context, plugin);
            },
          ),
        ],
        showMore: () => _showPluginMenu(context, plugin),
        child: WiredDraw(
        child: DSCard(
          padding: const EdgeInsets.all(6),
          onTap: () {
            Navigator.of(context).pop();
            // 目标即当前插件页时 openPlugin 内部会自行短路，只关对话框
            PluginManager.instance.openPlugin(context, plugin);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 插件图标：插件色实底圆盘 + 墨线抖动描边
                  Container(
                    width: 48,
                    height: 48,
                    decoration: dsSketchDecoration(
                      theme: theme,
                      fillColor: plugin.color ?? theme.primary,
                      circle: true,
                    ),
                    // plugin.icon 为插件自定义的 Material IconData，
                    // 无法映射到 DsIconKind，保持 Icon 渲染
                    child: Icon(
                      plugin.icon ?? Icons.extension,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 插件名称
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Text(
                      plugin.getPluginName(context) ?? plugin.id,
                      style: DsTypography.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.text,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // 固定标识
              if (isPinned)
                Positioned(
                  top: 2,
                  left: 4,
                  child: DsIcon(
                    DsIconKind.pin,
                    size: 16,
                    color: theme.primary,
                  ),
                ),
              // 插件设置入口（仅有设置页面的插件显示）
              if (plugin.hasSettingsView)
                Positioned(
                  top: 2,
                  right: 2,
                  child: DSIconButton(
                    icon: DsIconKind.gear,
                    size: 30,
                    color: theme.surfaceAlt,
                    iconColor: theme.textSub,
                    tooltip: 'app_settings'.tr,
                    onPressed: () {
                      Navigator.of(context).pop();
                      NavigationHelper.push(
                        context,
                        plugin.buildSettingsView(context),
                        routeName: '/plugin/${plugin.id}/settings',
                      );
                    },
                  ),
                ),
             ],
           ),
         ),
       ),
      ),
     );
   }

  /// 长按卡片弹出快捷操作面板：固定/取消固定、小窗打开
  Future<void> _showPluginMenu(BuildContext cardContext, PluginBase plugin) {
    final isPinned = PluginManager.instance.isPluginPinned(plugin.id);
    return SmoothBottomSheet.showWithTitle(
      context: cardContext,
      title: plugin.getPluginName(cardContext) ?? plugin.id,
      child: Builder(builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SmoothSheetAction(
            icon: DsIconKind.pin,
            label: isPinned ? 'core_unpinPlugin'.tr : 'core_pinPlugin'.tr,
            onTap: () {
              Navigator.of(sheetContext).pop();
              PluginManager.instance.togglePluginPin(plugin.id);
              // 刷新列表，固定项移动到最前
              setState(() {});
            },
          ),
          SmoothSheetAction(
            icon: DsIconKind.pictureInPicture,
            label: 'core_openInOverlay'.tr,
            onTap: () {
              Navigator.of(sheetContext).pop(); // 关闭操作面板
              Navigator.of(context).pop(); // 关闭插件列表对话框
              PluginOverlayManager().showPluginOverlay(context, plugin);
            },
          ),
        ],
      )),
    );
  }
}

/// 显示插件列表对话框
void showPluginListDialog(
  BuildContext context, {
  bool sortByRecentlyOpened = true,
}) {
  // 检查是否已经有对话框打开，避免重复弹窗
  if (_isDialogShowing) {
    print('[插件列表对话框] 对话框已在显示中，跳过重复打开');
    return;
  }

  _isDialogShowing = true;

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => PluginListDialog(
      sortByRecentlyOpened: sortByRecentlyOpened,
    ),
  ).then((_) {
    // 对话框关闭时重置标志位
    _isDialogShowing = false;
  });
}
