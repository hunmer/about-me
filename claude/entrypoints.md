# 入口与启动

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## Flutter 客户端：`lib/main.dart`

启动顺序（`main()` 内 `runZonedGuarded`）：

1. `WidgetsFlutterBinding.ensureInitialized()` + 早期注册 `registerSkribbleMaterialIcons()`（skribble 手绘图标）、timeago 中文
2. `Firebase.initializeApp`（项目 `test-3f050`，配置见 `firebase.json` / `lib/firebase_options.dart`）
3. 注册 FCM 后台消息处理器 `FirebaseMessaging.onBackgroundMessage`
4. 挂接 `FlutterError.onError` 与重写 `debugPrint` → 全部路由到 `LogService`
5. `initializeApp()`（见下）执行**最小同步初始化**
6. `runApp(const MyApp())`，其余初始化后台进行

`MyApp` → `AdaptiveTheme`（明暗主题）→ `WidgetUriHandler`（处理桌面小组件启动 URI）→ `GetMaterialApp`（`UnifiedTranslations` 中英双语、`AppRoutes` 路由表、`RouteHistoryManager` 观察者）。**启动路由为条件链（`lib/screens/route.dart`）：首启 `/onboarding`（引导页，完成后写 `onboardingCompleted`）→ `/startup`（startup_gate 启动闸门，等插件恢复完才建主页，避免先初始化 Live2D）→ 默认主页 `/jelly_home`（果冻小屋，四页签：小屋/日程/看板/我的）**。

## 核心初始化：`lib/core/app_initializer.dart`（2026-10 整体重写，现 651 行）

- `AppStartupState` 状态机：`coreReady`（存储+配置）→ `pluginsReady`（插件注册）→ `fullyReady`，驱动启动页进度。
- `initializeApp()` 初始化链：StorageManager → ConfigManager → PluginManager（经 `BuiltinPlugins.createAll()` 装载 28 个插件）→ JS Bridge → 前台服务 / 通知（aboutme_notifications）→ 快捷方式、悬浮球、FCM、数据迁移控制器等。
- `initializeApp()` 后 `WindowGeometryService.instance.initialize()`（桌面恢复窗口位置/大小）；首帧后 `AppUsageService.instance.init()`（前台使用时长/天数统计）。
- 应用回到前台时（`didChangeAppLifecycleState`）：同步小组件待处理变更、处理剪贴板。
- 全局默认字体：TegakiZatsu（851 手写杂书体，`pubspec.yaml` fonts）。

## Dart 同步服务器入口（现行）

| 服务 | 入口 | 启动 |
|------|------|------|
| aboutme_server | `packages/aboutme_server/bin/server.dart`（编译产物入口 `bin/aboutme-server`） | `procm-command start server`（默认端口 8874）；数据核心在 aboutme_data_sdk，服务器是薄壳 |
| MCP 端点 | `packages/aboutme_server/lib/src/mcp/mcp_endpoint.dart`（Streamable HTTP，挂载于主服务器 `/mcp`，68 工具） | 随 aboutme_server 启动 |

## 已删除入口

- `packages/server-nodejs/src/index.ts`（npm 包 `@hunmer/aboutme-server`）：2026-10-11 被 aboutme_server 取代，**2026-10-14 目录已彻底删除**，勿再引用其入口与 npm 命令。

## 构建与 CI

- 本地多平台打包：`scripts/build.sh`（读 `scripts/release_config.json`），发布用 `scripts/release.sh`。
- CI：`.github/workflows/` 下 `android-build.yml`、`ios-build.yml`、`windows-build.yml`、`macos-build.yml`、`web-deploy.yml`。
- Web 产物经 `vercel.json` 部署到 Vercel（静态托管 `build/web`）。
