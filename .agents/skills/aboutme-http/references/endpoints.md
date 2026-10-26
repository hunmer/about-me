# aboutme 插件端点速查

来源：`packages/aboutme_server/debug/index.html` 官方调试页测试场景。
所有路径省略前缀 `/api/v1/plugins/`；`:{name}` 为路径参数。
**冲突时以 `GET /api/v1/plugins/capabilities` 实时清单为准。**

## chat 聊天

| 方法 | 路径 | 请求体 / Query |
|---|---|---|
| POST | `chat/channels` | `{name, description}` |
| GET | `chat/channels` | `?offset&count` |
| PUT | `chat/channels/:id` | `{name, description}` |
| DELETE | `chat/channels/:id` | |
| GET | `chat/channels/:channelId/messages` | `?offset&count` |
| POST | `chat/channels/:channelId/messages` | `{content, senderId, senderName}` |
| DELETE | `chat/channels/:channelId/messages/:messageId` | |
| GET | 消息搜索（见 capabilities） | `?field=content&value=..&fuzzy=true&channelId` |

## notes 笔记

| 方法 | 路径 | 请求体 / Query |
|---|---|---|
| POST | `notes/folders` | `{name}` |
| DELETE | `notes/folders/:id` | |
| GET | `notes/notes` | `?folderId&offset&count` |
| POST | `notes/notes` | `{title, content, folderId?, tags?}` |
| PUT | `notes/notes/:id` | `{title?, content?, tags?}` |
| DELETE | `notes/notes/:id` | |
| GET | `notes/search` | `?keyword` |

## todo 待办

| 方法 | 路径 | 请求体 |
|---|---|---|
| POST | `todo/tasks` | `{title, priority}` |
| GET/PUT/DELETE | `todo/tasks/:id` | PUT：`{title?, priority?}` |
| POST | `todo/tasks/:id/complete` | |
| GET | `todo/tasks` | `?offset&count` |

## diary 日记（以 date 为主键）

| 方法 | 路径 | 请求体 / Query |
|---|---|---|
| POST | `diary/entries` | `{date: "YYYY-MM-DD", content, mood, weather, tags}` |
| PUT | `diary/entries/:date` | `{content?, mood?, weather?, tags?}` |
| GET | `diary/search` | `?keyword` |
| DELETE | `diary/entries/:date` | |

## activity 活动

| 方法 | 路径 | 请求体 |
|---|---|---|
| POST | `activity/activities` | `{title, startTime, endTime, tags?, description?, mood?}`（ISO 8601） |
| GET/PUT/DELETE | `activity/activities/:id` | PUT：`{title?, mood?…}` |
| GET | `activity/activities` | `?date=YYYY-MM-DD`（默认今天） |
| GET | `activity/stats/today` | |

## bill 账单

| 方法 | 路径 | 请求体 |
|---|---|---|
| POST | `bill/accounts` | `{name, balance}` |
| GET | `bill/accounts` | `?offset&count` |
| DELETE | `bill/accounts/:id` | |
| POST | `bill/accounts/:accountId/bills` | `{type: "expense"|"income", amount, category, description}` |
| PUT | `bill/bills/:id` | `{amount?, …}` |
| GET | `bill/stats` | |

## calendar 日历

| 方法 | 路径 | 请求体 / Query |
|---|---|---|
| POST | `calendar/events` | `{title, startTime, endTime}`（ISO 8601） |
| PUT/DELETE | `calendar/events/:id` | |
| POST | `calendar/events/:id/complete` | |
| GET | `calendar/events/search` | `?keyword` |

## calendar_album 日历相册（date + id 双键）

| 方法 | 路径 | 请求体 |
|---|---|---|
| POST | `calendar_album/entries` | `{date, title, content}` |
| PUT/DELETE | `calendar_album/entries/:date/:id` | PUT：`{title?, content?}` |
| GET | `calendar_album/tags` | |

## checkin 打卡

| 方法 | 路径 | 请求体 |
|---|---|---|
| POST | `checkin/items` | `{name, group?}` |
| PUT/DELETE | `checkin/items/:id` | |
| POST | `checkin/items/:id/checkin` | `{date, note?}` |
| GET | `checkin/stats` | |

## contact 联系人

| 方法 | 路径 | 请求体 |
|---|---|---|
| POST | `contact/contacts` | `{name, phone?}` |
| PUT/DELETE | `contact/contacts/:id` | PUT：`{tags?…}` |
| POST | `contact/interactions` | `{contactId, notes, date}` |
| DELETE | `contact/interactions/:id` | |

## day 纪念日

| 方法 | 路径 | 请求体 / Query |
|---|---|---|
| POST | `day/days` | `{title, date: "2027-01-01", type: "countdown"}` |
| PUT/DELETE | `day/days/:id` | |
| GET | `day/search` | `?keyword` |

## goods 物品库存

