import 'dart:async';
import 'dart:collection';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../webview_plugin.dart';
import '../models/webview_tab.dart';
import '../models/webview_card.dart';
import '../services/tab_manager.dart';
import '../services/js_bridge_injector.dart';
import '../services/download_flow.dart';
import '../services/webview_download_interceptor.dart';
import '../widgets/download_records_list.dart';
import 'tab_manager_screen.dart';

/// WebView 浏览器界面
class WebViewBrowserScreen extends StatefulWidget {
  final String? initialUrl;
  final String? initialTitle;
  final String? cardId;
  final bool hideUI;

  const WebViewBrowserScreen({
    super.key,
    this.initialUrl,
    this.initialTitle,
    this.cardId,
    this.hideUI = false,
  });

  @override
  State<WebViewBrowserScreen> createState() => _WebViewBrowserScreenState();
}

class _WebViewBrowserScreenState extends State<WebViewBrowserScreen> {
  final TextEditingController _urlController = TextEditingController();

  WebViewTab? _currentTab;
  bool _isUrlBarFocused = false;

  @override
  void initState() {
    super.initState();
    _initializeTab();
  }

  Future<void> _initializeTab() async {
    final plugin = WebViewPlugin.instance;

    // 如果有初始 URL，创建新标签页
    if (widget.initialUrl != null) {
      // 自动转换 file:// URL（Windows 平台）
      final convertedUrl = plugin.convertUrlIfNeeded(widget.initialUrl!);

      final tab = await plugin.tabManager.createTab(
        url: convertedUrl,
        title: widget.initialTitle ?? '新标签页',
        setActive: true,
        cardId: widget.cardId,
      );
      if (!mounted) {
        await plugin.tabManager.closeTab(tab.id);
        return;
      }
      setState(() {
        _currentTab = tab;
        _urlController.text = tab.url;
      });
    } else if (plugin.tabManager.activeTab != null) {
      // 使用现有的活动标签页
      if (!mounted) return;
      setState(() {
        _currentTab = plugin.tabManager.activeTab;
        _urlController.text = _currentTab?.url ?? '';
      });
    } else {
      // 创建空白标签页
      final tab = await plugin.tabManager.createTab(
        url: 'about:blank',
        title: '新标签页',
        setActive: true,
      );
      if (!mounted) {
        await plugin.tabManager.closeTab(tab.id);
        return;
      }
      setState(() {
        _currentTab = tab;
        _urlController.text = '';
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    // 保存标签页状态；标签模型保留，运行时 WebView 由子组件 dispose 释放。
    WebViewPlugin.instance.saveTabs();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plugin = WebViewPlugin.instance;

    return DSThemeBridge(
      child: ChangeNotifierProvider.value(
        value: plugin.tabManager,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // 顶部地址栏和导航（根据 hideUI 参数决定是否显示）
                if (!widget.hideUI) _buildAddressBar(context),

                // WebView 内容区域
                Expanded(
                  child: Consumer<TabManager>(
                    builder: (context, tabManager, child) {
                      if (tabManager.tabs.isEmpty) {
                        final theme = DSThemeBridge.resolve(context);
                        return Center(
                          child: Text(
                            'webview_no_tabs'.tr,
                            style: DsTypography.body.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                        );
                      }

                      // 使用 IndexedStack 保持标签页状态
                      return IndexedStack(
                        index: tabManager.activeTab != null
                            ? tabManager.getTabIndex(tabManager.activeTabId!)
                            : 0,
                        children: tabManager.tabs.map((tab) {
                          return _WebViewTabContent(
                            key: ValueKey(tab.id),
                            tab: tab,
                            onUrlChanged: (url) {
                              if (tab.id == tabManager.activeTabId) {
                                _urlController.text = url;
                              }
                            },
                            onTitleChanged: (title) {
                              tabManager.updateTab(tab.id, title: title);
                            },
                            onProgressChanged: (progress) {
                              tabManager.updateTab(tab.id, progress: progress);
                            },
                            onLoadingChanged: (isLoading) {
                              tabManager.updateTab(
                                tab.id,
                                isLoading: isLoading,
                              );
                            },
                            onNavigationStateChanged:
                                (canGoBack, canGoForward) {
                                  tabManager.updateTab(
                                    tab.id,
                                    canGoBack: canGoBack,
                                    canGoForward: canGoForward,
                                  );
                                },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),

                // 底部工具栏（根据 hideUI 参数决定是否显示）
                if (!widget.hideUI) _buildBottomBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressBar(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.background,
        boxShadow: theme.shadows.soft,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 返回按钮
              DSIconButton(
                icon: DsIconKind.chevronLeft,
                size: 40,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: '关闭',
                onPressed: () => Navigator.pop(context),
              ),

              // 地址栏（嵌入自绘容器的 TextField 编辑原语，刻意保留 Material）
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _urlController,
                    style: DsTypography.body.copyWith(color: theme.text),
                    decoration: InputDecoration(
                      hintText: 'webview_enter_url'.tr,
                      hintStyle: DsTypography.body.copyWith(
                        color: theme.textSub.withValues(alpha: 0.75),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      prefixIcon: Consumer<TabManager>(
                        builder: (context, tm, _) {
                          final tab = tm.activeTab;
                          if (tab?.isLoading ?? false) {
                            return const Center(
                              child: SizedBox(
                                width: 24,
                                child: DSLoadingDots(size: 4),
                              ),
                            );
                          }
                          // DS 暂无锁形图标，保留 Material
                          return Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: theme.textSub,
                          );
                        },
                      ),
                      suffixIcon: _isUrlBarFocused
                          ? Pressable(
                              onPressed: () {
                                _urlController.clear();
                              },
                              semanticLabel: '清空地址栏',
                              builder: (context, states) => Padding(
                                padding: const EdgeInsets.all(12),
                                child: DsIcon(
                                  DsIconKind.close,
                                  size: 18,
                                  color: theme.textSub,
                                ),
                              ),
                            )
                          : null,
                    ),
                    onTap: () {
                      setState(() {
                        _isUrlBarFocused = true;
                      });
                      _urlController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _urlController.text.length,
                      );
                    },
                    onSubmitted: (value) {
                      setState(() {
                        _isUrlBarFocused = false;
                      });
                      _navigateToUrl(value);
                    },
                    onEditingComplete: () {
                      setState(() {
                        _isUrlBarFocused = false;
                      });
                    },
                  ),
                ),
              ),

              // 刷新/停止按钮
              Consumer<TabManager>(
                builder: (context, tm, _) {
                  final tab = tm.activeTab;
                  return DSIconButton(
                    icon: (tab?.isLoading ?? false)
                        ? DsIconKind.stop
                        : DsIconKind.refresh,
                    size: 40,
                    color: theme.surfaceAlt,
                    iconColor: theme.textSub,
                    onPressed: () {
                      if (tab?.isLoading ?? false) {
                        tm.getController(tab!.id)?.stopLoading();
                      } else if (tab != null) {
                        tm.reload(tab.id);
                      }
                    },
                    tooltip: tab?.isLoading ?? false
                        ? 'webview_stop'.tr
                        : 'webview_reload'.tr,
                  );
                },
              ),
            ],
          ),

          // 加载进度条
          Consumer<TabManager>(
            builder: (context, tm, _) {
              final tab = tm.activeTab;
              if (tab?.isLoading ?? false) {
                return DSLinearProgress(value: tab!.progress, height: 4);
              }
              return const SizedBox(height: 4);
            },
          ),
        ],
      ),
    );
  }

  /// 打开下载管理底部弹层
  void _showDownloadManager() {
    final manager = WebViewPlugin.instance.browserDownloadManager;
    SmoothBottomSheet.showWithTitle(
      context: context,
      title: 'webview_download_manager_title'.tr,
      child: ChangeNotifierProvider.value(
        value: manager,
        child: const DownloadRecordsList(),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: theme.background,
        boxShadow: theme.shadows.soft,
      ),
      child: Consumer<TabManager>(
        builder: (context, tabManager, _) {
          final tab = tabManager.activeTab;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 后退
              DSIconButton(
                icon: DsIconKind.chevronLeft,
                size: 44,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                onPressed: tab?.canGoBack ?? false
                    ? () => tabManager.goBack(tab!.id)
                    : null,
                tooltip: 'webview_go_back'.tr,
              ),

              // 前进
              DSIconButton(
                icon: DsIconKind.chevronRight,
                size: 44,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                onPressed: tab?.canGoForward ?? false
                    ? () => tabManager.goForward(tab!.id)
                    : null,
                tooltip: 'webview_go_forward'.tr,
              ),

              // 添加到卡片
              DSIconButton(
                icon: DsIconKind.plus,
                size: 44,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                onPressed: tab != null ? () => _addToCards(tab) : null,
                tooltip: 'webview_add_to_cards'.tr,
              ),

              // 标签页管理
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: DSIconButton(
                        icon: DsIconKind.layers,
                        size: 44,
                        color: theme.surfaceAlt,
                        iconColor: theme.textSub,
                        onPressed: () => _showTabManager(),
                        tooltip: 'webview_tab_manager'.tr,
                      ),
                    ),
                    if (tabManager.tabCount > 1)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${tabManager.tabCount}',
                            style: DsTypography.label.copyWith(
                              fontSize: 10,
                              color: theme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 下载管理（badge 显示正在下载数量）
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: DSIconButton(
                        icon: DsIconKind.download,
                        size: 44,
                        color: theme.surfaceAlt,
                        iconColor: theme.textSub,
                        onPressed: () => _showDownloadManager(),
                        tooltip: 'webview_download_manager_title'.tr,
                      ),
                    ),
                    ListenableBuilder(
                      listenable: WebViewPlugin.instance.browserDownloadManager,
                      builder: (context, _) {
                        final count = WebViewPlugin
                            .instance.browserDownloadManager.activeCount;
                        if (count == 0) return const SizedBox.shrink();
                        return Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$count',
                              style: DsTypography.label.copyWith(
                                fontSize: 10,
                                color: theme.onPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // 更多选项（DSPopover 经根 Overlay 展示，内容已自带主题）
              DSPopover(
                width: 230,
                contentBuilder: (context, close) {
                  final menuTheme = DSThemeBridge.resolve(context);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MenuRow(
                        icon: DsIcon(
                          DsIconKind.plus,
                          size: 20,
                          color: menuTheme.primary,
                        ),
                        label: 'webview_new_tab'.tr,
                        theme: menuTheme,
                        onTap: () {
                          close();
                          _handleMenuAction('new_tab', tab);
                        },
                      ),
                      _MenuRow(
                        icon: DsIcon(
                          DsIconKind.share,
                          size: 20,
                          color: menuTheme.primary,
                        ),
                        label: 'webview_share'.tr,
                        theme: menuTheme,
                        onTap: () {
                          close();
                          _handleMenuAction('share', tab);
                        },
                      ),
                      _MenuRow(
                        icon: DsIcon(
                          DsIconKind.copy,
                          size: 20,
                          color: menuTheme.primary,
                        ),
                        label: 'webview_copy_url'.tr,
                        theme: menuTheme,
                        onTap: () {
                          close();
                          _handleMenuAction('copy_url', tab);
                        },
                      ),
                      _MenuRow(
                        // DS 暂无"外部浏览器打开"图标，保留 Material
                        icon: Icon(
                          Icons.open_in_browser,
                          size: 20,
                          color: menuTheme.primary,
                        ),
                        label: 'webview_open_in_browser'.tr,
                        theme: menuTheme,
                        onTap: () {
                          close();
                          _handleMenuAction('open_in_browser', tab);
                        },
                      ),
                      Container(
                        height: 1,
                        margin: EdgeInsets.symmetric(
                          vertical: menuTheme.spacing.xs,
                        ),
                        color: menuTheme.stroke,
                      ),
                      _MenuRow(
                        icon: DsIcon(
                          DsIconKind.close,
                          size: 20,
                          color: menuTheme.primary,
                        ),
                        label: 'webview_close_tab'.tr,
                        theme: menuTheme,
                        onTap: () {
                          close();
                          _handleMenuAction('close_tab', tab);
                        },
                      ),
                      _MenuRow(
                        icon: DsIcon(
                          DsIconKind.close,
                          size: 20,
                          color: menuTheme.danger,
                        ),
                        label: 'webview_close_all_tabs'.tr,
                        theme: menuTheme,
                        danger: true,
                        onTap: () {
                          close();
                          _handleMenuAction('close_all', tab);
                        },
                      ),
                    ],
                  );
                },
                child: DSIconButton(
                  icon: DsIconKind.more,
                  size: 44,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigateToUrl(String input) {
    String url = input.trim();

    // 处理搜索或 URL
    if (!url.contains('.') && !url.startsWith('http')) {
      // 使用搜索引擎
      final searchEngine =
          WebViewPlugin.instance.webviewSettings.defaultSearchEngine;
      url = '$searchEngine${Uri.encodeComponent(url)}';
    } else if (!url.startsWith('http')) {
      url = 'https://$url';
    }

    final tabId = WebViewPlugin.instance.tabManager.activeTabId;
    if (tabId != null) {
      WebViewPlugin.instance.tabManager.navigateTo(tabId, url);
      WebViewPlugin.instance.tabManager.updateTab(tabId, url: url);
    }
  }

  void _addToCards(WebViewTab tab) async {
    final exists = WebViewPlugin.instance.cardManager.getCardByUrl(tab.url);
    if (exists != null) {
      Toast.warning('该网址已在卡片中');
      return;
    }

    await WebViewPlugin.instance.cardManager.addCard(
      title: tab.title.isNotEmpty ? tab.title : tab.url,
      url: tab.url,
      type: CardType.url,
      iconUrl: tab.favicon,
    );

    if (mounted) {
      Toast.success('webview_card_added'.tr);
    }
  }

  void _showTabManager() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TabManagerScreen()),
    ).then((_) {
      // 返回时更新 URL 栏
      final tab = WebViewPlugin.instance.tabManager.activeTab;
      if (tab != null) {
        _urlController.text = tab.url;
      }
    });
  }

  void _handleMenuAction(String action, WebViewTab? tab) async {
    final plugin = WebViewPlugin.instance;

    switch (action) {
      case 'new_tab':
        await plugin.tabManager.createTab(
          url: 'about:blank',
          title: '新标签页',
          setActive: true,
        );
        _urlController.clear();
        break;

      case 'share':
        if (tab != null) {
          // TODO: 实现分享功能
        }
        break;

      case 'copy_url':
        if (tab != null) {
          Clipboard.setData(ClipboardData(text: tab.url));
          Toast.success('webview_url_copied'.tr);
        }
        break;

      case 'open_in_browser':
        if (tab != null) {
          final uri = Uri.tryParse(tab.url);
          if (uri != null) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        break;

      case 'close_tab':
        if (tab != null) {
          await plugin.tabManager.closeTab(tab.id);
          if (plugin.tabManager.tabs.isEmpty) {
            Navigator.pop(context);
          } else {
            final newTab = plugin.tabManager.activeTab;
            if (newTab != null) {
              _urlController.text = newTab.url;
            }
          }
        }
        break;

      case 'close_all':
        final confirm = await showDSDialog<bool>(
          context: context,
          theme: DSThemeBridge.resolve(context),
          builder: (ctx) => DSThemeBridge(
            child: Builder(
              builder: (ctx) => DSDialog(
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
          await plugin.tabManager.closeAllTabs();
          if (mounted) Navigator.pop(context);
        }
        break;
    }
  }
}

/// 更多选项气泡菜单行(果冻风格)
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.danger = false,
  });

  final Widget icon;
  final String label;
  final AppThemeData theme;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? theme.danger : theme.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Pressable(
        onPressed: onTap,
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return JellyBox(
            radius: theme.radii.md,
            raised: false,
            color: pressed ? accent.mixWhite(0.9) : theme.surfaceAlt,
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.sm + 2,
            ),
            child: Row(
              children: [
                icon,
                SizedBox(width: theme.spacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: DsTypography.body.copyWith(
                      color: danger ? theme.danger : theme.text,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// WebView 标签页内容组件
class _WebViewTabContent extends StatefulWidget {
  final WebViewTab tab;
  final ValueChanged<String> onUrlChanged;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<double> onProgressChanged;
  final ValueChanged<bool> onLoadingChanged;
  final void Function(bool canGoBack, bool canGoForward)
  onNavigationStateChanged;

  const _WebViewTabContent({
    super.key,
    required this.tab,
    required this.onUrlChanged,
    required this.onTitleChanged,
    required this.onProgressChanged,
    required this.onLoadingChanged,
    required this.onNavigationStateChanged,
  });

  @override
  State<_WebViewTabContent> createState() => _WebViewTabContentState();
}

class _WebViewTabContentState extends State<_WebViewTabContent> {
  JSBridgeInjector? _jsBridgeInjector;
  InAppWebViewController? _controller;
  Timer? _delayedStatusCheck;
  bool _initialLoadCompleted = false; // 标记初始加载是否完成
  String? _lastProcessedUrl; // 记录最后一次处理的 URL，避免重复处理
  final Set<String> _redirectChain = {}; // 记录重定向链，检测循环重定向

  @override
  void dispose() {
    _delayedStatusCheck?.cancel();
    _delayedStatusCheck = null;
    _jsBridgeInjector?.dispose();
    _jsBridgeInjector = null;
    WebViewPlugin.instance.tabManager.clearController(
      widget.tab.id,
      _controller,
    );
    _controller = null;
    _redirectChain.clear();
    super.dispose();
  }

  /// 处理 WebView 下载事件：复用共享下载流程（含 Content-Disposition 文件名）
  Future<void> _handleDownloadStartRequest(DownloadStartRequest request) async {
    await runBrowserDownloadFlow(
      context,
      url: request.url.toString(),
      suggestedFilename: request.suggestedFilename,
      contentDisposition: request.contentDisposition,
    );
  }

  /// 创建 Aboutme UserScript（在页面加载前注入）
  UserScript _createAboutmeUserScript() {
    const script = '''
    (function() {
      // 1. 注入基础命名空间
      if (typeof window.Aboutme !== 'undefined') return;

      window.Aboutme = {
        version: '1.0.0',
        plugins: {},
        system: {},
        storage: {},
        _ready: false,
        _readyCallbacks: []
      };

      window.Aboutme.ready = function(callback) {
        if (window.Aboutme._ready) {
          try { callback(); } catch(e) { console.error('Aboutme ready callback error:', e); }
        } else {
          window.Aboutme._readyCallbacks.push(callback);
        }
      };

      // 2. 注入插件代理
      window.Aboutme.plugins = new Proxy({}, {
        get: function(target, pluginId) {
          if (pluginId === 'ui' || typeof pluginId === 'symbol') {
            return target[pluginId];
          }

          if (!target[pluginId]) {
            target[pluginId] = new Proxy({}, {
              get: function(_, methodName) {
                if (typeof methodName === 'symbol') return undefined;

                return function(params) {
                  return window.flutter_inappwebview.callHandler('Aboutme_plugin_call', {
                    pluginId: pluginId,
                    method: methodName,
                    params: params || {}
                  }).then(function(result) {
                    if (typeof result === 'string') {
                      try {
                        return JSON.parse(result);
                      } catch(e) {
                        return result;
                      }
                    }
                    return result;
                  });
                };
              }
            });
          }
          return target[pluginId];
        }
      });

      // 3. 注入系统 API 代理
      var systemMethods = [
        'getCurrentTime',
        'getDeviceInfo',
        'getAppInfo',
        'formatDate',
        'getTimestamp',
        'getCustomDate'
      ];

      systemMethods.forEach(function(methodName) {
        window.Aboutme.system[methodName] = function(params) {
          return window.flutter_inappwebview.callHandler('Aboutme_system_call', {
            method: methodName,
            params: params
          }).then(function(result) {
            if (typeof result === 'string') {
              try {
                return JSON.parse(result);
              } catch(e) {
                return result;
              }
            }
            return result;
          });
        };
      });

      // 4. 注入 UI API 代理
      var uiApi = {
        toast: function(message, options) {
          return window.flutter_inappwebview.callHandler('Aboutme_ui_toast', {
            message: message,
            options: options || {}
          });
        },
        alert: function(message, options) {
          return window.flutter_inappwebview.callHandler('Aboutme_ui_alert', {
            message: message,
            options: options || {}
          });
        },
        dialog: function(options) {
          return window.flutter_inappwebview.callHandler('Aboutme_ui_dialog', options || {});
        }
      };

      window.Aboutme.plugins.ui = uiApi;
      window.Aboutme.ui = uiApi;

      // 5. 注入 Storage API 代理
      var storageApi = {
        read: function(key) {
          return window.flutter_inappwebview.callHandler('Aboutme_storage_read', {
            key: key
          }).then(function(result) {
            console.log('[Aboutme Storage] Read key:', key, 'result:', result);
            if (typeof result === 'string') {
              try {
                var parsed = JSON.parse(result);
                if (parsed.error) {
                  console.error('[Aboutme Storage] Read error:', parsed.error);
                  throw new Error(parsed.error);
                }
                console.log('[Aboutme Storage] Parsed data:', parsed.data);
                return parsed.data;
              } catch(e) {
                if (e.message && !e.message.includes('JSON')) {
                  throw e;
                }
                return result;
              }
            }
            return result;
          });
        },
        write: function(key, value) {
          return window.flutter_inappwebview.callHandler('Aboutme_storage_write', {
            key: key,
            value: value
          }).then(function(result) {
            if (typeof result === 'string') {
              try {
                var parsed = JSON.parse(result);
                if (parsed.error) {
                  throw new Error(parsed.error);
                }
                return parsed.success;
              } catch(e) {
                if (e.message && !e.message.includes('JSON')) {
                  throw e;
                }
                return true;
              }
            }
            return result;
          });
        },
        delete: function(key) {
          return window.flutter_inappwebview.callHandler('Aboutme_storage_delete', {
            key: key
          }).then(function(result) {
            if (typeof result === 'string') {
              try {
                var parsed = JSON.parse(result);
                if (parsed.error) {
                  throw new Error(parsed.error);
                }
                return parsed.success;
              } catch(e) {
                if (e.message && !e.message.includes('JSON')) {
                  throw e;
                }
                return true;
              }
            }
            return result;
          });
        }
      };

      window.Aboutme.storage = storageApi;

      // 标记准备完成并触发回调
      window.Aboutme._ready = true;
      if (window.Aboutme._readyCallbacks) {
        window.Aboutme._readyCallbacks.forEach(function(cb) {
          try { cb(); } catch(e) { console.error('Aboutme ready callback error:', e); }
        });
        window.Aboutme._readyCallbacks = [];
      }

      console.log('[Aboutme] JS Bridge preloaded successfully');
    })();
    ''';

    return UserScript(
      source: script,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      forMainFrameOnly: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final plugin = WebViewPlugin.instance;
    final webviewSettings = plugin.webviewSettings;

    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(widget.tab.url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: webviewSettings.enableJavaScript,
        javaScriptCanOpenWindowsAutomatically: !webviewSettings.blockPopups,
        supportZoom: webviewSettings.enableZoom,
        userAgent: webviewSettings.userAgent.isNotEmpty
            ? webviewSettings.userAgent
            : null,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        // 允许本地文件访问（用于 file:// URL）
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        useHybridComposition: true, // 启用混合组成，提高性能
      ),
      // 使用 UserScript 预加载 JS Bridge
      initialUserScripts: webviewSettings.enableJSBridge
          ? UnmodifiableListView<UserScript>([_createAboutmeUserScript()])
          : null,
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url?.toString() ?? '';

        // 允许 about:blank
        if (url == 'about:blank') {
          _lastProcessedUrl = url;
          _redirectChain.clear();
          return NavigationActionPolicy.ALLOW;
        }

        // 允许初始加载（尚未完成首次加载）
        if (!_initialLoadCompleted) {
          _lastProcessedUrl = url;
          _redirectChain.clear();
          return NavigationActionPolicy.ALLOW;
        }

        // 允许初始加载（tab.url 为空或为 about:blank）
        if (widget.tab.url.isEmpty || widget.tab.url == 'about:blank') {
          _lastProcessedUrl = url;
          _redirectChain.clear();
          return NavigationActionPolicy.ALLOW;
        }

        // 规范化 URL：去除尾部斜杠（除了根路径）
        String normalizeUrl(String u) {
          if (u.length > 1 && u.endsWith('/')) {
            return u.substring(0, u.length - 1);
          }
          return u;
        }

        final normalizedUrl = normalizeUrl(url);

        // 防止无限循环重定向：检测是否在相同的规范化 URL 之间反复跳转
        if (_redirectChain.contains(normalizedUrl)) {
          debugPrint('[WebView] 检测到循环重定向，已阻止: $url');
          return NavigationActionPolicy.CANCEL;
        }

        // 添加到重定向链
        _redirectChain.add(normalizedUrl);

        // 限制重定向链长度（防止内存泄漏）
        if (_redirectChain.length > 10) {
          // 保留最近的 5 个 URL
          final urls = _redirectChain.toList();
          _redirectChain.clear();
          _redirectChain.addAll(urls.sublist(5));
        }

        // 对于百度等网站，特殊处理：如果检测到 HTTP/HTTPS 反复切换，直接允许第一次，然后阻止后续
        final lastUrl = _lastProcessedUrl;
        if (lastUrl != null) {
          final normalizedLastUrl = normalizeUrl(lastUrl);

          // 如果只是协议不同（HTTP <-> HTTPS），但域名相同
          final isProtocolSwitch =
              (normalizedUrl.startsWith('http://') &&
                  normalizedLastUrl.startsWith('https://')) ||
              (normalizedUrl.startsWith('https://') &&
                  normalizedLastUrl.startsWith('http://'));

          if (isProtocolSwitch) {
            // 提取域名部分进行比较
            Uri? currentUri;
            Uri? lastUri;
            try {
              currentUri = Uri.parse(normalizedUrl);
              lastUri = Uri.parse(normalizedLastUrl);
            } catch (_) {
              // 解析失败，继续正常流程
            }

            if (currentUri != null &&
                lastUri != null &&
                currentUri.host == lastUri.host) {
              // 如果已经在重定向链中，说明是循环，阻止
              if (_redirectChain.contains(normalizedUrl)) {
                debugPrint('[WebView] 检测到协议切换循环，阻止: $url (上次: $lastUrl)');
                return NavigationActionPolicy.CANCEL;
              }
            }
          }
        }

        // 记录 URL 并允许导航
        _lastProcessedUrl = url;
        return NavigationActionPolicy.ALLOW;
      },
      onDownloadStartRequest: (controller, request) {
        _handleDownloadStartRequest(request);
      },
      onWebViewCreated: (controller) {
        _controller = controller;
        plugin.tabManager.setController(widget.tab.id, controller);

        // Windows：CDP 拦截下载响应，阻断 WebView2 默认下载 UI
        unawaited(WebviewDownloadInterceptor.attach(controller, () => context));

        // 初始化 JS Bridge
        if (webviewSettings.enableJSBridge) {
          _jsBridgeInjector = JSBridgeInjector(
            controller: controller,
            enabled: true,
          );
          _jsBridgeInjector!.setContext(context);
          _jsBridgeInjector!.initialize();
        }
      },
      onLoadStart: (controller, url) async {
        if (!mounted || !identical(_controller, controller)) return;
        widget.onLoadingChanged(true);
        if (url != null) {
          // 在开始新导航时，重置最后处理的 URL（但不重置为 null，避免误判）
          widget.onUrlChanged(url.toString());
        }
      },
      onLoadStop: (controller, url) async {
        if (!mounted || !identical(_controller, controller)) return;
        widget.onLoadingChanged(false);

        // 标记初始加载已完成
        if (!_initialLoadCompleted) {
          _initialLoadCompleted = true;
        }

        // 页面加载完成后清理重定向链（为下次导航做准备）
        _redirectChain.clear();

        // 更新导航状态
        try {
          final canGoBack = await controller.canGoBack();
          final canGoForward = await controller.canGoForward();
          if (!mounted || !identical(_controller, controller)) return;
          widget.onNavigationStateChanged(canGoBack, canGoForward);
        } catch (e) {
          debugPrint('[WebView] 导航状态读取失败: $e');
          return;
        }

        // 注意：JS Bridge 已通过 UserScript 预加载，无需重复注入
        // Handler 已在 onWebViewCreated 中注册

        // 调试：检查页面 DOM 状态和运行时错误
        try {
          final domCheck = await controller.evaluateJavascript(
            source: '''
            (function() {
              const bodyHTML = document.body ? document.body.innerHTML : 'NO BODY';
              const rootElement = document.getElementById('root') || document.getElementById('app');
              const rootHTML = rootElement ? rootElement.innerHTML : 'NO ROOT';
              const hasChildren = document.body ? document.body.children.length : 0;

              // 检查是否有全局错误
              const errors = window.__webviewErrors || [];

              // 尝试获取 React/Vue 的错误状态
              let frameworkError = null;
              try {
                // 检查常见的全局状态
                if (window.Vue && window.Vue.config && window.Vue.config.errorHandler) {
                  frameworkError = 'Vue detected';
                }
                if (window.React) {
                  frameworkError = 'React detected';
                }
              } catch (e) {
                frameworkError = 'Error checking framework: ' + e.message;
              }

              // 检查是否有加载指示器
              const hasLoadingIndicator = document.querySelector('.loading, [class*="loading"], [class*="spinner"]') !== null;

              return JSON.stringify({
                bodyEmpty: !document.body || document.body.innerHTML.trim() === '',
                hasRoot: !!rootElement,
                rootEmpty: !rootElement || rootElement.innerHTML.trim() === '',
                childCount: hasChildren,
                bodyPreview: bodyHTML.substring(0, 300),
                rootPreview: rootHTML.substring(0, 300),
                documentReady: document.readyState,
                aboutmeReady: typeof window.Aboutme !== 'undefined',
                hasLoadingIndicator: hasLoadingIndicator,
                globalErrors: errors.length,
                frameworkError: frameworkError
              });
            })();
          ''',
          );
          debugPrint('[WebView DOM Check] $domCheck');

          // 注入全局错误捕获器
          await controller.evaluateJavascript(
            source: '''
            (function() {
              if (!window.__webviewErrors) {
                window.__webviewErrors = [];

                // 捕获未捕获的 Promise 错误
                window.addEventListener('unhandledrejection', function(event) {
                  const error = {
                    type: 'unhandledrejection',
                    message: event.reason ? event.reason.message || event.reason : 'Unknown error',
                    stack: event.reason ? event.reason.stack : null
                  };
                  window.__webviewErrors.push(error);
                  console.error('[Unhandled Promise Rejection]', error.message);
                });

                // 捕获全局错误
                window.addEventListener('error', function(event) {
                  const error = {
                    type: 'error',
                    message: event.message,
                    filename: event.filename,
                    lineno: event.lineno,
                    colno: event.colno
                  };
                  window.__webviewErrors.push(error);
                  console.error('[Global Error]', error.message, 'at', error.filename + ':' + error.lineno);
                });

                console.log('[Aboutme] Global error handlers installed');
              }
            })();
          ''',
          );

          // 延迟 3 秒后再次检查页面状态（用于诊断是否卡在加载状态）
          _delayedStatusCheck?.cancel();
          late final Timer statusCheck;
          statusCheck = Timer(const Duration(seconds: 3), () async {
            try {
              if (!mounted || !identical(_controller, controller)) return;
              final laterCheck = await controller.evaluateJavascript(
                source: '''
                (function() {
                  const rootElement = document.getElementById('root') || document.getElementById('app');
                  const hasLoadingIndicator = document.querySelector('.loading, [class*="loading"], [class*="spinner"]') !== null;
                  const errors = window.__webviewErrors || [];

                  return JSON.stringify({
                    stillLoading: hasLoadingIndicator,
                    errorCount: errors.length,
                    errors: errors,
                    bodyHTML: document.body ? document.body.innerHTML.substring(0, 500) : 'NO BODY'
                  });
                })();
              ''',
              );
              debugPrint('[WebView Status After 3s] $laterCheck');
            } catch (e) {
              debugPrint('[WebView Status After 3s] Error: $e');
            } finally {
              if (identical(_delayedStatusCheck, statusCheck)) {
                _delayedStatusCheck = null;
              }
            }
          });
          _delayedStatusCheck = statusCheck;
        } catch (e) {
          debugPrint('[WebView DOM Check] Error: $e');
        }
      },
      onProgressChanged: (controller, progress) {
        if (!mounted || !identical(_controller, controller)) return;
        widget.onProgressChanged(progress / 100);
      },
      onTitleChanged: (controller, title) {
        if (!mounted || !identical(_controller, controller)) return;
        if (title != null && title.isNotEmpty) {
          widget.onTitleChanged(title);
        }
      },
      onUpdateVisitedHistory: (controller, url, androidIsReload) async {
        if (!mounted || !identical(_controller, controller) || url == null) {
          return;
        }
        widget.onUrlChanged(url.toString());

        // 更新导航状态
        try {
          final canGoBack = await controller.canGoBack();
          final canGoForward = await controller.canGoForward();
          if (!mounted || !identical(_controller, controller)) return;
          widget.onNavigationStateChanged(canGoBack, canGoForward);
        } catch (e) {
          debugPrint('[WebView] 历史导航状态读取失败: $e');
        }
      },
      onConsoleMessage: (controller, consoleMessage) {
        // 增强日志：包含消息级别
        final levelStr = consoleMessage.messageLevel.toString().split('.').last;
        debugPrint('[WebView Console][$levelStr] ${consoleMessage.message}');
      },
      onReceivedError: (controller, request, error) async {
        // 忽略 about:blank 的错误
        if (request.url.toString() == 'about:blank') {
          return;
        }

        // 忽略连接停止错误（type 9），这通常是用户主动停止或页面跳转
        // WebResourceErrorType 在不同平台上的值可能不同，直接比较数值
        if (error.type.toNativeValue() == 9) {
          return;
        }

        // 记录其他错误以便调试
        debugPrint(
          '[WebView Error] URL: ${request.url}, '
          'Error Type: ${error.type} (${error.type.toNativeValue()}), '
          'Description: ${error.description}',
        );

        // 停止加载状态
        widget.onLoadingChanged(false);
      },
      onReceivedHttpError: (controller, request, errorResponse) async {
        // 记录 HTTP 错误（如 404, 500 等）
        debugPrint(
          '[WebView HTTP Error] URL: ${request.url}, '
          'Status: ${errorResponse.statusCode}, '
          'Reason: ${errorResponse.reasonPhrase}',
        );
      },
      onReceivedServerTrustAuthRequest: (controller, challenge) async {
        // 处理 SSL 证书信任请求
        // 在开发环境中，自动信任所有有效证书
        // 注意：在生产环境中应该进行更严格的证书验证

        // 简单的解决方案：信任所有 SSL 证书验证
        return ServerTrustAuthResponse(
          action: ServerTrustAuthResponseAction.PROCEED,
        );
      },
    );
  }
}
