import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/core/widgets/lazy_indexed_stack.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_store/app_store_screen.dart';
import 'components/webview_add_download_form.dart';
import 'components/webview_add_card_form.dart';
import 'download_records_screen.dart';
import 'webview_cards_screen.dart';

/// WebView 主界面 - 已安装 / 商店 / 下载管理 三页签宿主页
///
/// 弧形圆盘底部导航（design.md §3，仅根级宿主页放置）切换三个页签，
/// 页签首次访问时构建，之后保留状态。两个页签各自持有
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

  /// 停靠到子栏右圆钮位的浮动操作钮：等比缩到 35，与圆钮同尺寸
  Widget _dockFab(VoidCallback onPressed) {
    return SizedBox(
      width: 35,
      height: 35,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: DSFab(onPressed: onPressed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            // 内容延伸到导航栏下方，页签列表经 MediaQuery.padding.bottom 避让
            extendBody: true,
            backgroundColor: dsTransparentWhenGlobalBackground(theme.surface),
            body: LazyIndexedStack(
              index: _currentIndex,
              builders: [
                (_) => const WebViewCardsScreen(),
                (_) => const AppStoreScreen(),
                (_) => const DownloadRecordsScreen(),
              ],
            ),

            // 底部弧形导航：已安装 / 商店 / 下载管理
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
                  // 按 tab 停靠子栏右圆钮位的浮动操作钮：已安装/商店为
                  // 「添加卡片」，下载管理为「手动添加下载」。
                  // 本页无子栏胶囊，恒传 never 保持仅 dock 的紧凑占位
                  tabFloatingActions: [
                    _dockFab(() => showAddCardSheet(context)),
                    _dockFab(() => showAddCardSheet(context)),
                    _dockFab(() => showAddDownloadSheet(context)),
                  ],
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
                    DSNavItem(
                      icon: DsIconKind.download,
                      label: 'webview_tab_downloads'.tr,
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
