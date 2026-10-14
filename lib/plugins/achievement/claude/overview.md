# achievement 插件 · 架构总览

> 所属：lib/plugins/achievement · [返回索引](../CLAUDE.md)

## 定位

成就系统插件（15 个 Dart 文件）：消费全应用 28 个插件的行为事件与存量数据，把使用足迹结算成 74 个成就系列的等级进度（Lv1~Lv5），升级时广播事件、发积分、弹全局庆祝弹窗。它是纯"账本 + 展示层"——不产生业务数据，只读他源；反向依赖极少（store 发积分、core 事件总线）。

## 关键设计

- **双通道结算**（AchievementController）：
  - **事件增量** `recordProgress(id, delta)`：流水型行为（发消息、打卡、记账…），O(1) 自维护计数，删除源数据不回退。映射表 `_eventToAchievement` 38 条（载荷为 `Value<int>` 正整数时按数值增量，否则 +1）。
  - **快照结算** `setProgressValue(id, value)`：各插件存量统计（频道数、日记数…），`max(当前值, 快照值)` 只增不减幂等。
- **结算时机**：稳态全靠事件通道，启动时**不做**任何快照扫描；只在**打开成就页**时由 `AchievementStatsResolver.resolveAll()` 全量快照一遍（GalleryScreen initState 触发，异步不阻塞渲染），校正无事件通道的成就与历史存量。取数失败（插件未就绪）返回 null 跳过，下轮补齐。
- **进度模型**：`AchievementProgress{value, unlockedLevel, unlockedDates[], earnedPoints}`，`unlockedDates` 长度 = maxLevel，未解锁为 null。
- **升级链路**：`_settle` 逐级解锁 → 写 `unlockedDates`、累计积分 → 广播 `achievement_level_up`（AchievementLevelUpEventArgs）→ `StorePlugin.controller.addPoints`（store 未就绪跳过不阻塞）→ `_recomputeDeepPlayer`（A74 深度玩家 = 除自身外已解锁级数）。
- **特殊通道**（不走通用映射）：
  - A48 第一桶金：订阅 `store_cache_updated`，按 store 积分流水「获得」类累计结算。
  - A59 开始计时：订阅统一计时器完成事件，仅 `pluginId == 'timer'` 来源计数。
  - A67 多线程浏览：`_eventToAchievementMax`，载荷为「当前标签页数」按峰值结算（max 语义）。
  - A71/A72/A73：`collectRecordDayStats()` 跨 diary/bill/todo/checkin 四源统计「用过插件数 / 四类同天记录数 / 任一记录连续天数」。
- **等级视觉**（AchievementLevels）：Lv1 灰铁 / Lv2 青铜 / Lv3 白银 / Lv4 黄金 / Lv5 彩虹流光；默认积分奖励 `[50,100,300,800,2000]`（可在 store 设置覆盖）。图标资产 `assets/achievements/A01~A74.webp`（已核实 74 个文件）。
- **弹窗队列**：AchievementUnlockDialog 静态队列，在全局 `navigatorKey` 上依次 showDialog，4 秒自动关闭，界面未就绪时延迟重试、超时清空。

## 接入面

- 注册：`lib/core/builtin_plugins.dart:62`（`AchievementPlugin()`），列于全部业务插件之后（发分依赖 store 先就绪）。
- 主视图：`buildMainView` → ChangeNotifierProvider + AchievementGalleryScreen；另有 `buildCardView` 插件卡片（进度条）。主页小组件 `achievement_overview`（home_widgets/home_widgets.dart，进度环）。
- 无 JS API、无路由处理器。
