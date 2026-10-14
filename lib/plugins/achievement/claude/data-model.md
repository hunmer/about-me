# achievement 数据模型与存储

> 所属：lib/plugins/achievement · [返回索引](../CLAUDE.md)

## 模型

### AchievementDefinition（models/achievement_definition.dart，8 个字段，纯静态）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | 编号，如 A01 |
| `name` | String | 成就名，如 千言万语 |
| `category` | String | 分类 id：ai / life / asset / tool / overall |
| `condition` | String | 达成条件描述，如「累计发送频道消息」 |
| `unit` | String | 计数单位：条 / 个 / 次 / 天… |
| `thresholds` | List\<int\> | 各等级阈值（升序），长度即最高等级数 |
| `hidden` | bool | 隐藏成就（未解锁显示 ???），默认 false |
| `event` | String? | 事件总线信号名；null = 该成就未（单独）接事件通道 |

派生：`maxLevel = thresholds.length`、`iconAsset = 'assets/achievements/$id.webp'`、`rewardFor(level)`、`levelForValue(value)`（当前累计值对应的最高已解锁等级）。

### AchievementProgress（controllers/achievement_controller.dart，4 个字段，运行时）

| 字段 | 类型 | 说明 |
|------|------|------|
| `value` | int | 当前累计值（只增不减） |
| `unlockedLevel` | int | 已解锁最高等级（0 = 未解锁） |
| `unlockedDates` | List\<DateTime?\> | 各等级获得时间，长度 = maxLevel |
| `earnedPoints` | int | 通过本成就累计获得积分 |

### AchievementLevels（等级配置）

- 积分奖励（Lv1~Lv5）：`[50, 100, 300, 800, 2000]`；实际发放优先读 store 的 `pointAwardSettings['achievement_Lv$level']`。
- 边框色：Lv1 灰铁 `0xFF8D99AE` / Lv2 青铜 `0xFFCD7F32` / Lv3 白银 `0xFFB8C0C8` / Lv4 黄金 `0xFFF5C518` / Lv5 彩虹 `0xFFFF6B9D`（渲染为流光）；0 = 未解锁灰。
- Lv5 彩虹渐变色组 `rainbowColors`（6 色）。

### 事件参数

`AchievementLevelUpEventArgs`（7 字段）：achievementId / name / condition / iconAsset / level / unlockedAt / points。

## 静态定义表（data/achievement_definitions.dart）

- `kAchievementCategories`：5 分类（ai、life、asset、tool、overall）。
- `kAchievementDefinitions`：74 条（A01~A74），与 docs/ACHIEVEMENT_SYSTEM_PLAN.md V3 表格一一对应。各分类条数：AI 13（A01~A13）、生活 28（A14~A41）、物品账务 14（A42~A55）、工具系统 15（A56~A70）、跨插件综合 4（A71~A74）。
- 隐藏成就 2 个：A11 赛博知己、A53 社交蝴蝶。
- `kAchievementById`：按编号索引的 Map。
- `kPendingAchievementIds`（6 个，无事件且无快照，展览显示「待接入」）：A06、A33、A35、A41、A63、A64。

## 存储

| 路径 | 内容 |
|------|------|
| `achievement/progress.json` | `{成就编号: AchievementProgress.toJson()}`，经 AboutmeDataService 读写；读取时只接受 `kAchievementById` 中存在的编号，仅升级时保存 |

## 快照取数（stats/achievement_stats_providers.dart）

`buildStatProviders()` 返回 57 个 `成就编号 → (来源插件id, 取数函数)`；取数函数约定返回 `null` = 数据源未就绪跳过，异常经 `_guard` 吞掉打日志。另有 `collectRecordDayStats()`（A72/A73）与 resolver 内联的 A71 统计。
