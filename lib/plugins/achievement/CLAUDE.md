# achievement 插件（成就系统）

[根目录](../../../CLAUDE.md) > [lib](../../) > [plugins](../) > **achievement**

成就系统插件（15 个 Dart 文件）：静态定义 74 个成就系列（A01~A74，五大分类，各最多 Lv5）+ 运行时进度结算（事件总线实时计数 + 打开成就页时全量快照校正）+ 升级发积分（对接 store 插件）+ 队列式达成弹窗 + 成就展览界面（概览卡 / 正在解锁 / 已解锁徽章墙 / 详情）。定义与 `docs/ACHIEVEMENT_SYSTEM_PLAN.md` 一一对应。

## 约定的规则

- 进度持久化在 `achievement/progress.json`（经 AboutmeDataService）；计数**只增不减**：事件增量累加（O(1)，删除源数据不回退），快照按 `max(当前值, 快照值)` 幂等结算。
- 新增/修改成就改 `data/achievement_definitions.dart`（静态表）；接入数据源两条路：发事件（在 controller 的 `_eventToAchievement` 映射里登记）或加快照取数（在 `stats/achievement_stats_providers.dart` 的 `buildStatProviders()` 里登记）。事件与快照可并存。
- 升级统一在 `_settle` 广播 `achievement_level_up`（弹窗与 home 小组件消费），积分经 store 插件 `controller.addPoints` 发放；等级奖励优先读 store 的 `pointAwardSettings['achievement_Lv$level']`，缺省用默认表 `[50,100,300,800,2000]`。
- `kPendingAchievementIds`（6 个）是尚未接入任何数据源的成就，展览界面显示「待接入」标记，勿当作 bug。
- 无 JS API、无路由处理器；主页经 `PluginManager.openPlugin` 打开，详情页走 `NavigationHelper.push`。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 双通道结算模型、控制器/结算器分工、与 store 的关系 | 第一次接触本插件 |
| [对外接口](claude/public-interfaces.md) | 事件总线映射、升级广播、home 小组件、Dart 层入口 | 跨模块对接 |
| [数据模型](claude/data-model.md) | AchievementDefinition/Progress 字段、等级配置、存储 | 改成就定义或数据结构 |
| [文件地图](claude/file-map.md) | 15 文件速查 + 相关外部文件 | 找代码 |
| [索引变更记录](claude/changelog.md) | 本文档更新历史 | 重复运行 /init-project 时 |

## 扫描状态

- 更新时间：2026-10-14（第六轮：首次生成）。
- 已扫描：主入口、控制器全部（事件映射 38+1 条、结算流程、积分发放、A74/A48/A59 特殊通道）、定义表全部 74 条、快照结算器与 providers 头部、展览/进行中/已解锁/详情 4 屏的职责、home 小组件与解锁弹窗、注册点与图标资产（74 个 webp）。
- 未深扫：providers 后半部分（A20 之后各快照取数的具体口径）、四屏与弹窗的 UI 细节、l10n 文案内容。
