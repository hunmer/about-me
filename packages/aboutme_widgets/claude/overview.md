# 架构总览

> 所属：packages/memento_widgets · [返回索引](../CLAUDE.md)

## 数据流

```mermaid
graph LR
    App[Flutter 应用<br/>plugin_widget_sync_helper] -->|saveString '{pluginId}_widget_data'<br/>JSON = PluginWidgetData| M[MyWidgetManager<br/>本包 Dart 层]
    M -->|HomeWidget API| HW[home_widget 插件]
    HW -->|App Group / SharedPreferences| A[Android AppWidgetProvider<br/>40+ 个]
    HW -->|App Group group.github.hunmer.memento| I[iOS WidgetKit 扩展<br/>在主应用 ios 工程内]
    M -->|updateWidget 触发刷新| A
```

要点：

- 小组件是**拉取式**渲染：应用侧写共享存储 → 触发 `updateWidget` → 原生 Provider 在 onUpdate 时从共享存储读 JSON 自行渲染。
- `renderFlutterWidget` 可把任意 Flutter Widget 渲染成图片存入共享存储（供 ImageWidget 类小组件使用），实现"Flutter UI 上桌面"。

## Provider 分类体系（Android）

| 类别 | 数量 | 示例 |
|------|------|------|
| 插件小组件 1x1 | 20 | `TodoWidgetProvider`、`BillWidgetProvider`…（每插件域一个） |
| 插件小组件 2x1 | 20 | `TodoWidget2x1Provider`…（同域放大版） |
| 专用小组件 | 9 | `TodoQuadrantWidgetProvider`（四象限）、`CheckinMonthWidgetProvider`（签到月历）、`HabitTimerWidgetProvider`（习惯计时）、`TrackerGoalWidgetProvider`、`TodoListWidgetProvider`、`CheckinItemWidgetProvider`、`CheckinWeeklyListWidgetProvider`、`HabitsWeeklyWidgetProvider`、`HabitGroupListWidgetProvider` |
| 快速小组件 | 2 | `ChatQuickWidgetProvider`（quick 包）、`AgentVoiceWidgetProvider` |
| 扩展视图 | 若干 | `ActivityDaily/Weekly`、`CalendarMonth`、`CalendarTodayList`、`BillShortcuts`；列表型带 `*RemoteViewsFactory` + `*WidgetService` |
| 示例 | 2 | `TextWidgetProvider`、`ImageWidgetProvider`（根包名下） |

## 双平台差异

- **Android**：全部 Provider 在本包实现（包名 `github.hunmer.memento_widgets`，providers 子包 `github.hunmer.memento.widgets.providers`）；列表型小组件用 RemoteViewsService + Factory。
- **iOS**：本包 Swift 侧仅 19 行插件注册壳；实际 WidgetKit 小组件扩展位于主应用 `ios/` 工程，与本包经 **App Group `group.github.hunmer.memento`** 共享 UserDefaults 数据（由 home_widget 机制承载）。

## 设计取舍

- 以 `_androidProviders` 静态映射维护"简单类名 → 完整包名"，`updateWidget` 同时传 iOS 名与 Android 合限定名，屏蔽双平台命名差异。
- 专用小组件（如 todo_quadrant）不走通用 `{pluginId}_widget_data` 的 1x1/2x1 双尺寸更新，而是单独的 provider 名列表（见 [对外接口](public-interfaces.md)）。
