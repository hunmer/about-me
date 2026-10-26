import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:adaptive_theme/adaptive_theme.dart';

import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/notification_controller.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/services/shortcut_manager.dart';
import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/services/system_widget_service.dart';
import 'package:aboutme/core/services/plugin_widget_sync_helper.dart';
import 'package:aboutme/core/services/app_background_controller.dart';
import 'package:aboutme/core/services/ds_ink_motion_controller.dart';
import 'package:aboutme/core/services/ds_ink_style_controller.dart';
import 'package:aboutme/core/services/hand_drawn_style_controller.dart';
import 'package:aboutme/core/services/grok_bot_style_controller.dart';
import 'package:aboutme/core/services/ds_theme_color_controller.dart';
import 'package:aboutme/core/services/timer/unified_timer_controller.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme_foreground_service/aboutme_foreground_service.dart';
import 'package:aboutme_notifications/aboutme_notifications.dart';
import 'package:aboutme/core/builtin_plugins.dart';
import 'package:aboutme/screens/settings_screen/controllers/auto_update_controller.dart';
import 'package:aboutme/screens/settings_screen/controllers/permission_controller.dart';
import 'package:aboutme/screens/settings_screen/widgets/permission_request_dialog.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/action/action_manager.dart';
import 'package:aboutme/core/floating_ball/floating_ball_service.dart';
import 'app_widgets/home_widget_service.dart';
import 'app_widgets/floating_ball_service.dart';
import 'package:aboutme/screens/route.dart';
import 'package:aboutme/core/storage/storage_backend_config.dart';
import 'package:aboutme/core/storage/device_identity.dart';
import 'package:aboutme/core/storage/storage_websocket_service.dart';
import 'package:aboutme/core/route/route_refresh_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/settings_screen/widgets/storage_backend_settings_dialog.dart';
import 'package:aboutme/utils/blob_url.dart';
import 'global_flags.dart';
import 'services/toast_service.dart';
import 'services/log_service.dart';
import 'services/startup_trace.dart';
import 'services/speech_recognition_config_service.dart';
import 'services/fcm_service.dart';

/// 应用启动状态管理
class AppStartupState extends ChangeNotifier {
  static final AppStartupState instance = AppStartupState._();
  AppStartupState._();

  bool _coreReady = false; // 核心服务就绪（存储、配置）
  bool _criticalPluginsReady = false; // 当前启动目标依赖的插件就绪
  bool _pluginsReady = false; // 插件注册完成
  bool _fullyReady = false; // 所有初始化完成
  final _pluginsReadyCompleter = Completer<void>();
  final _criticalPluginsReadyCompleter = Completer<void>();
  String _loadingMessage = '正在启动...';

  // 待处理的初始URI（从小组件启动时）
  Uri? _initialWidgetUri;
  bool _isHandlingInitialUri = false; // 是否正在处理初始URI

  bool get coreReady => _coreReady;
  bool get criticalPluginsReady => _criticalPluginsReady;
  bool get pluginsReady => _pluginsReady;
  bool get fullyReady => _fullyReady;
  Future<void> get whenPluginsReady => _pluginsReadyCompleter.future;
  Future<void> get whenCriticalPluginsReady =>
      _criticalPluginsReadyCompleter.future;
  String get loadingMessage => _loadingMessage;
  Uri? get initialWidgetUri => _initialWidgetUri;
  bool get isHandlingInitialUri => _isHandlingInitialUri;

  void _setCoreReady() {
    StartupTrace.mark('core_ready');
    _coreReady = true;
    notifyListeners();
  }

  void _setPluginsReady() {
    StartupTrace.mark('plugins_ready');
    _pluginsReady = true;
    if (!_pluginsReadyCompleter.isCompleted) _pluginsReadyCompleter.complete();
    notifyListeners();
  }

  void _setCriticalPluginsReady() {
    if (_criticalPluginsReady) return;
    StartupTrace.mark('critical_plugins_ready');
    _criticalPluginsReady = true;
    if (!_criticalPluginsReadyCompleter.isCompleted) {
      _criticalPluginsReadyCompleter.complete();
    }
    notifyListeners();
  }

  void _setFullyReady() {
    StartupTrace.mark('background_scheduled');
    _fullyReady = true;
    notifyListeners();
  }

