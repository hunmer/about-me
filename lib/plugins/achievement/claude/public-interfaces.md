# achievement 对外接口

> 所属：lib/plugins/achievement · [返回索引](../CLAUDE.md)

## 路由与 JS API

**均无**：未 mixin JSBridgePlugin、未注册 PluginRouteHandler。主页经 `PluginManager.openPlugin` → `/plugin/achievement` 打开 GalleryScreen；详情页由列表项经 `NavigationHelper.push(AchievementDetailScreen(def, controller))` 进入。

## 事件总线（lib/core/event/event_manager.dart）

### 消费的事件（实时计数来源）

`AchievementController` 订阅 39 个信号（`_eventToAchievement` 38 条 + `_eventToAchievementMax` 1 条），按四组分：

| 分组 | 事件 → 成就（节选） |
|------|------|
| 流水型（9） | `chat_message_sent`→A01、`diary_entry_created`→A14、`activity_added`→A17、`checkin_completed`→A23、`task_completed`→A26、`note_added`→A29、`bill_added`→A42、`goods_item_added`→A45、`onRecordAdded`→A55 |
| 创建型（18） | `chat_channel_added`→A02、`openai_agent_added`→A08、`prompt_preset_added`→A09、`moment_posted`→A10、`live2d_model_added`→A12、`task_added`→A28、`nodes_node_added`→A31、`memorial_day_added`→A34、`calendar_event_added`→A36、`account_added`→A44、`contact_created`→A51、`contact_interaction_added`→A52、`database_added`→A56、`database_record_added`→A57、`checkin_item_added`→A25、`note_folder_added`→A30、`reminder_added`→A40、`goods_warehouse_added`→A46 |
| 行为埋点（8） | `tts_spoken`→A61、`live2d_tts_spoken`→A13、`agent_chat_user_message`→A05、`agent_chat_tool_called`→A07、`tracker_goal_completed`→A54、`node_status_done`→A32、`webview_card_opened`→A65、`script_executed`→A68 |
| 数值增量（3，载荷 `Value<int>`） | `goods_usage_recorded`→A47、`activity_duration_added`→A18、`album_photo_added`→A38 |

另加 max 语义 1 条：`webview_tab_created`→A67（载荷 = 当前标签页数，按峰值结算）。

专用订阅 2 个：`TimerEventNames.timerCompleted`→A59（仅 timer 插件来源）、`store_cache_updated`→A48（按 store 积分流水累计）。

载荷约定：携带 `Value<int>` 正整数时按数值增量累加，否则 +1。**其他插件发新事件记成就，要在 controller 映射表登记一次**。

### 广播的事件

`achievement_level_up`（`AchievementLevelUpEventArgs`：achievementId / name / condition（含阈值与单位）/ iconAsset / level / unlockedAt / points）。消费方：本插件解锁弹窗（enqueue）、home 小组件（EventListenerContainer 刷新）。

## 主页小组件

`achievement_overview`（home_widgets/home_widgets.dart，`register()` 注册）：进度环 + 累计积分 + 最近达成，SmallSize / MediumSize 两档，点击 openPlugin 进成就页。

## Dart 层可调用能力

- `AchievementPlugin.instance` 单例；`controller`（AchievementController）。
- `resolveStats()`：手动触发一次全量快照结算（幂等）。
- `AchievementController`：`progressOf(id)` / `unlockedDateOf(id, level)` / `recordProgress` / `setProgressValue` / `debugUnlockTo(id, level)`（调试演示用）/ 统计 getter（`totalLevels` / `unlockedLevels` / `overallProgress` / `totalEarnedPoints` / `lastUnlockedAt`）。
