# 入口与路由

> 所属：`lib/plugins/moments/` · [返回索引](../CLAUDE.md)

## 入口链

- 主类：`moments_plugin.dart` 的 `MomentsPlugin`（id `moments`，图标 `Icons.photo_camera_outlined`，色 `0xFF0088FF`）。
- 注册：`lib/core/builtin_plugins.dart`（`MomentsPlugin()`）。
- 初始化：`initialize()` → `MomentsService.instance.loadPosts()`；无 `registerJSAPI`（JS API 挂在 openai 插件）。

## 路由（`moments_route_handler.dart`，`PluginRouteHandler`）

| 路由 | 页面 |
|------|------|
| `/moments` | `MomentsHomeScreen` 宿主页（三页签：动态流/回忆/我的主页） |
| `/moments/profile?agentId={id}` | `MomentsProfileScreen`（无 agentId 为「我」） |

## 小组件

- `home_widgets/register_icon_widget.dart`：注册 1x1 简单图标小组件（经 `HomeWidgetRegistry` 体系，见 `home_widgets.dart` 汇出）。
