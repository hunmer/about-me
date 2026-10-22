import 'dart:convert';
import 'dart:io' show File, Directory, FileSystemEntity, FileSystemEntityType;
import 'package:universal_platform/universal_platform.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/js_bridge/js_bridge_plugin.dart';
import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/services/plugin_data_selector/index.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

import 'models/webview_card.dart';
import 'models/webview_settings.dart';
import 'services/tab_manager.dart';
import 'services/card_manager.dart';
import 'services/proxy_controller_service.dart';
import 'services/local_http_server.dart';
import 'services/app_store_manager.dart';
import 'services/download_manager.dart';
import 'screens/webview_main_screen.dart';
import 'screens/webview_settings_screen.dart';

part 'webview_js_api.dart';
part 'webview_data_selectors.dart';
part 'webview_local_server.dart';

/// WebView 插件
///
/// 支持：
/// - 多标签页浏览
/// - 网址卡片管理（在线/本地）
/// - Aboutme JS Bridge 集成
class WebViewPlugin extends BasePlugin with ChangeNotifier, JSBridgePlugin {
  static WebViewPlugin? _instance;

  static WebViewPlugin get instance {
    _instance ??= PluginManager.instance.getPlugin('webview') as WebViewPlugin?;
    if (_instance == null) {
      throw StateError('WebViewPlugin has not been initialized');
    }
    return _instance!;
  }

  // Services
  late final TabManager tabManager;
  late final CardManager cardManager;
  late final ProxyControllerService proxyController;
  late final LocalHttpServer localHttpServer;
  late final AppStoreManager appStoreManager;
  late final DownloadManager downloadManager;
  late WebViewSettings webviewSettings;

  /// 待复制的文件列表（用于 Android 11+ 的文件访问）
  List<String>? pendingFilesToCopy;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  @override
  Map<String, Function> defineJSAPI() {
    return {
      // 卡片管理
      'getCards': _jsGetCards,
      'addCard': _jsAddCard,
      'deleteCard': _jsDeleteCard,
      'updateCard': _jsUpdateCard,
      'findCardById': _jsFindCardById,
      'findCardByUrl': _jsFindCardByUrl,

      // 标签页管理
      'getTabs': _jsGetTabs,
      'createTab': _jsCreateTab,
      'closeTab': _jsCloseTab,
      'switchTab': _jsSwitchTab,

      // 导航
      'navigate': _jsNavigate,
      'goBack': _jsGoBack,
      'goForward': _jsGoForward,
      'reload': _jsReload,
    };
  }

  @override
  String get id => 'webview';

  @override
  Color get color => const Color(0xFF4285F4); // Google Blue

  @override
  IconData get icon => Icons.language;

  @override
  String? getPluginName(context) => 'webview_name'.tr;

  @override
  Future<void> initialize() async {
    // 初始化服务
    tabManager = TabManager(maxTabs: 10);
    cardManager = CardManager(storage);
    proxyController = ProxyControllerService();
    localHttpServer = LocalHttpServer();

    // 初始化应用商场管理器
    appStoreManager = AppStoreManager(
      storage: storage,
      cardManager: cardManager,
    );

    // 初始化下载管理器
    downloadManager = DownloadManager(
      storage: storage,
      cardManager: cardManager,
      appStoreManager: appStoreManager,
      httpServer: localHttpServer,
    );

    // 检查 proxy 支持
    await proxyController.checkSupport();

    // 加载设置
    await _loadSettings();

    // 应用 proxy 配置（如果支持）
    if (proxyController.isSupported) {
      await proxyController.applyProxySettings(webviewSettings.proxySettings);
    }

    // 初始化卡片服务
    await cardManager.initialize();

    // 初始化应用商场
    await appStoreManager.initialize();

    // 恢复标签页状态
    if (webviewSettings.restoreTabsOnStartup) {
      await _restoreTabs();
    }

    // 在非 Web 平台启动本地 HTTP 服务器（主要用于 Windows）
    if (!kIsWeb) {
      await _startLocalHttpServer();
    }

    _isInitialized = true;
    _instance = this;

    // 注册 JS API
    await registerJSAPI();

    // 等待 JSBridgeManager 完全初始化
    final jsBridge = JSBridgeManager.instance;

    // 等待引擎初始化完成
    int retryCount = 0;
    while (!jsBridge.isSupported && retryCount < 50) {
      await Future.delayed(Duration(milliseconds: 100));
      retryCount++;
    }

    if (jsBridge.isSupported) {
      // 加载所有卡片的 preload.js 并注册工具
      await _loadPreloadScripts();
    }

    // 注册数据选择器
    _registerDataSelectors();
  }