  void _setLoadingMessage(String message) {
    _loadingMessage = message;
    notifyListeners();
  }

  /// 设置待处理的初始URI
  void setInitialWidgetUri(Uri uri) {
    _initialWidgetUri = uri;
    _isHandlingInitialUri = true;
    notifyListeners();
  }

  /// 清除初始URI（处理完成后调用）
  void clearInitialWidgetUri() {
    _initialWidgetUri = null;
    _isHandlingInitialUri = false;
    notifyListeners();
  }
}

const String _permissionOnboardingKey = 'permissionsOnboardingCompleted';

bool _shouldHandlePermissionsForPlatform() {
  return UniversalPlatform.isAndroid || UniversalPlatform.isIOS;
}

/// 应用初始化函数 - 快速启动版本
/// 只执行最小必要的同步初始化，其他功能后台加载
Future<void> initializeApp() async {
  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 配置日志输出（轻量级，不阻塞）
  Logger.root.level = Level.ALL;
  // dartantic 流式日志过于高频（每个 stream chunk 都输出），静音其 FINE 级日志
  hierarchicalLoggingEnabled = true;
  Logger('dartantic').level = Level.WARNING;
  Logger.root.onRecord.listen((record) {
    debugPrint(
      '[${record.level.name}] ${record.loggerName}: ${record.message}',
    );
    if (record.error != null) {
      debugPrint('Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      debugPrint('StackTrace: ${record.stackTrace}');
    }

    // 同时输出到日志服务
    final logService = LogService.instance;
    if (logService.isEnabled) {
      final message = '[${record.loggerName}] ${record.message}';
      switch (record.level.name) {
        case 'WARNING':
          logService.warning(message);
          break;
        case 'SEVERE':
        case 'SHOUT':
          logService.error(
            message,
            error: record.error,
            stackTrace: record.stackTrace,
          );
          break;
        case 'INFO':
        case 'CONFIG':
          logService.info(message);
          break;
        default:
          logService.debug(message);
      }
    }
  });

  // 设置首选方向为竖屏（快速操作）
  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  );

  // 异步获取主题，不阻塞启动
  unawaited(
    AdaptiveTheme.getThemeMode().then((mode) {
      savedThemeMode = mode;
    }),
  );

  try {
    // === 核心初始化（必须同步完成） ===
    // 创建并初始化存储管理器
    await StartupTrace.measure('device_identity', DeviceIdentity.initialize);
    globalStorage = StorageManager();
    await StartupTrace.measure('storage', globalStorage.initialize);

    // 初始化统一数据入口（本地直处理 / 远程 REST 自动决定）
    await StartupTrace.measure(
      'data_service',
      AboutmeDataService.instance.initialize,
    );

    // 初始化配置管理器
    globalConfigManager = ConfigManager(globalStorage);
    await StartupTrace.measure('config', globalConfigManager.initialize);

    // 初始化全局主题背景（所有界面共用的背景图设置）
    await StartupTrace.measure(
      'background_config',
      AppBackgroundController().initialize,
    );

    // 初始化主题色板（全局主题颜色选择）
    await StartupTrace.measure(
      'theme_color',
      DsThemeColorController().initialize,
    );

    // 初始化墨线风格（全局手绘粗糙度档位）
    await StartupTrace.measure('ink_style', DsInkStyleController().initialize);

    // 初始化墨线入场动画时长（0 = 关闭描画动画）
    await StartupTrace.measure('ink_motion', DsInkMotionController().initialize);

    // 初始化手绘便签风格（全局贴条/倾斜开关）
    await StartupTrace.measure(
      'hand_drawn_style',
      HandDrawnStyleController().initialize,
    );

    // 初始化 grokbot 外观（首页角色身形/墨色）
    await StartupTrace.measure(
      'grok_bot_style',
      GrokBotStyleController().initialize,
    );

    // 初始化日志服务（根据配置决定是否启用）
    unawaited(LogService.instance.initialize(globalStorage));

    // 初始化插件管理器（不注册插件）
    globalPluginManager = PluginManager();
    await StartupTrace.measure(
      'plugin_config',
      () => globalPluginManager.setStorageManager(globalStorage),
    );
    RouteRefreshManager().setPluginManager(globalPluginManager);
    final backendConfig = await LocalStorageBackendConfigStore().load();
    if (backendConfig.isHttpEnabled) {
      unawaited(StorageWebSocketService.instance.connect(backendConfig));
    }

    // 设置全局错误处理器
    FlutterError.onError = (details) {
      debugPrint(details.toString());
    };

    // 初始化 Toast 服务
    Toast.setNavigatorKey(navigatorKey);

    // 远端存储连接失败的提示在真实 UI 首帧后由 MyApp 触发
    // （promptRemoteStorageUnavailable），启动壳期间导航器尚不可用。

    // 在初始化通知服务之前先清理历史通知和计时器状态
    // 这是防止应用重启后通知自动复原的关键步骤
    AppStartupState.instance._setLoadingMessage('正在清理历史通知...');
    await StartupTrace.measure(
      'notifications_clear',
      AboutmeNotifications.instance.cancelAll,
    );

    // 同时清理统一计时器控制器的活动计时器，防止插件重新创建通知
    try {
      final timerController = UnifiedTimerController();
      await StartupTrace.measure('timers_clear', timerController.clearAll);
    } catch (e) {
      debugPrint('[AppInitializer] 清理计时器状态失败（可能尚未初始化）: $e');
    }

    // 停止前台服务（防止系统重启后自动启动）
    // 仅在移动端执行此操作
    if (UniversalPlatform.isAndroid || UniversalPlatform.isIOS) {
      try {
        final foregroundService = AboutmeForegroundService.instance;
        if (await foregroundService.isRunning) {
          await foregroundService.stopService();
          debugPrint('[AppInitializer] 已停止前台服务');
        }
      } catch (e) {
        debugPrint('[AppInitializer] 停止前台服务失败: $e');
      }
    }

    // 初始化通知控制器（设置监听器和配置）
    AppStartupState.instance._setLoadingMessage('正在初始化通知服务...');
    await StartupTrace.measure(
      'notifications_init',
      NotificationController.initialize,
    );

    // 核心服务就绪，可以显示UI
    AppStartupState.instance._setCoreReady();

    // === 检查是否有来自小组件的初始URI ===
    // 这必须在设置监听器之前执行，否则会错过启动时的URI
    unawaited(_handleInitialWidgetUri());
  } catch (e) {
    debugPrint('核心初始化失败: $e');
    // 启动壳展示失败状态，不构建依赖未初始化全局变量的应用树。
    rethrow;
  }
}

