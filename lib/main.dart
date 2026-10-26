import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/core/services/log_service.dart';
import 'package:aboutme/core/services/startup_trace.dart';
import 'package:aboutme/core/services/window_geometry_service.dart';
import 'package:aboutme/core/widgets/app_bootstrap.dart';
// Select the platform implementation at compile time so the web build keeps
// its logger dependency isolated from the native startup path.
import 'core/services/procm_logger_stub.dart'
    if (dart.library.io) 'core/services/procm_logger_io.dart'
    if (dart.library.js_interop) 'core/services/procm_logger_web.dart';
import 'package:timeago/timeago.dart' as timeago;

// GetX 统一翻译导入
import 'package:aboutme/l10n/unified_translations.dart';
import 'package:aboutme/core/widgets/app_background.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/core/services/app_background_controller.dart';

// 第三方库国际化
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:syncfusion_localizations/syncfusion_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

// 条件导入：StyledToast 在 Web 平台有问题
// 默认使用存根，有 IO 库时（移动/桌面）使用真实实现
import 'utils/styled_toast_stub.dart'
    if (dart.library.io) 'package:flutter_styled_toast/flutter_styled_toast.dart';

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:skribble_icons_material/skribble_icons_material.dart';
import 'package:aboutme/core/services/ds_ink_motion_controller.dart';
import 'core/services/plugin_widget_sync_helper.dart';
import 'core/services/clipboard_service.dart';
import 'core/services/app_usage_service.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'screens/route.dart';
import 'core/route/route_history_manager.dart';
import 'screens/settings_screen/controllers/auto_update_controller.dart';

// 从 app_initializer 导入全局变量

void main() {
  StartupTrace.start();
  // 使用 runZonedGuarded 捕获所有未处理的异步异常
  runZonedGuarded(
    () async {
      // 0. 确保 WidgetsFlutterBinding 初始化（必须在任何平台通道操作之前）
      // 必须在 runZonedGuarded 内部调用，以避免 Zone 不匹配错误
      WidgetsFlutterBinding.ensureInitialized();
      StartupTrace.mark('binding_ready');

      // 1. 捕获 Flutter Framework 错误（如 widget build 错误）
      FlutterError.onError = (FlutterErrorDetails details) {
        // 记录到日志服务
        final logService = LogService.instance;
        if (logService.isEnabled && logService.isInitialized) {
          logService.error(
            'FlutterError: ${details.exception}',
            error: details.exception,
            stackTrace: details.stack,
          );
        }

        // 在调试模式下仍然显示错误界面
        if (kDebugMode) {
          FlutterError.presentError(details);
        }
      };

      // 2. 重写 debugPrint，让所有日志输出路由到 LogService
      // 这样无需修改现有的 debugPrint 调用
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message == null || message.isEmpty) return;

        // 在控制台仍然输出（开发环境方便调试）
        originalDebugPrint(message, wrapWidth: wrapWidth);

        // 同时记录到日志服务（如果启用）
        final logService = LogService.instance;
        if (logService.isEnabled && logService.isInitialized) {
          logService.info(message);
        }
      };

      // 启动壳不读取全局存储/配置，首帧显示后才加载真实应用。
      runApp(AppBootstrap(
        initialize: () async {
          await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
          registerSkribbleMaterialIcons();
          timeago.setLocaleMessages('zh', timeago.ZhMessages());
          setupLoggerFromEnv().info('Aboutme 启动', {
            'platform': defaultTargetPlatform.name,
          });
          await StartupTrace.measure('core', initializeApp);
          await StartupTrace.measure(
            'window',
            WindowGeometryService.instance.initialize,
          );
        },
        builder: (_) => const MyApp(),
      ));
      StartupTrace.mark('runApp');
      WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) {
        StartupTrace.mark('first_frame_rasterized');
      });
    },
    (error, stack) {
      // 捕获所有未处理的异步异常
      final logService = LogService.instance;
      if (logService.isEnabled && logService.isInitialized) {
        logService.error(
          'Uncaught Exception: $error',
          error: error,
          stackTrace: stack,
        );
      }

      // 未捕获异常同步转发到 procm 房间（未初始化时为静默级别，无副作用）
      getLogger().error('Uncaught Exception: $error', {
        'stack': stack.toString(),
      });

      // 在调试模式下打印到控制台（使用 print 而不是 debugPrint）
      if (kDebugMode) {
        print('Uncaught Exception: $error');
        print(stack);
      }
    },
  );
}

/// 处理小组件URI的包装组件
/// 在导航树上覆盖加载页，等待插件就绪后处理初始URI。
class WidgetUriHandler extends StatelessWidget {
  final Widget child;

