# 对外接口

> 所属：packages/mcp-memento-server · [返回索引](../CLAUDE.md)

## 工具命名与清单

命名规范：`memento_{plugin}_{action}`。定义集中在 `src/tools/index.ts`（完整参数 Schema 以该文件为准）。2026-09 扫描到的工具域与代表性工具：

| 域 | 工具（示例） |
|----|--------------|
| chat | getChannels / createChannel / updateChannel / deleteChannel；getMessages / sendMessage / deleteMessage / searchMessages |
| notes | getNotes / createNote / updateNote / deleteNote / searchNotes |
| activity | getActivities / createActivity / updateActivity / deleteActivity / getTodayStats |
| goods | getWarehouses / getItems / createItem / updateItem / deleteItem / searchItems |
| bill | getAccounts / getBills / createBill / updateBill / deleteBill / getStats |
| todo | getTasks / createTask / updateTask / completeTask / getTodayTasks / getOverdueTasks |
| diary | 日记增删改查（`memento_diary_*`） |
| checkin | 签到记录（`memento_checkin_*`） |
| calendar | 日历事件（`memento_calendar_*`） |
| contact | 联系人（`memento_contact_*`） |
| tracker | 目标追踪（`memento_tracker_*`） |
| day | 纪念日（`memento_day_*`） |

（chat/notes/activity/goods/bill/todo 六域工具名已逐条核实，其余六域在 `src/tools/index.ts` 中按同一模式定义。）

## 传输与协议

- stdio 传输上的 MCP 协议（JSON-RPC 2.0），由 `@modelcontextprotocol/sdk` 处理握手与工具调用。

## 下游依赖接口

- 每个工具调用经 `MementoClient` 转 server-nodejs 的插件数据 REST API；认证用 `MEMENTO_API_KEY`，敏感载荷用 `MEMENTO_ENCRYPTION_KEY` 加密。