Future<void>? _backgroundInitialization;

/// 仅在真实应用首帧后调用；重复调用共用同一次初始化。
Future<void> initializeBackgroundServices() =>
    _backgroundInitialization ??= _initializeBackgroundServices();

/// 后台服务初始化 - 在UI显示后执行
Future<void> _initializeBackgroundServices() async {
  final startupState = AppStartupState.instance;

  try {
    // 初始化 ImageUtils
    unawaited(ImageUtils.initializeSync(storage: globalStorage));

    // 初始化路由历史管理器
    unawaited(RouteHistoryManager.instance.initialize(storage: globalStorage));

    // 初始化快捷方式管理器
    globalShortcutManager = AppShortcutManager();
    globalShortcutManager.initialize();

    // 初始化 JS Bridge
    unawaited(
      JSBridgeManager.instance.initialize().catchError((e) {
        debugPrint('JS Bridge 初始化失败: $e');
      }),
    );

    // === 注册插件（核心功能，可配置） ===
    startupState._setLoadingMessage('正在加载插件...');
    await StartupTrace.measure('plugins', _registerPlugins);
    startupState._setPluginsReady();

    // 先让目标页面完成一帧，低优先级服务不挤占页面首次构建。
    await WidgetsBinding.instance.endOfFrame;
    StartupTrace.mark('deferred_services_begin');
    unawaited(NotificationController.requestPermission());
    unawaited(
      SpeechRecognitionConfigService.instance.initialize().catchError((e) {
        debugPrint('语音识别配置服务初始化失败: $e');
      }),
    );

    // === 初始化悬浮球动作管理器 ===
    unawaited(_initializeFloatingBallActions());

    // === 后续初始化（低优先级） ===
    startupState._setLoadingMessage('正在完成初始化...');

    // 初始化主页小组件系统
    unawaited(initializeHomeWidgets());

    // 初始化自动更新控制器
    final updateController = AutoUpdateController.instance;
    updateController.initialize();

    // 设置桌面小组件点击监听器
    unawaited(setupWidgetClickListener());

    // 初始化系统桌面小组件服务并同步数据
    unawaited(
      SystemWidgetService.instance.initialize().then((_) {
        PluginWidgetSyncHelper.instance.syncAllPlugins();
      }),
    );

    // 恢复悬浮球状态
    unawaited(restoreFloatingBallState());

    // 初始化 FCM 推送服务
    unawaited(
      FcmService.instance.initialize().catchError((e) {
        debugPrint('FCM 推送服务初始化失败: $e');
      }),
    );

    // 延迟执行权限检查和小组件同步
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = navigatorKey.currentContext;
      if (context != null && _shouldHandlePermissionsForPlatform()) {
        _permissionController = PermissionController();
        final hasCompletedPermissions = globalConfigManager
            .getAppConfigValue<bool>(_permissionOnboardingKey, false);

        if (!hasCompletedPermissions) {
          await showPermissionRequestDialog(
            context: context,
            controller: _permissionController,
            barrierDismissible: false,
            showSkipButton: true,
          );
          await globalConfigManager.setAppConfigValue(
            _permissionOnboardingKey,
            true,
          );
        }
      }

      // 发布插件初始化完成事件
      eventManager.broadcast(
        'plugins_initialized',
        EventArgs('plugins_initialized'),
      );

      // 同步待处理的小组件变更
      await PluginWidgetSyncHelper.instance.syncPendingTaskChangesOnStartup();
      await PluginWidgetSyncHelper.instance.syncPendingGoalChangesOnStartup();
      await PluginWidgetSyncHelper.instance
          .syncPendingHabitTimerChangesOnStartup();
    });

    startupState._setFullyReady();
  } catch (e) {
    debugPrint('后台初始化失败: $e');
    // 即使后台注册整体失败，也不要让启动闸门永久等待。
    startupState._setCriticalPluginsReady();
    startupState._setFullyReady();
  }
}