  const WidgetUriHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStartupState.instance,
      builder: (context, child) {
        final startupState = AppStartupState.instance;
        final initialUri = startupState.initialWidgetUri;

        // 始终保留导航树，避免加载期间 Navigator 被移除而无法处理 URI。
        return Stack(
          fit: StackFit.expand,
          children: [
            child!,
            if (initialUri != null && startupState.isHandlingInitialUri)
              Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('core_starting'.tr),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      child: child,
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// 根据保存的 locale 获取初始 Locale
  Locale _getInitialLocale(Locale savedLocale) {
    final langCode = savedLocale.languageCode;
    if (langCode == 'zh') {
      return const Locale('zh', 'CN');
    } else if (langCode == 'en') {
      return const Locale('en', 'US');
    }
    return const Locale('zh', 'CN');
  }

  @override
  void initState() {
    super.initState();
    // 添加生命周期观察者
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      StartupTrace.mark('app_shell_frame');
      // 真实导航树出现后才启动插件，不和启动壳首帧争用主线程。
      unawaited(initializeBackgroundServices());
      _setupAutoUpdate();
      // 初始化Flutter悬浮球
      await initializeFlutterFloatingBall();
      // Web 平台检查 HTTP 存储服务器配置，未配置则弹设置对话框
      unawaited(ensureWebStorageBackend());
      // 远端存储服务器连接失败时提示用户并引导打开存储设置
      unawaited(promptRemoteStorageUnavailable());
      // App 累计使用时长统计（设置页信息栏展示）
      unawaited(AppUsageService.instance.init());
    });
  }

  @override
  void dispose() {
    // 移除生命周期观察者
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 应用从后台恢复到前台时同步待处理的小组件变更
    if (state == AppLifecycleState.resumed &&
        AppStartupState.instance.pluginsReady) {
      PluginWidgetSyncHelper.instance.syncPendingTaskChangesOnStartup();
      PluginWidgetSyncHelper.instance.syncPendingCalendarEventsOnStartup();
      PluginWidgetSyncHelper.instance.syncPendingGoalChangesOnStartup();
      PluginWidgetSyncHelper.instance.syncPendingHabitTimerChangesOnStartup();
      // 检查剪贴板数据
      ClipboardService.instance.processClipboard();
    }
  }

  void _setupAutoUpdate() {
    if (!mounted) return;
    final updateController = AutoUpdateController.instance;
    updateController.context = context;
  }

  Future<void> checkForUpdates() async {
    if (!mounted) return;

    final updateController = AutoUpdateController.instance;
    updateController.context = context;
    final hasUpdate = await updateController.checkForUpdates();
    if (hasUpdate) {
      updateController.showUpdateDialog(skipCheck: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        // 全局默认字体：851 手写杂书体（含中/英/日，与设计系统同源）
        fontFamily: 'TegakiZatsu',
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white, // 卡片背景设为纯白色
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white, // AppBar 背景设为纯白色
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ).copyWith(
          surface: Colors.white, // 表面颜色设为纯白色
          secondaryContainer: Colors.white, // 次要容器颜色设为纯白色
        ),
      ),
      dark: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'TegakiZatsu',
      ),
      initial: savedThemeMode ?? AdaptiveThemeMode.light,
      builder:
          (theme, darkTheme) {
            return ListenableBuilder(
              listenable: AppBackgroundController(),
              builder: (context, _) {
                // 设置全局主题背景（背景图/纯色）后，Scaffold/AppBar 纯色背景改为透明以透出背景
                final hasCustomBackground =
                    AppBackgroundController().hasCustomBackground;
                return GetMaterialApp(
                  translations: UnifiedTranslations(),
                  locale: _getInitialLocale(globalConfigManager.getLocale()),
                  fallbackLocale: const Locale('zh', 'CN'),
                  scaffoldMessengerKey: scaffoldMessengerKey,
                  navigatorKey: navigatorKey,
                  title: 'Aboutme',
                  debugShowCheckedModeBanner: false,
                  localizationsDelegates: const [
                    // 仅保留第三方库的国际化
                    SfGlobalLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                    FlutterQuillLocalizations.delegate,
                    // pro_image_editor v14 基于 material_ui，需要其本地化
                    //（否则编辑器内弹窗/按钮报 No MaterialLocalizations found）
                    ...material_ui.GlobalMaterialLocalizations.delegates,
                  ],
                  supportedLocales: const [
                    Locale('zh', 'CN'), // 中文
                    Locale('en', 'US'), // 英文
                  ],
                  theme:
                      hasCustomBackground ? _transparentSurfaces(theme) : theme,
                  darkTheme:
                      hasCustomBackground
                          ? _transparentSurfaces(darkTheme)
                          : darkTheme,
                      builder: (context, child) {
                        // 确保字体大小不受系统设置影响
                        // 根部全局包一层 DS 桥:根 Overlay/残留 Material 屏幕里的 DS 组件
                        // 不再因缺 AppTheme 祖树而 Null check 崩溃(幂等,已有桥处就近生效)
                        return ListenableBuilder(
                          // 全局墨线入场动画时长/开关（设置页可调，0 = 关闭）
                          listenable: DsInkMotionController(),
                          builder: (context, _) {
                            final motion = DsInkMotionController();
                            return WiredMotion(
                              enabled: motion.enabled,
                              drawDuration: Duration(
                                milliseconds: motion.durationMs,
                              ),
                              child: DSThemeBridge(
                                // 全局主题背景：垫在根 Navigator 之下，所有界面共用
                                child: AppBackground(
                                  child: MediaQuery(
                                    data: MediaQuery.of(
                                      context,
                                    ).copyWith(
                                      textScaler: const TextScaler.linear(1.0),
                                    ),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => FocusManager
                                          .instance
                                          .primaryFocus
                                          ?.unfocus(),
                                      child: StyledToast(
                                        child: WidgetUriHandler(child: child!),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                  initialRoute: AppRoutes.initialRoute,
                  onGenerateInitialRoutes: AppRoutes.generateInitialRoutes,
                  routes: AppRoutes.routes,
                  onGenerateRoute: AppRoutes.generateRoute,
                  navigatorObservers: [RouteHistoryManager()],
                  onGenerateTitle: (BuildContext context) => 'app_appTitle'.tr,
                );
              },
            );
          },
    );
  }

  /// 全局主题背景生效时，将界面纯色背景（Scaffold/AppBar）改为透明
  ThemeData _transparentSurfaces(ThemeData theme) {
    return theme.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
