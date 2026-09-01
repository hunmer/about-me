# memento_widgets 桌面小组件插件

Memento 的桌面小组件原生插件（Android/iOS 双平台，265 个文件，是 packages/ 下最复杂的子包）：基于 `home_widget` ^0.6 封装，Dart 侧由 `MyWidgetManager` 单例提供"写共享存储 + 触发刷新 + 渲染 Flutter Widget 为图片"的统一 API；Android 侧在 `android/src/main/kotlin/github/hunmer/memento/widgets/providers/` 下以 `BasePluginWidgetProvider` 为基类实现 **40+ 个 AppWidget Provider**（覆盖 20 个插件域的 1x1 与 2x1 两种尺寸，另有 Todo 四象限、签到月历、习惯计时等专用小组件与快速小组件）；iOS 侧本包仅是 19 行插件壳，WidgetKit 扩展与数据共享依赖 App Group `group.github.hunmer.memento`。

客户端消费点：`lib/core/app_widgets/home_widget_service.dart` 与 `core/services/plugin_widget_sync_helper.dart`（数据写入格式见 `models/plugin_widget_data.dart`）。

## 约定的规则

- 新增小组件：Android Provider（继承 `BasePluginWidgetProvider`）+ 在 `lib/memento_widgets.dart` 的 `_androidProviders` 映射注册完整包名 + 需要插件数据时在 `_getProviderNames` / `_getAllProviderNames` 补充。
- 数据传递：插件数据以 JSON 存入共享存储键 `{pluginId}_widget_data`（`updatePluginWidgetData`），原生侧自行解析渲染。
- iOS 走 App Group `group.github.hunmer.memento`（`_ensureInitialized` 自动设置）；桌面平台（非 Android/iOS）所有 API 静默返回空值。
- 本插件 example/ 为脚手架示例工程，与主应用无关。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 数据流、Provider 分类体系、双平台差异 | 理解小组件体系 |
| [对外接口](claude/public-interfaces.md) | MyWidgetManager API、pluginId→Provider 映射 | 从客户端调用 / 加新小组件 |
| [文件地图](claude/file-map.md) | 双平台源码清单 | 找 Provider 代码 |

## 模块索引

| 模块 | 说明 |
|------|------|
| `lib/memento_widgets.dart` | `MyWidgetManager`（核心 API）+ Provider 映射表 |
| `lib/models/` | `PluginWidgetData` / `WidgetStatItem`（共享数据模型） |
| `android/.../widgets/` | `BasePluginWidgetProvider` 基类 + 40+ Provider + 列表型 RemoteViews 工厂 |
| `ios/` | 插件壳（`MementoWidgetsPlugin.swift`）+ podspec + PrivacyInfo |
| `example/` | Flutter 插件示例工程 |
| 参考文档 | `docs/memento_widgets.md`、`docs/WIDGET_ARCHITECTURE_UNIFIED.md`、`docs/WIDGET_QUICK_REFERENCE_NEW.md` |

## 扫描状态

- 更新时间：2026-09-02（本次补扫）
- 已扫描：pubspec、全部 Dart API（memento_widgets.dart 全文）、Android Provider 清单、iOS 结构。
- 未深扫：各 Provider 的 Kotlin 布局/渲染细节、Android res/ 与 Manifest、example 工程。
