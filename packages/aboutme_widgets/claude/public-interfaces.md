# 对外接口

> 所属：packages/aboutme_widgets · [返回索引](../CLAUDE.md)

## Dart API：`MyWidgetManager`（单例，`lib/aboutme_widgets.dart`）

| 方法 | 说明 |
|------|------|
| `saveString / saveInt / saveBool / saveDouble(key, value)` | 写入小组件共享存储（非移动平台直接返回 false/null） |
| `getData<T>(key)` | 读取共享存储 |
| `updateWidget({widgetName})` | 触发指定 Provider 刷新；不传则刷新 Text/Image 两个示例小组件 |
| `renderFlutterWidget(widget, {key, logicalSize, pixelRatio})` | 将 Flutter Widget 渲染为图片存入共享存储 |
| `registerInteractivityCallback(fn)` | 注册小组件点击等交互回调 |
| `getInitialUri()` | 应用由小组件启动时的初始 URI（配合 `WidgetUriHandler`） |
| `updatePluginWidgetData(pluginId, PluginWidgetData)` | 写 `{pluginId}_widget_data` JSON 并刷新对应小组件（**插件数据主入口**） |
| `updatePluginWidget(pluginId)` | 仅刷新某插件的小组件（1x1 + 2x1） |
| `updateAllPluginWidgets()` | 刷新全部插件小组件 |

另有 `AboutmeWidgets.getPlatformVersion()`（MethodChannel `aboutme_widgets`，模板遗留）。导出模型：`PluginWidgetData`、`WidgetStatItem`。

## pluginId → Provider 映射规则

- **专用小组件**（单 Provider）：`checkin_item`、`checkin_month`、`todo_list`、`todo_quadrant`、`checkin_weekly_list`、`tracker_goal`、`habit_timer`、`habits_weekly`、`habit_group_list`。
- **通用插件域**（同时更新 1x1 + 2x1 两个 Provider）：`todo`、`timer`、`bill`、`calendar`、`activity`、`tracker`、`habits`、`diary`、`checkin`、`nodes`、`database`、`contact`、`day`、`goods`、`notes`、`store`、`openai`、`agent_chat`、`calendar_album`、`chat`。
- 快速小组件：`ChatQuickWidgetProvider`、`AgentVoiceWidgetProvider`（quick 子包）。

## 平台约束

- iOS App Group：`group.github.hunmer.aboutme`（首次调用自动 `setAppGroupId`）。
- Android Provider 完整包名映射表：`MyWidgetManager._androidProviders`（新增 Provider 必须在此注册）。