| 方法 | 路径 | 请求体 / Query |
|---|---|---|
| POST | `goods/warehouses` | `{name}` |
| DELETE | `goods/warehouses/:id` | |
| GET | `goods/items` | `?warehouseId&offset&count` |
| POST | `goods/items` | `{name, warehouseId, quantity, category?}` |
| PUT/DELETE | `goods/items/:id` | PUT：`{quantity?…}` |
| GET | `goods/search` | `?keyword` |

## habits 习惯

| 方法 | 路径 | 请求体 |
|---|---|---|
| POST | `habits/habits` | `{title}` |
| PUT/DELETE | `habits/habits/:id` | |
| POST | `habits/records` | `{parentId: <habitId>, date}` |
| DELETE | `habits/records/:id` | |

## media_log 媒体记录

| 方法 | 路径 | 请求体 |
|---|---|---|
| POST | `media_log/items` | `{title, type: "movie"|…, status: "completed"|"watching"|…}` |
| PUT/DELETE | `media_log/items/:id` | PUT：`{status?…}` |
| POST | `media_log/items/:itemId/reviews` | `{rating, text}` |
| DELETE | `media_log/items/:itemId/reviews/:reviewId` | |

## nodes 笔记本节点

| 方法 | 路径 | 请求体 |
|---|---|---|
| POST | `nodes/notebooks` | `{title}` |
| DELETE | `nodes/notebooks/:id` | |
| POST | `nodes/notebooks/:notebookId/nodes` | `{title, content}` |
| PATCH/DELETE | `nodes/notebooks/:notebookId/nodes/:id` | PATCH：`{title?…}`（注意是 PATCH） |

## store 积分商店

| 方法 | 路径 | 请求体 | 响应提取 |
|---|---|---|---|
| POST | `store/products` | `{name, price, stock, use_duration}` | `data.id` |
| POST | `store/points` | `{value, reason}` | |
| POST | `store/purchase` | `{productId}` | `data.userItem.id` |
| POST | `store/user-items/:id/use` | | |
| DELETE | `store/products/:id` | | |

## tracker 追踪目标

| 方法 | 路径 | 请求体 |
|---|---|---|
| POST | `tracker/goals` | `{name, targetValue, unit}` |
| PUT/DELETE | `tracker/goals/:id` | |
| POST | `tracker/records` | `{goalId, value, date}` |
| GET/DELETE | `tracker/goals/:goalId/records` | DELETE 为清空该目标全部记录 |

## database 自定义数据库

| 方法 | 路径 | 请求体 |
|---|---|---|
| POST | `database/databases` | `{name}` |
| DELETE | `database/databases/:id` | |
| POST | `database/records` | `{databaseId, data: {...}}` |
| PUT | `database/records/:id` | `{databaseId, data: {...}}` |
| DELETE | `database/records/:id` | body 也要带 `{databaseId}` |

## agent_chat AI 会话

| 方法 | 路径 | 请求体 |
|---|---|---|
| POST | `agent_chat/conversations` | `{title}` |
| PATCH/DELETE | `agent_chat/conversations/:id` |（注意是 PATCH） |
| POST | `agent_chat/conversations/:conversationId/messages` | `{role: "user", content}` |

## webview 网页组件（KV 存储）

| 方法 | 路径 | 请求体 |
|---|---|---|
| GET | `webview/tabs` | |
| PUT | `webview/storage/:key` | 任意 JSON 对象 |
| GET | `webview/storage/:key` | |
| DELETE | `webview/storage/:key` | |

## scripts_center 脚本中心

| 方法 | 路径 | 请求体 |
|---|---|---|
| POST | `scripts_center/scripts` | `{id, metadata: {title}, code}`（id 自拟） |
| PUT | `scripts_center/scripts/:id/meta` | `{metadata: {title}}` |
| DELETE | `scripts_center/scripts/:id` | |

## assets 资源（base64 上传）

| 方法 | 路径 | 请求体 |
|---|---|---|
| POST | `assets/` | `{fileName, mediaType, content}`（content 为 base64） |
| GET | `assets/:id/metadata` | |
| DELETE | `assets/:id` | |

## 快照类（读 → 原样写回，勿改结构）

timer / achievement / reminder / live2d / tts 均为：

- `GET <plugin>/snapshot` → 记下 `data`
- `PUT <plugin>/snapshot` body `{"snapshot": <刚才读到的 data 原样>}`

## 只读配置

- `GET photo_editor/history`（图片编辑历史）
- `GET toolbox/ai-image/history`、`GET toolbox/image-search/history`
- `GET openai/agents`、`GET openai/presets`、`GET openai/providers`
- `GET system/registry`（插件注册表）、`GET system/store-config`（商店配置）

## 系统内置（免认证）

- `GET /health`、`GET /version`
- `GET /api/v1/plugins/capabilities`（需要认证）
