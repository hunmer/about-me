# 开发约定

> 所属：lib/ 应用代码层 · [返回索引](../CLAUDE.md)

## 插件开发模式

```dart
class MyPlugin extends BasePlugin with JSBridgePlugin {
  @override
  String get id => 'my_plugin';

  @override
  Future<void> initialize() async {
    // 1. 初始化 Service 层  2. 注册数据选择器  3. 注册 JS API
    await registerJSAPI();
  }

  @override
  Map<String, Function> defineJSAPI() => {
    'getItems': _jsGetItems,
    'createItem': _jsCreateItem,
  };
}
```

- 注册：`core/builtin_plugins.dart` `_builders` 追加 `() => MyPlugin()`。
- 路由：新建 `screens/routing/routes/my_plugin_routes.dart` 并在 `screens/route.dart` 导入汇总。

## UseCase 分层（推荐）

```
MyPlugin（JS API 适配层）
  → MyUseCase（业务逻辑，shared_models/lib/usecases/）
  → ClientMyRepository（数据访问适配，实现 shared_models 的 Repository 接口）
  → MyService + MyController（具体实现）
```

迁移指南：`docs/USECASE_MIGRATION_GUIDE.md`。

## JS API 命名

`get{Entity}s`（分页列表）/ `get{Entity}ById` / `find{Entity}By{Field}` / `create{Entity}` / `update{Entity}` / `delete{Entity}`。

## 国际化

- 文案 key 用 GetX `.tr`；翻译集中在 `l10n/unified_translations.dart`（zh_CN / en_US / ja_JP，缺省回落 zh_CN）。
- 不要硬编码界面文案；第三方库 delegates 已在 `main.dart` 配齐（Syncfusion、Quill 等）。

## 主题与 UI

- 明暗主题经 `AdaptiveTheme`（`core/theme_controller.dart`），Material 3。
- 跨插件复用组件放 `widgets/`（memento_editor、form_fields、enhanced_calendar、data_selector_sheet 等），插件私有 UI 不外提。

## 其他

- 跨插件通信走 `core/event/` 事件总线，不直接 import 其他插件内部类。
- 桌面小组件数据同步统一走 `core/services/plugin_widget_sync_helper.dart`，勿在插件内自建通道。
- 动态 `IconData` 依赖 `tree-shake-icons: false`，新增图标需确认在 assets（`assets/icons/material/`）中可用。