/// 处理来自小组件的初始URI（应用冷启动时）
Future<void> _handleInitialWidgetUri() async {
  try {
    // 检查是否有初始的URI（通过小组件启动时）
    final initialUri = await SystemWidgetService.instance.getInitialUri();
    if (initialUri != null && initialUri.toString().isNotEmpty) {
      debugPrint('检测到来自小组件的初始URI: $initialUri');

      // 将URI设置到AppStartupState中
      AppStartupState.instance.setInitialWidgetUri(initialUri);

      // 等待实际就绪，避免首帧提前后固定延迟仍访问未初始化插件。
      await AppStartupState.instance.whenPluginsReady;
      await WidgetsBinding.instance.endOfFrame;

      // 直接导航到对应路由
      _navigateToWidgetUri(initialUri.toString());
    }
  } catch (e) {
    debugPrint('处理初始URI失败: $e');
  }
}

/// 导航到小组件URI对应的页面
/// 这是从 home_widget_service.dart 移植过来的简化版本
void _navigateToWidgetUri(String url) {
  debugPrint('收到桌面小组件点击事件: $url');

  // 标记应用从小组件启动，防止错误地自动打开最后使用的插件
  isLaunchedFromWidget = true;

  try {
    final uri = Uri.parse(url);
    debugPrint('URI scheme: ${uri.scheme}');
    debugPrint('URI host: ${uri.host}');
    debugPrint('URI path: ${uri.path}');
    debugPrint('URI query: ${uri.query}');

    // 解析 URI 路径和参数
    String routePath = uri.path;

    // 如果 path 为空或只有斜杠，使用 host 作为路由路径
    if (routePath.isEmpty || routePath == '/') {
      routePath = '/${uri.host}';
      debugPrint('使用 host 作为路由路径: $routePath');
    }

    // 移除 /widget 前缀（如果存在）
    if (routePath.startsWith('/widget/')) {
      routePath = routePath.substring(7);
    } else if (routePath.startsWith('widget/')) {
      routePath = '/${routePath.substring(7)}';
    }

    debugPrint('处理后的路由路径: $routePath');

    // 提取所有查询参数
    final queryParams = uri.queryParameters;

    // 将 queryParams 作为 arguments 传递
    final arguments = queryParams.isNotEmpty ? queryParams : null;

    debugPrint('导航到路由: $routePath, 参数: $arguments');

    // 执行导航
    Future.delayed(const Duration(milliseconds: 100), () {
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        debugPrint(
          '执行导航: 重置路由栈并push RouteSettings($routePath, arguments: $arguments)',
        );
        try {
          // 从小组件进入时，重置路由栈为两层：首页 + 目标页面
          navigator.pushNamedAndRemoveUntil(
            AppRoutes.initialRoute,
            (route) => false,
          );

          // 延迟一帧后再推入目标路由
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final route = AppRoutes.generateRoute(
              RouteSettings(name: routePath, arguments: arguments),
            );
            navigator.push(route);
            debugPrint(
              '导航成功：路由栈现在有两层 (${AppRoutes.initialRoute} -> $routePath)',
            );

            // 导航成功后清除初始URI状态
            AppStartupState.instance.clearInitialWidgetUri();
          });
        } catch (error, stack) {
          debugPrint('路由导航失败: $error');
          debugPrint('堆栈: $stack');

          // 导航失败时也清除状态
          AppStartupState.instance.clearInitialWidgetUri();
        }
      } else {
        debugPrint('导航器尚未初始化，延迟500ms后重试');
        Future.delayed(const Duration(milliseconds: 500), () {
          final retryNavigator = navigatorKey.currentState;
          if (retryNavigator != null) {
            try {
              retryNavigator.pushNamedAndRemoveUntil(
                AppRoutes.initialRoute,
                (route) => false,
              );

              WidgetsBinding.instance.addPostFrameCallback((_) {
                final route = AppRoutes.generateRoute(
                  RouteSettings(name: routePath, arguments: arguments),
                );
                retryNavigator.push(route);
                debugPrint('重试导航成功');

                // 导航成功后清除初始URI状态
                AppStartupState.instance.clearInitialWidgetUri();
              });
            } catch (e) {
              debugPrint('重试导航失败: $e');

              // 导航失败时也清除状态
              AppStartupState.instance.clearInitialWidgetUri();
            }
          } else {
            debugPrint('导航器初始化失败');

            // 失败时清除状态
            AppStartupState.instance.clearInitialWidgetUri();
          }
        });
      }
    });
  } catch (e, stack) {
    debugPrint('处理小组件点击失败: $e');
    debugPrint('堆栈: $stack');

    // 发生异常时清除状态
    AppStartupState.instance.clearInitialWidgetUri();
  }
}

