# 入口与启动

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## Flutter 客户端：`lib/main.dart`

启动顺序（`main()` 内 `runZonedGuarded`）：

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `Firebase.initializeApp`（项目 `test-3f050`，配置见 `firebase.json` / `lib/firebase_options.dart`）
3. 注册 FCM 后台消息处理器 `FirebaseMessaging.onBackgroundMessage`
4. 挂接 `FlutterError.onError` 与重写 `debugPrint` → 全部路由到 `LogService`
5. `initializeApp()`（见下）执行**最小同步初始化**
6. `runApp(const MyApp())`，其余初始化后台进行

`MyApp` → `AdaptiveTheme`（明暗主题）→ `WidgetUriHandler`（处理桌面小组件启动 URI）→ `GetMaterialApp`（`UnifiedTranslations` 三语言、`AppRoutes` 路由表、`RouteHistoryManager` 观察者）。**默认首页 `/jelly_home`（果冻小屋，`AppRoutes.initialRoute`，见 `lib/screens/route.dart`）**，四页签底部导航（小屋/日程/看板/我的）。

## 核心初始化：`lib/core/app_initializer.dart`

- `AppStartupState` 状态机：`coreReady`（存储+配置）→ `pluginsReady`（插件注册）→ `fullyReady`，驱动启动页进度。
- `initializeApp()` 初始化链：StorageManager → ConfigManager → PluginManager（经 `BuiltinPlugins.createAll()` 装载 26 个插件）→ JS Bridge → 前台服务 / 通知（aboutme_notifications）→ 快捷方式、悬浮球、FCM、数据迁移控制器等。
- 应用回到前台时（`didChangeAppLifecycleState`）：同步小组件待处理变更、处理剪贴板。

## Node.js 服务端入口

| 服务 | 入口 | 启动 |
|------|------|------|
| 同步服务器 | `packages/server-nodejs/src/index.ts`（CLI 入口 `bin/aboutme-server.js`，npm 包名 `@hunmer/aboutme-server`） | `npm run dev` / `npm start`（默认端口 8874） |
| MCP 端点 | `packages/server-nodejs/src/mcp/index.ts`（Streamable HTTP，挂载于主服务器 `/mcp`） | 随 server-nodejs 启动 |

`server-nodejs` 的 `main()` 顺序：读取配置（`src/config/serverConfig.ts`）→ 初始化 `FileStorageService`（data 目录）→ AuthService / PluginDataService / PluginService / WebSocketManager / FileWatcherService → 挂载 `authRoutes`、`syncRoutes`、`pluginRoutes`、`pluginSystemRoutes` → 静态托管管理面板 `admin/`。

## 构建与 CI

- 本地多平台打包：`scripts/build.sh`（读 `scripts/release_config.json`），发布用 `scripts/release.sh`。
- CI：`.github/workflows/` 下 `android-build.yml`、`ios-build.yml`、`windows-build.yml`、`macos-build.yml`、`web-deploy.yml`。
- Web 产物经 `vercel.json` 部署到 Vercel（静态托管 `build/web`）。