  /// 加载所有卡片的 preload.js 文件
  Future<void> _loadPreloadScripts() async {
    final jsBridge = JSBridgeManager.instance;
    final cards = cardManager.getAllCards();
    if (cards.isEmpty) {
      return;
    }

    for (final card in cards) {
      if (card.type == CardType.localFile) {
        // 获取卡片对应的 HTTP 服务器路径
        final cardPath = await cardManager.getCardPath(card);
        final preloadFile = File('$cardPath/preload.js');
        if (await preloadFile.exists()) {
          // 读取 preload.js 内容
          final scriptContent = await preloadFile.readAsString();
          // 在 QuickJS 引擎中执行脚本（如果 JS Bridge 未初始化，会自动加入延迟队列）
          try {
            final result = await jsBridge.evaluateWhenReady(
              scriptContent,
              description: 'preload.js: ${card.title}',
            );
            if (!result.success) {
              print('[WebViewPlugin] 执行错误: ${result.error}');
            }
          } catch (e) {
            print('[WebViewPlugin] ✗ 加载 preload.js 失败: ${card.title}');
            print('[WebViewPlugin] 错误详情: $e');
            print('[WebViewPlugin] 错误类型: ${e.runtimeType}');
          }
        }
      }
    }
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      final data = await AboutmeDataService.instance.readPath('webview/settings.json');
      if (data != null) {
        webviewSettings = WebViewSettings.fromJson(
          data as Map<String, dynamic>,
        );
      } else {
        webviewSettings = WebViewSettings();
      }
    } catch (e) {
      webviewSettings = WebViewSettings();
    }
  }

  /// 保存设置
  Future<void> saveWebviewSettings() async {
    await AboutmeDataService.instance.writePath('webview/settings.json', webviewSettings.toJson());

    // 重新应用 proxy 配置
    if (proxyController.isSupported) {
      await proxyController.applyProxySettings(webviewSettings.proxySettings);
    }

    notifyListeners();
  }

  /// 恢复标签页
  Future<void> _restoreTabs() async {
    try {
      final data = await AboutmeDataService.instance.readPath('webview/tabs.json');
      if (data != null && data is List) {
        await tabManager.restoreFromJson(data);
      }
    } catch (e) {
      debugPrint('恢复标签页失败: $e');
    }
  }

  /// 保存标签页状态
  Future<void> saveTabs() async {
    final tabsJson = tabManager.toJson();
    await AboutmeDataService.instance.writePath('webview/tabs.json', tabsJson);
  }

  // ==================== 统计方法 ====================

  int getTotalCardsCount() => _isInitialized ? cardManager.count : 0;
  int getUrlCardsCount() => _isInitialized ? cardManager.urlCards.length : 0;
  int getLocalFileCardsCount() =>
      _isInitialized ? cardManager.localFileCards.length : 0;
  int getActiveTabsCount() => _isInitialized ? tabManager.tabCount : 0;

  // ==================== UI 构建 ====================

  @override
  Widget buildMainView(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: cardManager),
        ChangeNotifierProvider.value(value: tabManager),
        ChangeNotifierProvider.value(value: appStoreManager),
        ChangeNotifierProvider.value(value: downloadManager),
      ],
      child: const WebViewMainScreen(),
    );
  }

  @override
  bool get hasSettingsView => true;

  @override
  Widget buildSettingsView(BuildContext context) {
    return const WebViewSettingsScreen();
  }

  @override
  Widget? buildCardView(BuildContext context) {
    if (!_isInitialized) return null;

    final theme = DSThemeBridge.resolve(context);
    final totalCards = getTotalCardsCount();
    final activeTabs = getActiveTabsCount();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 插件注册表图标(Icons.language),属持久化 IconData,刻意保留 Material
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                'webview_name'.tr,
                style: DsTypography.heading.copyWith(
                  color: theme.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    'webview_cards'.tr,
                    style: DsTypography.body.copyWith(color: theme.textSub),
                  ),
                  Text(
                    '$totalCards',
                    style: DsTypography.body.copyWith(
                      color: theme.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'webview_tabs'.tr,
                    style: DsTypography.body.copyWith(color: theme.textSub),
                  ),
                  Text(
                    '$activeTabs',
                    style: DsTypography.body.copyWith(
                      color: theme.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // 停止本地 HTTP 服务器
    if (!kIsWeb) {
      stopLocalHttpServer();
    }
    super.dispose();
  }
}
