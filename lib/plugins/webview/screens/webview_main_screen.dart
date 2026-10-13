import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_store/app_store_screen.dart';
import 'webview_cards_screen.dart';

/// WebView 主界面 - 已安装 / 商店 双页签宿主页
///
/// 弧形圆盘底部导航（design.md §3，仅根级宿主页放置）切换两个页签，
/// IndexedStack 保留各页签状态。两个页签各自持有
/// SuperCupertinoNavigationWrapper，内层（商店）须传
/// transitionBetweenRoutes:false，避免与外层导航栏 hero tag 冲突
/// （design.md §1）。
///
/// AppStoreManager / DownloadManager 等Provider由
/// WebViewPlugin.buildMainView 顶层 MultiProvider 提供，页签内直接读取。
class WebViewMainScreen extends StatefulWidget {
  const WebViewMainScreen({super.key});

  @override
  State<WebViewMainScreen> createState() => _WebViewMainScreenState();
}

class _WebViewMainScreenState extends State<WebViewMainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            // 内容延伸到导航栏下方，页签列表经 MediaQuery.padding.bottom 避让
            extendBody: true,
            backgroundColor: theme.surface,
            body: IndexedStack(
              index: _currentIndex,
              children: const [
                WebViewCardsScreen(),
                AppStoreScreen(),
              ],
            ),

            // 底部弧形导航：已安装 / 商店
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.all(theme.spacing.lg),
                child: DSBottomNavigation(
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  // 子栏右侧圆钮：添加卡片/本地项目（无子栏胶囊，
                  // 恒传 never 保持仅 dock 的紧凑占位）
                  trailingAction: DsIcon(
                    DsIconKind.plus,
                    size: 16,
                    color: theme.primary,
                  ),
                  onTrailingTap: () => showAddCardDialog(context),
                  subBarBehavior: RadialSubBarBehavior.never,
                  items: [
                    DSNavItem(
                      icon: DsIconKind.grid,
                      label: 'webview_tab_installed'.tr,
                    ),
                    DSNavItem(
                      icon: DsIconKind.store,
                      label: 'webview_tab_store'.tr,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
