# 入口与启动

> 所属：lib/ 应用代码层 · [返回索引](../CLAUDE.md)

## `lib/main.dart`

```
runZonedGuarded
 ├─ WidgetsFlutterBinding.ensureInitialized()
 ├─ Firebase.initializeApp（lib/firebase_options.dart）
 ├─ FirebaseMessaging.onBackgroundMessage(fcmService 后台处理器)
 ├─ FlutterError.onError → LogService
 ├─ debugPrint 重定向 → LogService（同时保留控制台输出）
 ├─ initializeApp()            ← core/app_initializer.dart，最小同步初始化
 └─ runApp(MyApp)
      └─ AdaptiveTheme → WidgetUriHandler → GetMaterialApp
          · translations: UnifiedTranslations()（zh/en/ja）
          · initialRoute/routes/onGenerateRoute: AppRoutes（screens/route.dart）
          · navigatorObservers: RouteHistoryManager
```

要点：

- **快速启动策略**：`initializeApp()` 只做必要同步初始化，`runApp` 立即执行，其余初始化（悬浮球、自动更新检查等）在首帧后后台进行。
- `WidgetUriHandler`：若从桌面小组件 URI 启动，先显示加载页并直达目标页面（状态来自 `AppStartupState.initialWidgetUri`）。
- 生命周期（`_MyAppState.didChangeAppLifecycleState`）：回到前台时触发小组件待处理变更同步（任务/日历/目标/习惯计时）与剪贴板处理。
- 字体缩放锁定 1.0（`TextScaler.linear(1.0)`）；页面转场使用无动画 builder 优化键盘弹出性能。

## `core/app_initializer.dart`

- `AppStartupState`（单例 ChangeNotifier）：`coreReady` / `pluginsReady` / `fullyReady` 三段状态 + `loadingMessage`，驱动启动页。
- `initializeApp()` 初始化链（关键对象）：`StorageManager` → `globalConfigManager` → `PluginManager`（`BuiltinPlugins.createAll()` 装载 25 插件）→ `JSBridgeManager` → `memento_foreground_service` / `memento_notifications` → `ShortcutManager`、`FloatingBallService`、`ApiForwardingService`、`FCMService`、`DataMigrationController`、权限引导（移动端）等。
- 首帧后（`WidgetsBinding.addPostFrameCallback`）：自动更新检查、Flutter 侧悬浮球初始化。

## 路由挂载：`screens/route.dart`

- `AppRoutes.routes`（命名路由 Map，直接引用各插件主页面）+ `AppRoutes.generateRoute`（动态路由）+ `onGenerateRoute`。
- `screens/routing/`：`route_definition.dart` / `route_manager.dart` / `route_helpers.dart` 与 `routes/` 下 18 个注册表（core、test、widget_gallery、chat、diary、agent_chat、bill、calendar、notes、store、habits、tracker、activity、calendar_album、contact、todo、webview、plugin_common）。
- 插件专属 handler：checkin / todo / goods / habits / tracker 的 `*_route_handler.dart`，经 `core/routing/plugin_route_handler.dart` 分发。
