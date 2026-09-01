# 数据模型

> 所属：lib/plugins/reminder · [返回索引](../CLAUDE.md)

## Reminder（`models/reminder.dart`）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String（uuid） | 唯一标识 |
| `title` / `content` | String | 标题 / 内容 |
| `imageUrl` | String? | 可选图片 |
| `frequency` | ReminderFrequency | 频率：none（手动）/ daily / weekly / monthly |
| `selectedDays` | List\<int\> | 周几（1-7，weekly）或日期（1-31，monthly） |
| `time` | TimeOfDay | 触发时刻 |
| `pushMethod` | ReminderPushMethod | localNotification / fcm（占位）/ both |
| `isEnabled` | bool | 启用状态 |
| `createdAt` / `lastTriggeredAt` / `nextTriggerAt` | DateTime? | 状态时间戳 |
| `groupId` | String? | 可选分组 |
| `priority` | int（0-3） | 优先级 |

## 枚举

- `ReminderFrequency`：`none`（手动触发）、`daily`、`weekly`、`monthly`。
- `ReminderPushMethod`：`localNotification`（当前实际生效）、`fcm`（占位）、`both`。

## 持久化与事件

- 序列化：`toJson` / `fromJson`（手写，未用 json_serializable）。
- 存储：`reminders.json`（ReminderService 的 `_storageKey`），经全局存储抽象读写。
- 事件：`ReminderEventArgs`（scheduler 触发提醒时携带实例），供外部监听。
