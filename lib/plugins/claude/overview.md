# 插件体系架构总览

> 所属：`lib/plugins/` · [返回索引](../CLAUDE.md)

## 基类链（两层）

- `lib/core/plugin_base.dart` — `abstract class PluginBase`：底层接口，定义全部生命周期与能力方法。
- `lib/plugins/base_plugin.dart` — `abstract class BasePlugin extends PluginBase`：插件实际继承的基类，主要增加 StorageManager 懒获取（优先注入，否则回退 `PluginManager.instance.storageManager`，否则抛 `StateError`），以及 `initializeDefaultData()`、`uninstall()`。

实际实现中 **6 个插件直接继承 `PluginBase`**（agent_chat、habits、nodes、tracker、bill、nfc），其余 20 个继承 `BasePlugin`（含 live2d）。

## PluginBase 生命周期与能力方法

| 方法 | 说明 |
|------|------|
| `id` / `storageDir` / `icon` / `color` | 元数据（icon 默认 `Icons.extension`，color 默认 `Colors.blue`） |
| `setStorageManager()` / `storage` | 存储注入（StorageManager，Web 用 WebStorage、移动端 MobileStorage，底层 JsonStorageEngine） |
| `loadSettings(defaults)` / `saveSettings()` / `updateSettings()` / `settings` | 插件配置持久化（路径来自 `ConfigManager.getPluginConfigPath(id)`） |
| `initialize()` | 抽象方法，初始化服务层 |
| `registerToApp(PluginManager, ConfigManager)` | 初始化后的应用级注册（默认空实现，如 reminder 在此启动调度器） |
| `buildMainView(context)` | 抽象方法，主视图 |
| `buildCardView(context)` / `buildSettingsView(context)` | 可选卡片/设置视图 |
| `refreshData([PluginRefreshDataArgs])` | 同步服务更新数据后回调（默认返回 false） |
| `supportsFileRefresh(filePath)` | 文件级刷新过滤（按存储前缀如 `'chat/'`、`'timer/'`） |
| `getPluginName(context)` | i18n 名称（GetX `.tr`） |

`PluginWidget`（`plugin_widget.dart`）是 19 行的 InheritedWidget，在 Widget 树中传递插件实例。

## 插件的四大能力扩展（不在基类内，经 mixin / 独立机制）

1. **JS API**：`core/js_bridge/js_bridge_plugin.dart` 的 `mixin JSBridgePlugin on PluginBase`——实现 `defineJSAPI()` 返回 `Map<String, Function>`，`initialize()` 末尾调 `registerJSAPI()` 注册到 `JSBridgeManager`（1186 行，支持延迟注册与 Web/IO 条件导入引擎）。约定 `initialize()` 最后一步是 `await registerJSAPI()`。
2. **路由**：两套机制汇合于 `lib/screens/route.dart`——声明式 `screens/routing/routes/*_routes.dart`（12 个插件）+ `plugin_common_routes.dart` 通用主页路由；命令式 `core/routing/plugin_route_handler.dart` 的 `PluginRouteHandler`（仅 checkin/todo/goods/habits/tracker 5 个，硬编码于 `AppRoutes._pluginRouteHandlers`，主要承接小组件/NFC 深链）。
3. **主页小组件**：各插件 `home_widgets/home_widgets.dart` 暴露 `void register()`，由 `core/app_widgets/home_widget_service.dart`（752 行）的 `initializeHomeWidgets()` 逐一调用，注册到 `screens/home_screen/managers/home_widget_registry.dart`。24 个插件有小组件（reminder、live2d 没有）。
4. **数据选择器**：`core/services/plugin_data_selector/` 的 `PluginDataSelectorService.registerSelector()`，插件经 `part` 文件 `*_data_selectors.dart` 注册（如 `chat.channel`、`openai.agent`），供悬浮球动作/UI 选择面板消费。

## 注册与运行

- 内置清单：`lib/core/builtin_plugins.dart` 的 `BuiltinPlugins._builders` 静态列表，共 **26 个**（顺序即注册顺序）：Chat、OpenAI、AgentChat、Diary、Activity、Checkin、Contact、Habits、Database、Timer、Todo、Day、Tracker、Store、Nodes、Notes、Goods、Bill、Calendar、CalendarAlbum、ScriptsCenter、TTS、Nfc、WebView、Reminder、Live2D。
- 实际装配：`core/app_initializer.dart` 的 `_registerPlugins()`——`globalConfigManager.isPluginEnabled(plugin.id)` 过滤禁用插件 → `Future.wait` 并发 `registerPlugin`（单个失败仅 debugPrint 不中断）。
- `PluginManager.registerPlugin()`（`core/plugin_manager.dart`，231 行，单例）：注入 StorageManager → `plugin.initialize()` → `plugin.registerToApp()` → 广播 `plugin_loaded` 事件。
- 插件统一经 `openPlugin()` 以 `/plugin/${plugin.id}` 路由名打开主视图。
- **单例访问模式**：`static XxxPlugin get instance` → 从 `PluginManager.instance.getPlugin('xxx')` 惰性获取，未注册抛 `StateError`。

## 分层与存储约定

- **17/26 插件走 UseCase 分层**：Repository/UseCase 接口放 `package:shared_models`，插件内实现 `client_*_repository.dart`。无 shared_models 的 6 个：webview、tts、nfc、scripts_center、reminder、live2d。
- 存储：统一 `plugin.storage`（StorageManager，JSON 文件 + 内存缓存），无数据库；database 插件的"数据库"也是 JSON 存储（`databases/databases.json`），查询能力在 JS API 层（结构化查询而非 SQL）。

## 跨插件协作枢纽

- `webview` 的 `LocalHttpServer`（默认 8899 端口）是全应用 HTTP API 底座 ← goods / store / contact / calendar_album 注册接口。
- `nfc` 的 `card_handlers/` 刷卡直达 checkin 打卡、goods 用量、habits 计时、tracker 进度。
- `scripts_center` 的脚本经 JSBridgeManager 可调所有暴露 `*_js_api` 的插件——全应用的自动化扩展层。
- `tts` 的消费方是 activity（活动播报）与 agent_chat（语音通话）；与 openai 无直接关联。
- AI 依赖链：`agent_chat → openai → chat`（详见各自 CLAUDE.md）。
