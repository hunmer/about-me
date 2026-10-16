import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/floating_ball/plugin_overlay_manager.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/route.dart';
import 'package:aboutme/screens/settings_screen/settings_screen.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 防重复弹窗标志位
bool _isDialogShowing = false;

class PluginListDialog extends StatefulWidget {
  final bool sortByRecentlyOpened;

  /// 对话框弹出时的当前路由名（须在 showDialog 前捕获：
  /// 无名的 DialogRoute 会把 RouteHistoryManager 的当前路由覆盖为 unknown），
  /// 用于点击插件时判断目标路由是否等于当前路由
  final String? currentRouteName;

  const PluginListDialog({
    super.key,
    this.sortByRecentlyOpened = true,
    this.currentRouteName,
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
            backgroundColor: AppTheme.of(context).background,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
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
        child: Text(
          'core_noMatchingPlugins'.tr,
          style: DsTypography.body.copyWith(
            color: AppTheme.of(context).textSub,
          ),
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

  // 构建插件卡片
  Widget _buildPluginCard(BuildContext context, PluginBase plugin) {
    final isPinned = PluginManager.instance.isPluginPinned(plugin.id);
    // 如果没有自定义卡片视图，使用默认卡片布局
    return GestureDetector(
      // 移动端长按 / 桌面端右键弹出操作菜单
      onLongPressStart: (details) =>
          _showPluginMenu(context, plugin, details.globalPosition),
      onSecondaryTapUp: (details) =>
          _showPluginMenu(context, plugin, details.globalPosition),
      child: Card(
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () {
            Navigator.of(context).pop();
            // 目标路由等于当前路由时无需跳转（openPlugin 内的防重复判断
            // 拿到的是对话框自己的 DialogRoute，此处无法生效），只关对话框
            if (widget.currentRouteName == '/plugin/${plugin.id}') {
              return;
            }
            PluginManager.instance.openPlugin(context, plugin);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 插件图标：图标颜色作背景，图标白色高亮
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: plugin.color ?? Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      plugin.icon ?? Icons.extension,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 插件名称
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      plugin.getPluginName(context) ?? plugin.id,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
                  top: 4,
                  left: 4,
                  child: Icon(
                    Icons.push_pin,
                    size: 14,
                    color: AppTheme.of(context).primary,
                  ),
                ),
              // 插件设置入口（仅有设置页面的插件显示）
              if (plugin.hasSettingsView)
                Positioned(
                  top: 0,
                  right: 0,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      icon: const Icon(Icons.settings),
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
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 长按卡片弹出操作菜单：固定/取消固定、小窗打开
  Future<void> _showPluginMenu(
    BuildContext cardContext,
    PluginBase plugin,
    Offset globalPosition,
  ) async {
    final overlay = Overlay.of(cardContext);
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final size = overlayBox.size;
    final position = RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      size.width - globalPosition.dx,
      size.height - globalPosition.dy,
    );

    final isPinned = PluginManager.instance.isPluginPinned(plugin.id);
    final result = await showMenu<String>(
      context: cardContext,
      position: position,
      items: [
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(Icons.push_pin, size: 18),
              const SizedBox(width: 8),
              Text(isPinned ? 'core_unpinPlugin'.tr : 'core_pinPlugin'.tr),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'overlay',
          child: Row(
            children: [
              Icon(Icons.picture_in_picture_alt, size: 18),
              const SizedBox(width: 8),
              Text('core_openInOverlay'.tr),
            ],
          ),
        ),
      ],
    );
    if (!mounted || result == null) return;

    switch (result) {
      case 'pin':
        PluginManager.instance.togglePluginPin(plugin.id);
        // 刷新列表，固定项移动到最前
        setState(() {});
        break;
      case 'overlay':
        Navigator.of(context).pop(); // 关闭插件列表对话框
        PluginOverlayManager().showPluginOverlay(context, plugin);
        break;
    }
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

  // showDialog 前捕获当前路由名，见 PluginListDialog.currentRouteName 注释
  final currentRouteName = RouteHistoryManager.getCurrentContext()?.pageId;

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => PluginListDialog(
      sortByRecentlyOpened: sortByRecentlyOpened,
      currentRouteName: currentRouteName,
    ),
  ).then((_) {
    // 对话框关闭时重置标志位
    _isDialogShowing = false;
  });
}
