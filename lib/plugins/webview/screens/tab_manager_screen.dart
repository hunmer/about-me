import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../webview_plugin.dart';
import '../models/webview_tab.dart';
import '../services/tab_manager.dart';

/// 标签页管理界面
class TabManagerScreen extends StatelessWidget {
  const TabManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plugin = WebViewPlugin.instance;

    // Scaffold/AppBar 属结构性组件,刻意保留 Material
    return DSThemeBridge(
      child: ChangeNotifierProvider.value(
        value: plugin.tabManager,
        child: Builder(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(
                title: Text('webview_tab_manager'.tr),
                actions: [
                  // 关闭所有标签页(DS 按钮自带 DSThemeBridge 提供 AppTheme)
                  Consumer<TabManager>(
                    builder: (context, tabManager, _) {
                      if (tabManager.tabs.isEmpty) return const SizedBox();
                      final theme = DSThemeBridge.resolve(context);
                      return DSThemeBridge(
                        child: DSIconButton(
                          icon: DsIconKind.close,
                          size: 40,
                          color: theme.surfaceAlt,
                          iconColor: theme.textSub,
                          onPressed: () => _confirmCloseAll(context),
                          tooltip: 'webview_close_all_tabs'.tr,
                        ),
                      );
                    },
                  ),
                ],
              ),
              body: Consumer<TabManager>(
                builder: (context, tabManager, child) {
                  if (tabManager.tabs.isEmpty) {
                    return Center(
                      child: DSEmptyState(
                        emoji: '🗂️',
                        title: 'webview_no_tabs'.tr,
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _getCrossAxisCount(context),
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 12,
                      // ≥16：避免便签贴条出血被上一行遮挡
                      mainAxisSpacing: 16,
                    ),
                    itemCount:
                        tabManager.tabs.length + 1, // +1 for new tab button
                    itemBuilder: (context, index) {
                      if (index == tabManager.tabs.length) {
                        // 新建标签页按钮
                        return _buildNewTabButton(context);
                      }

                      final tab = tabManager.tabs[index];
                      return HandDrawnStickyItem(
                        tiltKey: tab.id,
                        child: _TabPreviewCard(
                          tab: tab,
                          isActive: tab.id == tabManager.activeTabId,
                          onTap: () {
                            tabManager.switchToTab(tab.id);
                            Navigator.pop(context);
                          },
                          onClose: () => _closeTab(context, tab.id),
                        ),
                      );
                    },
                  );
                },
              ),
              floatingActionButton: DSFab(
                icon: DsIconKind.plus,
                onPressed: () => _createNewTab(context),
              ),
            );
          },
        ),
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 5;
    if (width > 900) return 4;
    if (width > 600) return 3;
    return 2;
  }

  Widget _buildNewTabButton(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: () => _createNewTab(context),
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return JellyBox(
          radius: theme.radii.xl,
          raised: false,
          color: pressed ? theme.primary.mixWhite(0.9) : null,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DsIcon(DsIconKind.plus, size: 48, color: theme.textSub),
                SizedBox(height: theme.spacing.sm),
                Text(
                  'webview_new_tab'.tr,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createNewTab(BuildContext context) async {
    final plugin = WebViewPlugin.instance;

    if (!plugin.tabManager.canAddTab) {
      Toast.warning('webview_max_tabs_reached'.tr);
      return;
    }

    await plugin.tabManager.createTab(
      url: 'about:blank',
      title: '新标签页',
      setActive: true,
    );

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _closeTab(BuildContext context, String tabId) async {
    final plugin = WebViewPlugin.instance;
    await plugin.tabManager.closeTab(tabId);

    if (plugin.tabManager.tabs.isEmpty && context.mounted) {
      Navigator.pop(context);
      Navigator.pop(context); // 也退出浏览器界面
    }
  }

  Future<void> _confirmCloseAll(BuildContext context) async {
    final confirm = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (ctx) => DSThemeBridge(
            child: Builder(
              builder:
                  (ctx) => DSDialog(
                    title: 'webview_close_all_tabs'.tr,
                    message: 'webview_confirm_close_all'.tr,
                    confirmText: 'app_confirm'.tr,
                    cancelText: 'app_cancel'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onConfirm: () => Navigator.of(ctx).pop(true),
                    onCancel: () => Navigator.of(ctx).pop(false),
                  ),
            ),
          ),
    );

    if (confirm == true) {
      await WebViewPlugin.instance.tabManager.closeAllTabs();
      if (context.mounted) {
        Navigator.pop(context);
        Navigator.pop(context); // 也退出浏览器界面
      }
    }
  }
}

/// 标签页预览卡片
class _TabPreviewCard extends StatelessWidget {
  final WebViewTab tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabPreviewCard({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Material(
      color: isActive ? theme.primary.withValues(alpha: 0.1) : theme.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? theme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部栏（标题和关闭按钮）
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.backgroundAlt,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
                child: Row(
                  children: [
                    // Favicon(DS 暂无网页图标,回退保留 Material)
                    if (tab.favicon != null && tab.favicon!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Image.network(
                          tab.favicon!,
                          width: 16,
                          height: 16,
                          errorBuilder:
                              (_, __, ___) =>
                                  const Icon(Icons.language, size: 16),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.language, size: 16),
                      ),

                    // 标题
                    Expanded(
                      child: Text(
                        tab.title.isNotEmpty ? tab.title : '新标签页',
                        style: DsTypography.caption.copyWith(
                          color: theme.text,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // 关闭按钮
                    InkWell(
                      onTap: onClose,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: DsIcon(
                          DsIconKind.close,
                          size: 16,
                          color: theme.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 预览区域
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.background,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(10),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // DS 暂无网页/地球图标,保留 Material
                        Icon(Icons.language, size: 48, color: theme.textSub),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            _getDisplayUrl(tab.url),
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDisplayUrl(String url) {
    if (url == 'about:blank') return '新标签页';
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return url;
    }
  }
}
