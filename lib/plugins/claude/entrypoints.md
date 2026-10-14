# 插件入口与生命周期挂载点

> 所属：`lib/plugins/` · [返回索引](../CLAUDE.md)

## 注册链（谁在何时创建插件）

1. `lib/main.dart` → `core/app_initializer.dart` 的 `initializeApp()`
2. 后台阶段 `_initializeBackgroundServices()` → **`_registerPlugins()`**：
   - `BuiltinPlugins.createAll()` 按 `_builders` 列表顺序实例化 28 个插件
   - `globalConfigManager.isPluginEnabled(plugin.id)` 过滤用户禁用的插件
   - `Future.wait` 并发 `PluginManager.registerPlugin(plugin)`（单个失败仅 debugPrint，不中断其他插件）
   - 完成后 `setPluginsReady`（AppStartupState 三阶段：coreReady / pluginsReady / fullyReady）
3. `PluginManager.registerPlugin()`：注入 StorageManager → `plugin.initialize()` → `plugin.registerToApp(this, configManager)` → 广播 `plugin_loaded` 事件（按 id 去重）

## 插件内的挂载时机

| 挂载点 | 用途 | 示例 |
|--------|------|------|
| `initialize()` | 服务层构建、默认数据、`registerJSAPI()`（惯例最后一步）、`_registerDataSelectors()` | 几乎全部插件 |
| `registerToApp()` | 需要 PluginManager/ConfigManager 的应用级注册 | reminder 在此启动调度器 |
| `initializeDefaultData()`（BasePlugin） | 首启灌入默认数据 | openai 默认智能体、chat 示例频道 |
| `uninstall()`（BasePlugin） | 卸载清理（删 storageDir、dispose 处理器） | openai |

## 小组件注册链

`core/app_widgets/home_widget_service.dart` 的 `initializeHomeWidgets()`（fullyReady 前的 unawaited 批次）→ 逐个调用 24 个插件的 `XxxHomeWidgets.register()` → 注册到 `screens/home_screen/managers/home_widget_registry.dart`。该文件同时处理桌面系统小组件（home_widget 包）点击 URI 导航。

## 打开插件

`PluginManager.openPlugin(context, plugin)` → `NavigationHelper.push(context, plugin.buildMainView(context), routeName: '/plugin/${plugin.id}')`，并 `recordPluginOpen` 记录访问历史（持久化于 `configs/plugin_manager.json`，供"最近使用"排序与 `autoOpenLastPlugin`）。

## 数据刷新入口（同步后）

同步服务写入插件存储目录后，按 `supportsFileRefresh(path)` 匹配前缀（如 `'timer/'`、`'chat/'`）→ 调 `refreshData(PluginRefreshDataArgs{filePath, source, timestamp})` → 插件重载 controller 数据并广播缓存事件。