/// 初始化悬浮球动作管理器
Future<void> _initializeFloatingBallActions() async {
  try {
    final actionManager = ActionManager();
    await actionManager.initialize();
  } catch (e, stack) {
    debugPrint('悬浮球动作管理器初始化失败: $e');
    debugPrint('堆栈: $stack');
  }
}

/// 注册所有内置插件
Future<void> _registerPlugins() async {
  final plugins = BuiltinPlugins.createAll();

  final lastPluginId = globalPluginManager.getLastOpenedPluginId;
  final lastPluginEnabled =
      lastPluginId != null && globalConfigManager.isPluginEnabled(lastPluginId);
  final criticalId = globalPluginManager.autoOpenLastPlugin && lastPluginEnabled
      ? lastPluginId
      : 'live2d';
  final registrations = plugins.map((plugin) async {
    final isEnabled = globalConfigManager.isPluginEnabled(plugin.id);
    if (!isEnabled) {
      debugPrint('插件已禁用，跳过注册: ${plugin.id}');
      if (plugin.id == criticalId) {
        AppStartupState.instance._setCriticalPluginsReady();
      }
      return;
    }
    try {
      await globalPluginManager.registerPlugin(plugin);
      if (plugin.id == criticalId) {
        AppStartupState.instance._setCriticalPluginsReady();
      }
    } catch (e) {
      debugPrint('插件注册失败: ${plugin.id} - $e');
    } finally {
      if (plugin.id == criticalId) {
        AppStartupState.instance._setCriticalPluginsReady();
      }
    }
  });

  // The target plugin may be disabled or absent; do not block the gate forever.
  if (!plugins.any((plugin) => plugin.id == criticalId)) {
    AppStartupState.instance._setCriticalPluginsReady();
  }
  await Future.wait(registrations);
}

