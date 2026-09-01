# reminder 定时提醒插件

Aboutme 的第 25 个内置插件（`id: reminder`，名称"定时提醒"），负责**本地定时提醒**：按每天/每周/每月（或手动）频率在指定时刻触发本地通知。结构极简（10 个文件）：`ReminderService` 负责 CRUD 与持久化（存储键 `reminders.json`），`ReminderScheduler` 周期轮询到期提醒并补触发错过的提醒，`ReminderNotificationService` 发送本地通知；UI 为列表页 + 表单页。未接入 shared_models（无 Repository/UseCase），也不提供 JS API。

## 约定的规则

- 数据持久化键固定为 `reminders.json`（ReminderService），改结构需考虑旧数据兼容。
- 调度基于应用内周期 `Timer`（ReminderScheduler），应用被杀后靠 `_checkMissedReminders` 启动补触发；不要假设系统级精确定时。
- 插件在 `registerToApp` 阶段才启动调度器（晚于 `initialize`）。
- 通知统一走 `ReminderNotificationService`，勿在插件内直接调通知插件 API。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 分层、启动流程、服务协作 | 改调度/通知逻辑前 |
| [数据模型](claude/data-model.md) | Reminder 字段、枚举、序列化 | 改数据结构前 |

## 模块索引

| 模块 | 说明 |
|------|------|
| `reminder_plugin.dart` | 插件入口（单例 `ReminderPlugin.instance`） |
| `models/reminder.dart` | Reminder 模型与频率/推送枚举 |
| `services/reminder_service.dart` | CRUD + 持久化 |
| `services/reminder_scheduler.dart` | 周期调度 + 错过补触发 + 事件 |
| `services/reminder_notification_service.dart` | 本地通知发送 |
| `screens/reminder_list_screen.dart` · `reminder_form_screen.dart` · `components/` | 列表 / 表单 / 卡片与空态 |
| `controllers/reminder_list_controller.dart` | 列表状态控制器 |

## 扫描状态

- 更新时间：2026-09-02（本次补扫，此前为 25 插件中唯一无文档者）
- 已扫描：全部 10 个文件的职责与关键实现（入口、模型、服务层）。
- 未深扫：UI 组件内部布局细节。
