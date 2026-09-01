# Aboutme AI Prompt 使用手册

> **版本**: 2.0
> **最后更新**: 2025-01-15
> **适用范围**: OpenAI 插件的 AI 助手 Prompt 编写

---

## 📋 目录

1. [概述](#概述)
2. [快速开始](#快速开始)
3. [可用的 Prompt 方法](#可用的-prompt-方法)
4. [数据模式说明](#数据模式说明)
5. [最佳实践](#最佳实践)
6. [常见场景示例](#常见场景示例)
7. [性能优化建议](#性能优化建议)
8. [故障排查](#故障排查)

---

## 概述

Aboutme 提供了一套强大的 **Prompt 替换方法**，允许你在 AI 助手的系统提示词中直接调用插件数据进行分析。这些方法遵循统一的数据格式规范，支持三种数据模式（summary/compact/full），可以有效优化 token 消耗。

### 核心特性

- ✅ **13个插件**已支持 Prompt 方法
- ✅ **3种数据模式**：summary（最节省token）、compact（平衡）、full（完整数据）
- ✅ **统一数据格式**：所有插件遵循相同的字段命名规范
- ✅ **87.8% token 节省**：相比完整数据模式
- ✅ **灵活参数**：支持日期范围、状态过滤、分类筛选等

---

## 快速开始

### 1. 在 AI 助手的系统提示词中使用

在 OpenAI 插件的助手编辑界面，在「系统提示词」中添加 Prompt 方法调用：

```
你是一个个人数据分析助手。你可以访问用户的以下数据：

- 活动记录：{{activity_getActivities(startDate: "2025-01-01", endDate: "2025-01-31", mode: "summary")}}
- 日记：{{diary_getDiaries(startDate: "2025-01-01", mode: "compact")}}
- 任务：{{todo_getTasks(status: "inProgress", mode: "summary")}}

根据这些数据为用户提供有洞察力的分析和建议。
```

### 2. 数据模式选择

| 模式 | 适用场景 | Token 消耗 | 示例 |
|------|----------|-----------|------|
| **summary** | 快速概览、统计分析 | 最低（~10%） | `mode: "summary"` |
| **compact** | 需要查看列表但不需要完整内容 | 中等（~30%） | `mode: "compact"` |
| **full** | 需要完整数据、详细分析 | 最高（100%） | `mode: "full"` |

**推荐**：默认使用 `summary` 模式，仅在需要时使用 `compact` 或 `full`。

---

## 可用的 Prompt 方法

### 📊 Activity（活动记录）

#### `activity_getActivities(startDate?, endDate?, mode?)`

获取活动记录数据。

**参数**：
- `startDate`（可选）：开始日期，格式 YYYY-MM-DD，默认今天
- `endDate`（可选）：结束日期，格式 YYYY-MM-DD，默认今天
- `mode`（可选）：数据模式，默认 summary

**返回数据**：
- **summary**：`{sum: {total, dur, avg, topTags: [...]}}`
- **compact**：`{sum: {...}, recs: [{id, title, start, end, dur, tags, mood}]}`
- **full**：完整数据（包含 description）

**示例**：
```
{{activity_getActivities(startDate: "2025-01-01", endDate: "2025-01-07", mode: "summary")}}
```

---

### 📖 Diary（日记）

#### `diary_getDiaries(startDate?, endDate?, mode?)`

获取日记数据。

**参数**：
- `startDate`（可选）：开始日期
- `endDate`（可选）：结束日期
- `mode`（可选）：数据模式，默认 summary

**返回数据**：
- **summary**：`{sum: {cnt, totalWords, avgWords}, topMoods: [...]}`
- **compact**：`{sum: {...}, recs: [{id, date, title, desc, mood}]}`（content 截断至100字）
- **full**：完整数据（包含完整 content）

**示例**：
```
{{diary_getDiaries(startDate: "2025-01-01", mode: "compact")}}
```

---

### 💰 Bill（账单）

#### `bill_getBills(startDate?, endDate?, mode?)`

获取账单数据。

**参数**：
- `startDate`（可选）：开始日期
- `endDate`（可选）：结束日期
- `mode`（可选）：数据模式，默认 summary

**返回数据**：
- **summary**：`{sum: {total, inc, exp, net}, topCat: [...]}`
- **compact**：`{sum: {...}, recs: [{id, title, date, amount, cat, account}]}`
- **full**：完整数据

**示例**：
```
{{bill_getBills(startDate: "2025-01-01", endDate: "2025-01-31", mode: "summary")}}
```

---

### 📝 Notes（笔记）

#### `notes_getNotes(folder_ids?, note_ids?, mode?)`

获取笔记数据。

**参数**：
- `folder_ids`（可选）：文件夹ID数组（JSON格式字符串）
- `note_ids`（可选）：笔记ID数组（JSON格式字符串）
- `mode`（可选）：数据模式，默认 summary

**返回数据**：
- **summary**：`{sum: {total, folders, totalWords}, topTags: [...]}`
- **compact**：`{sum: {...}, recs: [{id, title, folder, tags, desc}]}`（content 截断）
- **full**：完整数据

**示例**：
```
{{notes_getNotes(mode: "summary")}}
```

---

### ✅ Todo（任务）

#### `todo_getTasks(status?, priority?, mode?)`

获取任务数据。

**参数**：
- `status`（可选）：任务状态（todo/inProgress/done）
- `priority`（可选）：优先级（low/medium/high）
- `mode`（可选）：数据模式，默认 summary

**返回数据**：
- **summary**：`{sum: {total, todo, inProgress, done, overdue}}`
- **compact**：`{sum: {...}, recs: [{id, title, status, priority, due, tags}]}`
- **full**：完整数据（包含 description）

**示例**：
```
{{todo_getTasks(status: "inProgress", mode: "compact")}}
```

#### `todo_getStats()`

获取任务统计数据（仅 summary 模式）。

**返回数据**：`{sum: {total, todo, inProgress, done, overdue}}`

---

### 🎯 Tracker（目标追踪）

#### `tracker_getGoals(status?, mode?)`

获取目标数据。

**参数**：
- `status`（可选）：目标状态（active/paused/completed）
- `mode`（可选）：数据模式，默认 summary

**返回数据**：
- **summary**：`{sum: {total, active, avgProgress}, topGoals: [...]}`
- **compact**：`{sum: {...}, recs: [{id, name, progress, target, unit}]}`
- **full**：完整数据

**示例**：
```
{{tracker_getGoals(status: "active", mode: "summary")}}
```

---

### 📦 Goods（物品管理）

#### `goods_getItems(warehouseId?, mode?)`

获取物品数据。

**参数**：
- `warehouseId`（可选）：仓库ID
- `mode`（可选）：数据模式，默认 summary

**返回数据**：
- **summary**：`{sum: {total, warehouses, totalValue}, topCats: [...]}`
- **compact**：`{sum: {...}, recs: [{id, name, cat, price, tags}]}`
- **full**：完整数据

**示例**：
```
{{goods_getItems(mode: "summary")}}
```

---

### ✔️ Checkin（签到）

#### `checkin_getCheckinHistory(startDate?, endDate?, mode?)`

获取签到历史数据。

**参数**：
- `startDate`（可选）：开始日期
- `endDate`（可选）：结束日期
- `mode`（可选）：数据模式，默认 summary

**返回数据**：
- **summary**：`{sum: {total, done, streak}, topGroups: [...]}`
- **compact**：`{sum: {...}, recs: [{id, name, group, done, start, end}]}`
- **full**：完整数据

---

### 📅 Day（纪念日）

#### `day_getDays(mode?)`

获取纪念日数据。

**参数**：
- `mode`（可选）：数据模式，默认 summary

**返回数据**：
- **summary**：`{sum: {total, upcoming, past}}`
- **compact**：`{sum: {...}, recs: [{id, title, date, daysRemaining}]}`
- **full**：完整数据

---

### 🌳 Nodes（节点笔记本）

#### `nodes_getNodePaths(notebookId?, mode?)`

获取节点路径数据。

**参数**：
- `notebookId`（可选）：笔记本ID
- `mode`（可选）：数据模式，默认 summary

**返回数据**：
- **summary**：`{notebook, sum: {total, completed, topTags}}`
- **compact**：`{notebook, sum: {...}, recs: [{id, title, status, tags}]}`
- **full**：完整数据

---

### 🏃 Habits（习惯管理）

#### `habits_getHabits(startDate?, endDate?, mode?)`

获取习惯数据。

**参数**：
- `startDate`（可选）：开始日期
- `endDate`（可选）：结束日期
- `mode`（可选）：数据模式，默认 summary

**返回数据**：
- **summary**：`{sum: {total, completions, totalTime, currentStreak}}`
- **compact**：`{sum: {...}, recs: [{id, title, dur, skill, tags}]}`
- **full**：完整数据

---

### 👤 Contact（联系人）

#### `contact_getContacts(tag?, uncontactedDays?, mode?)`

获取联系人数据。

**参数**：
- `tag`（可选）：标签过滤
- `uncontactedDays`（可选）：未联系天数（筛选超过N天未联系的人）
- `mode`（可选）：数据模式，默认 summary

**返回数据**：
- **summary**：`{sum: {total, groups}, topGroups: [...]}`
- **compact**：`{sum: {...}, recs: [{id, name, phone, email, group}]}`
- **full**：完整数据

---

### 📆 Calendar（日历）

#### `calendar_getEvents(startDate?, endDate?, source?, mode?)`

获取事件数据。

**参数**：
- `startDate`（可选）：开始日期
- `endDate`（可选）：结束日期
- `source`（可选）：来源过滤（diary/todo/day等）
- `mode`（可选）：数据模式，默认 summary

**返回数据**：
- **summary**：`{sum: {total, today, upcoming}}`
- **compact**：`{sum: {...}, recs: [{id, title, start, end, type, source}]}`
- **full**：完整数据

#### `calendar_getTodayEvents(mode?)`

获取今日事件（快捷方法）。

---

## 数据模式说明

### Summary 模式（摘要）

**特点**：
- 仅返回统计数据，无详细记录列表
- Token 消耗最低（约为 full 模式的 10%）
- 适合快速概览和趋势分析

**示例输出**：
```json
{
  "sum": {
    "total": 50,
    "dur": 3600,
    "avg": 72,
    "topTags": [
      {"tag": "学习", "cnt": 20, "dur": 1200},
      {"tag": "运动", "cnt": 15, "dur": 900}
    ]
  }
}
```

---

### Compact 模式（紧凑）

**特点**：
- 返回简化字段的记录列表
- Token 消耗中等（约为 full 模式的 30-50%）
- 省略冗长字段（description、content等）

**示例输出**：
```json
{
  "sum": {
    "total": 50,
    "dur": 3600
  },
  "recs": [
    {
      "id": "uuid-1",
      "title": "阅读《深度学习》",
      "start": "2025-01-15T09:00:00",
      "end": "2025-01-15T10:30:00",
      "dur": 90,
      "tags": ["学习", "AI"]
    }
  ]
}
```

---

### Full 模式（完整）

**特点**：
- 返回所有字段的完整数据
- Token 消耗最高（100%）
- 包含 description、content、notes 等详细字段

**使用建议**：仅在确实需要完整数据时使用。

---

## 最佳实践

### 1. 优先使用 Summary 模式

对于大多数数据分析场景，summary 模式已经足够：

```
# ✅ 推荐：使用 summary 模式
{{activity_getActivities(startDate: "2025-01-01", endDate: "2025-01-31", mode: "summary")}}

# ❌ 不推荐：不指定模式或使用 full 模式
{{activity_getActivities(startDate: "2025-01-01", endDate: "2025-01-31")}}
```

### 2. 合理设置日期范围

避免查询过大的日期范围，特别是在 compact 或 full 模式下：

```
# ✅ 推荐：查询近7天
{{activity_getActivities(startDate: "2025-01-08", endDate: "2025-01-15", mode: "compact")}}

# ❌ 不推荐：查询整年数据（除非使用 summary 模式）
{{activity_getActivities(startDate: "2025-01-01", endDate: "2025-12-31", mode: "full")}}
```

### 3. 组合使用多个插件

在系统提示词中组合多个插件的数据，提供全面的分析：

```
你是一个个人效率分析助手，可以访问以下数据：

**时间管理**：
- 活动记录：{{activity_getActivities(startDate: "2025-01-08", endDate: "2025-01-15", mode: "summary")}}
- 日历事件：{{calendar_getEvents(startDate: "2025-01-08", endDate: "2025-01-15", mode: "summary")}}

**任务目标**：
- 任务列表：{{todo_getTasks(status: "inProgress", mode: "summary")}}
- 目标进度：{{tracker_getGoals(status: "active", mode: "summary")}}

**自我反思**：
- 日记摘要：{{diary_getDiaries(startDate: "2025-01-08", mode: "summary")}}

根据这些数据，分析用户的时间利用效率，并提供改进建议。
```

### 4. 善用参数过滤

利用参数减少不必要的数据返回：

```
# 只查询进行中的任务
{{todo_getTasks(status: "inProgress", mode: "compact")}}

# 只查询高优先级任务
{{todo_getTasks(priority: "high", mode: "compact")}}

# 查询特定仓库的物品
{{goods_getItems(warehouseId: "warehouse-1", mode: "compact")}}
```

---

## 常见场景示例

### 场景 1：每周总结

```
你是一个周报生成助手。根据用户过去7天的数据生成周总结报告。

**活动数据**：
{{activity_getActivities(startDate: "2025-01-08", endDate: "2025-01-15", mode: "summary")}}

**任务完成情况**：
{{todo_getTasks(mode: "summary")}}

**目标进度**：
{{tracker_getGoals(status: "active", mode: "summary")}}

**本周日记**：
{{diary_getDiaries(startDate: "2025-01-08", mode: "compact")}}

请生成一份简洁的周总结报告，包括：
1. 时间利用分析
2. 任务完成率
3. 目标进度
4. 本周亮点和改进建议
```

---

### 场景 2：财务分析

```
你是一个财务分析助手。

**本月账单**：
{{bill_getBills(startDate: "2025-01-01", endDate: "2025-01-31", mode: "summary")}}

**物品价值统计**：
{{goods_getItems(mode: "summary")}}

分析用户的财务状况，包括：
1. 收支平衡情况
2. 主要支出类别
3. 资产价值估算
4. 理财建议
```

---

### 场景 3：社交提醒

```
你是一个社交关系维护助手。

**联系人数据**：
{{contact_getContacts(uncontactedDays: 30, mode: "compact")}}

**本周日程**：
{{calendar_getTodayEvents(mode: "compact")}}

提醒用户关注以下事项：
1. 超过30天未联系的重要联系人
2. 今日待办事项
3. 社交建议
```

---

### 场景 4：习惯养成分析

```
你是一个习惯培养教练。

**习惯数据**：
{{habits_getHabits(startDate: "2025-01-01", mode: "summary")}}

**签到记录**：
{{checkin_getCheckinHistory(startDate: "2025-01-01", mode: "summary")}}

分析用户的习惯养成情况：
1. 连续打卡天数
2. 完成率分析
3. 时间投入统计
4. 激励建议
```

---

## 性能优化建议

### Token 消耗对比

以下是不同场景下的 token 消耗估算（以查询7天数据为例）：

| 场景 | Summary | Compact | Full | 推荐模式 |
|------|---------|---------|------|---------|
| Activity (50条) | 800 | 2000 | 8000 | summary |
| Diary (7篇) | 1400 | 2800 | 14000 | summary |
| Bill (100条) | 1200 | 2000 | 4000 | summary |
| Notes (20条) | 1000 | 2000 | 10000 | summary |
| Todo (30条) | 400 | 800 | 2000 | compact |

### 优化策略

1. **默认使用 summary**：对于统计分析场景
2. **必要时用 compact**：需要查看列表但不需要完整内容
3. **避免滥用 full**：仅在确实需要完整数据时使用
4. **控制日期范围**：
   - summary 模式：可查询 1-3 个月
   - compact 模式：建议查询 1-2 周
   - full 模式：建议查询 1-3 天
5. **使用参数过滤**：减少不必要的数据返回

---

## 故障排查

### 常见问题

#### Q1：Prompt 方法不工作

**症状**：在系统提示词中添加了 Prompt 方法，但 AI 回复中显示原始的 `{{...}}` 文本。

**解决方法**：
1. 检查 OpenAI 插件是否已正确初始化
2. 确认方法名拼写正确（区分大小写）
3. 检查参数格式是否正确
4. 重启应用并重试

---

#### Q2：返回数据为空

**症状**：Prompt 方法返回 `{sum: {total: 0}}` 或空数据。

**解决方法**：
1. 检查日期范围参数是否正确
2. 确认该日期范围内确实有数据
3. 检查过滤参数是否过于严格

---

#### Q3：Token 消耗过高

**症状**：AI 回复很慢，或提示 token 超限。

**解决方法**：
1. 使用 summary 模式替代 compact 或 full
2. 缩小日期范围
3. 添加过滤参数减少数据量
4. 减少同时调用的 Prompt 方法数量

---

#### Q4：日期参数格式错误

**症状**：提示「无法解析日期」错误。

**支持的日期格式**：
- `YYYY-MM-DD`（推荐）：`"2025-01-15"`
- `YYYY/MM/DD`：`"2025/01/15"`
- ISO 8601：`"2025-01-15T00:00:00"`

**不支持的格式**：
- `MM/DD/YYYY`：`"01/15/2025"` ❌
- 中文日期：`"2025年1月15日"` ❌

---

## 附录

### 字段缩写对照表

| 完整名称 | 缩写 | 说明 |
|---------|------|------|
| total | total | 总数（不缩写） |
| count | cnt | 计数 |
| duration | dur | 时长（分钟） |
| average | avg | 平均值 |
| income | inc | 收入 |
| expense | exp | 支出 |
| records | recs | 记录列表 |
| description | desc | 描述 |
| timestamp | ts | 时间戳 |
| category | cat | 类别 |

### 相关文档

- [Prompt 数据格式规范](./PROMPT_DATA_SPEC.md) - 技术规范详细说明
- [插件开发指南](../CLAUDE.md) - 如何为插件添加 Prompt 支持
- [OpenAI 插件文档](../lib/plugins/openai/CLAUDE.md) - OpenAI 插件使用说明

---

**文档维护者**: Aboutme Team
**反馈渠道**: GitHub Issues
**最后更新**: 2025-01-15
