# media_log 对外接口

> 所属：lib/plugins/media_log · [返回索引](../CLAUDE.md)

## 路由

`MediaLogRouteHandler`（media_log_route_handler.dart，注册于 `lib/screens/route.dart:80` 的 `_pluginRouteHandlers`）：

| 路由 | 行为 |
|------|------|
| `/media_log` | 主视图（DSThemeBridge + Material 包裹 MediaListScreen） |
| `/media_log/detail?itemId={id}` | 条目详情页（MediaDetailScreen），缺 itemId 返回 null 交由后续处理 |

主入口仍为 `PluginManager.openPlugin` → 路由名 `/plugin/media_log`（打开 `buildMainView`）。

## JS API（media_log_js_api.dart，`defineJSAPI` 共 14 个注册名）

每个方法注册一个别名（同一函数），主名带 `Media` 前缀、别名不带。全部返回 JSON 字符串，失败返回 `{'error': ...}` 或 `{'success': false, 'error': ...}`。

| 方法（别名） | 参数 | 返回 |
|------|------|------|
| `getMediaItems`（`getItems`） | `kind?`（'reading' / 'watching'） | 全部条目 JSON 数组（含点评） |
| `getMediaItem`（`getItemById`） | `id` | 单条目 JSON；不存在返回 error |
| `createMediaItem`（`createItem`） | `kind`、`title`（必填非空），`author?`、`rating?`、`overview?`、`tags?`、`finishedAt?`（ISO8601）、`cover?`（CoverStyle 名，缺省 sheep）、`coverImage?` | 新建条目 JSON |
| `updateMediaItem`（`updateItem`） | `id` + 上述可选字段（按 copyWith 合并，字段传 null 保持原值） | 更新后条目 JSON |
| `deleteMediaItem`（`deleteItem`） | `id` | `{'success': true/false}` |
| `addMediaReview`（`addReview`） | `itemId`、`text`（必填非空），`rating?`、`timestamp?`（ISO8601，默认当前）、`author?`、`avatar?` | 新点评 JSON |
| `deleteMediaReview`（`deleteReview`） | `itemId`、`reviewId` | `{'success': true/false}` |

注意：JS 层不暴露 `coverImage` 之外的字段无遮拦修改；`updateMediaItem` 的 `finishedAt` 传无效字符串会经 `DateTime.tryParse` 得 null（保持原值的 copyWith 语义），不报错。

JS API 会被 agent_chat 的 `ToolConfigManager` 扫描 `*_js_api.dart` 自动生成工具描述，供 AI 工具调用感知——新增方法无需手工登记。

## Dart 层可调用能力

- `MediaLogPlugin.instance` 单例（经 PluginManager.getPlugin('media_log')）。
- `items` / `getItem(id)` / `getAllTags()` / `saveItem(item)` / `deleteItem(id)` / `saveReview(itemId, review)` / `deleteReview(itemId, reviewId)` / `newId()`。
- 变更订阅：`addListener(callback)` / `removeListener(callback)`（数据变化时 notifyListeners）。

## 无 home_widgets、无数据选择器

本插件未注册主页小组件与 PluginDataSelectorService 选择器。