/// 保存的主题模式（公共变量，供其他模块使用）
AdaptiveThemeMode? savedThemeMode;

/// 全局导航键
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 全局单例实例
late final StorageManager globalStorage;
late final ConfigManager globalConfigManager;
late final PluginManager globalPluginManager;
late final AppShortcutManager globalShortcutManager;

late PermissionController _permissionController;

/// 初始化并显示Flutter悬浮球（应用内Overlay）
/// 在应用启动完成后，导航器可用时调用
Future<void> initializeFlutterFloatingBall() async {
  try {
    // 等待一小段时间确保导航器已初始化
    await Future.delayed(const Duration(milliseconds: 100));

    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('导航器上下文未就绪，延迟重试');
      // 延迟一帧后重试
      WidgetsBinding.instance.addPostFrameCallback((_) {
        initializeFlutterFloatingBall();
      });
      return;
    }

    // 使用 addPostFrameCallback 确保 UI 完全构建后再显示浮动球
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // 再次检查上下文是否有效
        if (!context.mounted) {
          debugPrint('上下文已失效，跳过悬浮球初始化');
          return;
        }

        // 初始化悬浮球服务
        final floatingBallService = FloatingBallService();
        await floatingBallService.initialize(context);

        // 设置悬浮球动作上下文，使手势动作生效
        floatingBallService.manager.setActionContext(context);

        // 检查悬浮球是否启用，如果启用则显示
        final isEnabled = await floatingBallService.manager.isEnabled();
        if (isEnabled) {
          await floatingBallService.show(context);
        }
      } catch (e, stack) {
        debugPrint('Flutter悬浮球初始化失败: $e');
        debugPrint('堆栈: $stack');
      }
    });
  } catch (e, stack) {
    debugPrint('Flutter悬浮球初始化失败: $e');
    debugPrint('堆栈: $stack');
  }
}

/// 远端存储服务器连接失败时提示用户，确认后打开存储后端设置对话框。
/// 与 [ensureWebStorageBackend] 同样在真实导航树首帧后由 MyApp 调用，
/// 此时 [globalStorage] 已完成初始化并记录失败原因。
Future<void> promptRemoteStorageUnavailable() async {
  try {
    if (globalStorage.remoteFallbackReason == null) return;

    // 让过启动期其他弹层，避免多弹窗叠加
    await Future.delayed(const Duration(milliseconds: 500));
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('[StorageFallback] 导航器未就绪，跳过远端存储不可用提示');
      return;
    }

    final openSettings = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSDialog(
            title: '远程服务器不可用',
            message: '无法连接远端存储服务器，数据暂时无法同步。是否打开存储设置检查配置？',
            confirmText: '打开设置',
            cancelText: '忽略',
          ),
    );
    if (openSettings != true) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const StorageBackendSettingsDialog(),
    );
    if (saved == true && kIsWeb) {
      // Web 保存新配置后刷新页面立即生效，避免继续使用失效的连接
      reloadPage();
    }
  } catch (e) {
    debugPrint('[StorageFallback] 远端存储不可用提示失败: $e');
  }
}

/// Web 平台要求配置 HTTP 存储服务器（浏览器 IndexedDB 仅作未配置时的临时后端）。
/// 未配置时在 UI 就绪后弹出设置对话框，保存成功后自动刷新页面生效；
/// 用户取消则本次会话继续使用本地 IndexedDB，下次启动再次提醒。
Future<void> ensureWebStorageBackend() async {
  if (!kIsWeb) return;
  try {
    final config = await LocalStorageBackendConfigStore().load();
    if (config.isHttpEnabled) return;

    await Future.delayed(const Duration(milliseconds: 500));
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('[WebStorage] 导航器未就绪，跳过存储后端配置提醒');
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          PopScope(canPop: false, child: const StorageBackendSettingsDialog()),
    );
    if (saved == true) {
      debugPrint('[WebStorage] 存储后端已配置，刷新页面生效');
      reloadPage();
    } else {
      debugPrint('[WebStorage] 用户跳过配置，本次会话使用浏览器本地存储');
    }
  } catch (e) {
    debugPrint('[WebStorage] 存储后端配置检查失败: $e');
  }
}
