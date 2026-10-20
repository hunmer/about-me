# 插件对外接口全景

> 所属：`lib/plugins/` · [返回索引](../CLAUDE.md)

## 路由

两套机制汇合于 `lib/screens/route.dart`：

1. **声明式路由** `lib/screens/routing/routes/*_routes.dart`（RouteRegistry 列表 + AppRoutes 静态路径常量），覆盖 activity/habits/notes/store/bill/todo/calendar_album/webview/tracker/calendar/contact/diary 等。
2. **通用主页路由** `plugin_common_routes.dart`：`/activity /checkin /tts /nodes /openai /scripts_center /timer /timer_details /contact /database /day /goods /common_widget_selector /live2d`。
3. **命令式深链** `PluginRouteHandler`（仅 5 个）：checkin（`/checkin_item_selector`、`/checkin_item`）、todo（`/todo_task_detail?taskId=`、`/todo_list_selector`、`/todo_list`）、goods（`/goods/warehouse_detail`、`/goods/item_detail`、`/goods/usage`）、habits（`/habit/timer?habitId=&action=start_timer|show_dialog`）、tracker（`/tracker`、`/tracker/progress`）——主要承接桌面小组件与 NFC 扫描跳转。
4. 其余插件统一经 `/plugin/<id>` 由 PluginManager 打开。

### 各插件主要路由

| 插件 | 路由 |
|------|------|
| activity | `/activity`、`/activity_edit`、`/activity_weekly_config`、`/activity_daily_config`、`/tag_statistics` |
| habits | `/habits`、`/habit_timer_selector`、`/habits_weekly_config`、`/habit_group_list_selector`、`/habit_timer_dialog` + handler 深链 |
| notes | `/notes`、`/notes/create` |
| store | `/store`、`/store/product_items`、`/store/user_item`、`/store/points_history` |
| bill | `/bill`、`/bill_shortcuts_selector` |
| todo | `/todo` + 3 条 handler 深链 |
| calendar_album | `/calendar_album`、`/calendar_album_weekly_selector` |
| webview | `/webview/browser` |
| tracker | `/tracker`、`/tracker_goal_selector`、`/tracker_goal_progress_selector` + handler 深链 |
| calendar | `/calendar`、`/calendar_month_selector`、`/calendar_month/event` |
| contact | `/contact`、`/contact/detail` |
| diary | `/diary`、`/diary_detail`、`/diary/editor` |
| timer | `/timer`、`/timer_details` |
| moments | `/moments`（宿主页三页签）、`/moments/profile?agentId=`（个人主页，handler 深链） |
| chat / agent_chat / openai / database / nodes / day / tts / scripts_center / checkin | 见上文通用路由与 `/plugin/<id>` |
| live2d | `/live2d`（设置页，注册于 plugin_common_routes） |
| nfc / reminder | 无路由 |

## JS API（JSBridgeManager 命名空间）

- 命名约定：`get{Entity}s` / `create{Entity}` / `update{Entity}` / `delete{Entity}` / `find{Entity}By(Id|Name|...)`。
- 规模示例：timer 13 个（含 startTimer/pauseTimer/stopTimer/resetTimer/getTimerStatus/getHistory）；todo 16 个（含 getTodayTasks/getOverdueTasks/completeTask）；database 15+（`_jsQuery/_jsGetCount/_jsFindRecordBy` 等结构化查询）。
- openai：`getAgents`、`getAgent`、`sendMessage`（流式收集，最多 10 次重试）、`getProviders`、`testProvider`。
- **chat**：part 文件 `chat_js_api.dart` 有完整实现（getChannels/createChannel/sendMessage/getMessagesByDate/...），但主类 `defineJSAPI()` 当前返回空 map——**未实际注册**，属迁移中间态。
- 无 JS API 的插件：agent_chat、scripts_center、reminder、nfc、live2d、moments（scripts_center 本身是脚本的执行方；moments 的 AI 工具挂在 openai 的 `moments_js_api.dart`）。
- 详细 API 文档：多个插件目录内有 `JS_API.md` / `JS_API_DOC.md`（notes、store、todo、timer、tracker）。

## 数据选择器（PluginDataSelectorService）

插件经 `*_data_selectors.dart` 注册，供悬浮球动作与 UI 选择面板：

| 选择器 | 用途 |
|--------|------|
| `chat.channel` / `chat.message` | 频道（单级）/ 消息（频道→消息两级） |
| `agent_chat.conversation` | 会话单选 |
| `openai.agent` + Prompt 预设 | 网格选助手 / 预设 |
| 其余插件（todo、tracker、habits 等） | 任务/目标/习惯等实体的选择面板 |

## 事件（EventManager）

- 核心：`plugin_loaded`、`plugins_initialized`。
- chat：`chat_message_sent`、`chat_message_updated`（openai 的 ChatEventHandler 订阅前者实现 @AI 回复；store/scripts_center 亦有订阅）。
- openai：`openai_agent_*`（Agent CRUD）。
- diary：`diary_entry_created/updated/deleted`；timer：`timer_task_changed`；tracker：携带数据的缓存更新事件。
