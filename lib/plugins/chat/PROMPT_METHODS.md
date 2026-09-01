# Chat 插件 Prompt 替换方法使用指南

本文档说明如何在 OpenAI 插件的 Prompt 中使用 Chat 插件提供的数据分析方法。

## 可用方法

### 1. chat_getMessages - 获取消息列表

获取指定频道和日期范围内的消息数据。

**参数：**
- `channelId` (可选): 频道ID，留空则获取所有频道的消息
- `startDate` (可选): 开始日期，格式 YYYY-MM-DD，默认今天
- `endDate` (可选): 结束日期，格式 YYYY-MM-DD，默认今天
- `mode` (可选): 数据模式，可选值：summary（默认）、compact、full

**使用示例：**

```
# 获取今天所有频道的消息摘要
{{chat_getMessages(mode: "summary")}}

# 获取特定频道的消息列表（紧凑模式）
{{chat_getMessages(channelId: "channel123", mode: "compact")}}

# 获取日期范围内的完整消息数据
{{chat_getMessages(startDate: "2025-01-01", endDate: "2025-01-31", mode: "full")}}

# 获取特定频道和日期范围的消息
{{chat_getMessages(channelId: "channel123", startDate: "2025-01-15", endDate: "2025-01-20", mode: "compact")}}
```

**返回格式：**

- **summary 模式**（仅统计）：
```json
{
  "sum": {
    "total": 100,
    "totalChannels": 3,
    "avgPerChannel": 33
  }
}
```

- **compact 模式**（简化记录，无 content）：
```json
{
  "sum": { "total": 10 },
  "recs": [
    {
      "id": "msg123",
      "channelId": "channel1",
      "type": "sent",
      "ts": "2025-01-15T09:00:00.000Z",
      "user": { "id": "user1" },
      "edited": "2025-01-15T10:00:00.000Z",
      "replyTo": "msg122",
      "fixed": "📌"
    }
  ]
}
```

- **full 模式**（完整数据）：
```json
{
  "recs": [
    {
      "id": "msg123",
      "channelId": "channel1",
      "content": "消息内容...",
      "type": "sent",
      "date": "2025-01-15T09:00:00.000Z",
      "user": { "id": "user1" },
      "editedAt": "2025-01-15T10:00:00.000Z",
      "fixedSymbol": "📌",
      "bubbleColor": "#FF5722",
      "metadata": {},
      "replyToId": "msg122"
    }
  ]
}
```

---

### 2. chat_getChannels - 获取频道列表

获取所有聊天频道的信息。

**参数：**
- `mode` (可选): 数据模式，可选值：summary（默认）、compact、full

**使用示例：**

```
# 获取频道统计摘要
{{chat_getChannels(mode: "summary")}}

# 获取频道列表（紧凑模式）
{{chat_getChannels(mode: "compact")}}

# 获取完整频道数据
{{chat_getChannels(mode: "full")}}
```

**返回格式：**

- **summary 模式**：
```json
{
  "sum": {
    "total": 5,
    "totalMessages": 1234
  }
}
```

- **compact 模式**：
```json
{
  "sum": {
    "total": 5,
    "totalMessages": 1234
  },
  "recs": [
    {
      "id": "channel1",
      "title": "工作群",
      "msgCnt": 456,
      "priority": 1,
      "groups": ["工作", "重要"]
    }
  ]
}
```

- **full 模式**：
```json
{
  "recs": [
    {
      "id": "channel1",
      "title": "工作群",
      "draft": "草稿内容...",
      "icon": 59574,
      "iconFontFamily": "MaterialIcons",
      "backgroundColor": "#2196F3",
      "priority": 1,
      "groups": ["工作", "重要"],
      "fixedSymbol": "⭐",
      "backgroundPath": "./backgrounds/bg1.jpg",
      "lastMessageTime": "2025-01-15T12:00:00.000Z",
      "metadata": {}
    }
  ]
}
```

---

### 3. chat_getStatistics - 获取消息统计

获取消息的统计分析数据。

**参数：**
- `channelId` (可选): 频道ID，留空则统计所有频道
- `startDate` (可选): 开始日期，格式 YYYY-MM-DD
- `endDate` (可选): 结束日期，格式 YYYY-MM-DD

**使用示例：**

```
# 获取今天所有频道的消息统计
{{chat_getStatistics()}}

# 获取特定频道的统计
{{chat_getStatistics(channelId: "channel123")}}

# 获取日期范围内的统计
{{chat_getStatistics(startDate: "2025-01-01", endDate: "2025-01-31")}}

# 获取特定频道和日期范围的统计
{{chat_getStatistics(channelId: "channel123", startDate: "2025-01-15", endDate: "2025-01-20")}}
```

**返回格式：**

```json
{
  "sum": {
    "total": 100,
    "byType": {
      "sent": 60,
      "received": 30,
      "file": 5,
      "image": 3,
      "audio": 2
    },
    "byChannel": {
      "channel1": 50,
      "channel2": 30,
      "channel3": 20
    }
  }
}
```

---

## 使用场景示例

### 场景 1：分析聊天活跃度

```
请分析我在 {{chat_getStatistics(startDate: "2025-01-01", endDate: "2025-01-31")}} 期间的聊天活跃度，总结：
1. 哪个频道最活跃
2. 每天平均发送多少条消息
3. 消息类型分布
```

### 场景 2：查找特定内容

```
以下是我最近的消息记录：
{{chat_getMessages(startDate: "2025-01-10", endDate: "2025-01-15", mode: "full")}}

请帮我找出所有关于"项目进度"的讨论。
```

### 场景 3：频道管理建议

```
根据我的频道使用情况：
{{chat_getChannels(mode: "compact")}}

请给我一些频道管理建议，比如哪些频道可以归档或合并。
```

### 场景 4：跨频道消息汇总

```
请汇总以下所有频道中关于"会议"的消息：
{{chat_getMessages(mode: "compact")}}

列出所有包含"会议"关键词的消息，并按时间排序。
```

---

## 数据模式选择建议

| 模式 | Token 消耗 | 适用场景 |
|------|-----------|---------|
| **summary** | 最少 (~200 tokens) | 只需要统计数据，不需要具体内容 |
| **compact** | 中等 (~1000 tokens) | 需要查看消息列表，但不需要完整内容 |
| **full** | 最多 (~5000+ tokens) | 需要完整数据进行详细分析 |

**建议：**
1. 优先使用 `summary` 模式获取概览
2. 如需详细分析，再使用 `compact` 或 `full` 模式
3. 对于大量数据，考虑缩小日期范围或指定频道ID

---

## 错误处理

如果方法执行失败，会返回包含错误信息的 JSON：

```json
{
  "error": "获取消息数据时出错",
  "details": "具体错误信息..."
}
```

---

## 注意事项

1. **日期格式**：支持 `YYYY-MM-DD` 和 `YYYY/MM/DD` 格式
2. **默认日期**：不提供日期参数时，默认为当天
3. **频道ID**：可通过 `chat_getChannels` 方法查看所有可用的频道ID
4. **性能考虑**：查询大量数据时建议使用 `summary` 或 `compact` 模式

---

## 版本信息

- **创建日期**: 2025-11-15
- **遵循规范**: Aboutme Prompt 数据格式规范 v2.0
- **依赖插件**: Chat Plugin v1.0, OpenAI Plugin v1.0
