# 插件开发约定

> 所属：`lib/plugins/` · [返回索引](../CLAUDE.md)
> 根级通用约定（命令、代码风格、构建）见 [根 conventions](../../../claude/conventions.md)。

## 新插件步骤

1. 建目录 `lib/plugins/<name>/`，主类文件 `<name>_plugin.dart`。
2. 在 `lib/core/builtin_plugins.dart` 的 `_builders` 列表注册 builder。
3. 有路由则到 `lib/screens/routing/routes/` 建声明式路由，或加入 `plugin_common_routes.dart`；深链/小组件跳转用 `PluginRouteHandler`（参考 `todo_route_handler.dart`）。
4. 有桌面小组件则建 `home_widgets/home_widgets.dart` 暴露 `register()`，并在 `core/app_widgets/home_widget_service.dart` 的 `initializeHomeWidgets()` 中调用。
5. 接口放 `shared_models/`（Repository + UseCase），插件内实现 `client_<name>_repository.dart`。

## 主类模式

```dart
class XxxPlugin extends BasePlugin with ChangeNotifier, JSBridgePlugin {
  XxxPlugin._();
  static XxxPlugin get instance =>
      PluginManager.instance.getPlugin('xxx') as XxxPlugin; // 单例，未注册抛 StateError

  @override
  Future<void> initialize() async {
    // 服务层初始化……
    await registerJSAPI();     // 惯例：最后一步
    _registerDataSelectors();  // JSBridgePlugin 之后
  }
}
```

- 基类选择：默认 `BasePlugin`；`PluginBase` 仅 6 个插件直接用（agent_chat/habits/nodes/tracker/bill/nfc）。
- 需要 UI 刷新的插件加 `ChangeNotifier` mixin（todo/bill/tracker/chat/notes/webview 等）。

## JS API 规范

- 命名：`get{Entity}s` / `create{Entity}` / `update{Entity}` / `delete{Entity}` / `find{Entity}By(Id|Name|...)`。
- 用 `part '<name>_js_api.dart';` 拆出实现文件（part of 主类文件）。
- **注意**：chat 插件主类 `defineJSAPI()` 当前返回空 map，part 文件里的完整实现未挂接（迁移中间态）——扩展 chat JS API 前先核实 `chat_plugin.dart:143`。
- 数据选择器同样用 part 文件 `<name>_data_selectors.dart`，`_registerDataSelectors()` 中注册。

## 数据与同步

- 存储统一走 `plugin.storage`（JSON 文件），不引入数据库。
- 参与同步的插件重写 `supportsFileRefresh`（返回存储前缀如 `'notes/'`）+ `refreshData`（重载 controller 数据）。
- 事件用 `EventManager.instance.subscribe/broadcast`，自定义 EventArgs 放 `events/` 子目录（参考 diary 的 `DiaryEntryCreatedEventArgs`、tracker 的携带数据缓存事件）。

## 目录与命名

- 典型结构：`models/ repositories/ services|controllers/ screens|views/ widgets/ home_widgets/ l10n/`（子目录名允许 screens/views、services/controllers 两种风格并存，新插件建议 screens + services）。
- 单文件 ≤1000 行，超限用 `part` 拆分；snake_case 文件名；中文注释。
- i18n：`getPluginName` 返回 `'<id>_name'.tr`（GetX），翻译放插件 `l10n/`。

## 已知例外（勿"顺手统一"）

- bill 用 `controls/`（非 controllers）、timer 用 `views/`（非 screens）、calendar 的 `pages/` 与 `screens/` 并存——历史结构，重构前先确认引用面。
- reminder 无路由、无小组件、无 JS API（纯本地通知调度）。
- nfc 无路由（刷卡触发，不走导航）。
