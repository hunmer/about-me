---
name: aboutme-http
description: HTTP API fallback for the aboutme MCP (@hunmer/aboutme-server tools like aboutme_data_call / aboutme_chat_sendMessage) when those MCP tools are unavailable or the user asks to operate aboutme data over HTTP. Use whenever the agent needs to read/write aboutme personal data — notes, chat, todo, diary, bills, calendar, checkin, contacts, goods, habits, tracker, store points, assets, agent_chat conversations, etc. — against a running aboutme server, especially when mcp__*__aboutme tools are missing or fail. Covers auth (X-API-Key / Bearer JWT), capability discovery, endpoint patterns, and per-plugin endpoint reference.
---

# aboutme-http（aboutme MCP 的 HTTP 等价方案）

aboutme server 自带 MCP 端点，暴露 `aboutme_data_call`、`aboutme_data_capabilities`
和一批 `aboutme_<plugin>_<action>` 语义工具（如 `aboutme_chat_sendMessage`）。
**这些工具全部是 server 自身 REST API（`/api/v1/plugins/...`）的薄封装**，
所以直接发 HTTP 请求即可达到与 MCP 完全相同的效果，不依赖 MCP 连接。

## 何时使用本 skill

- `aboutme` MCP 工具（`mcp__*__aboutme_*`）不在工具列表中，或调用时报连接/超时错误；
- 用户要求读写 aboutme 数据（笔记 / 聊天 / 待办 / 日记 / 账单 / 日历 / 打卡 / 联系人 / 物品 / 习惯 / 追踪 / 积分商店 / 资源 / AI 会话…）；
- 用户明确说"用 HTTP"或"MCP 不可用"。

MCP 工具可用时优先用 MCP，本 skill 是备份路径。

## 1. 连接与认证

服务器默认 `http://127.0.0.1:8874`（环境变量 `PORT` 可改）。
先探活（免认证）：

```bash
curl -s http://127.0.0.1:8874/health
curl -s http://127.0.0.1:8874/version
```

凭据二选一，放入请求头：

| 凭据形态 | 请求头 |
|---|---|
| API Key（不含 `.` 或含 1 个 `.`） | `X-API-Key: <key>` |
| JWT（用 `.` 分隔恰好 3 段） | `Authorization: Bearer <jwt>` |

判别规则来自官方调试页：`key.split('.').length === 3` 即 JWT。

没有凭据时的自举路径（auth 路由挂在 `/api/v1/auth/`，一律用 JWT Bearer 认证，
**API Key 对 auth 管理接口无效**，如删 key 时用 `X-API-Key` 会返回 401）：

```bash
# 登录拿 JWT（默认管理员 admin/admin123，仅开发环境）
# 注意：body 必须带 device_id（snake_case），缺它报"设备 ID 不能为空"
curl -s -X POST http://127.0.0.1:8874/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123","device_id":"zcode-agent"}'
# 成功响应：{"success":true,"user_id":"...","token":"<jwt>","expires_at":"..."}

# 创建长期 API Key（推荐日常用，比 JWT 稳定）
curl -s -X POST http://127.0.0.1:8874/api/v1/auth/api-keys \
  -H "Authorization: Bearer <jwt>" -H 'Content-Type: application/json' \
  -d '{"name":"zcode-agent"}'
# 成功响应：api_key.key 形如 mk_...（无点号，自动走 X-API-Key 路径）

# 已有 key 时可列出并 reveal（响应含完整 key 值）
curl -s http://127.0.0.1:8874/api/v1/auth/api-keys -H "X-API-Key: <key>"
curl -s http://127.0.0.1:8874/api/v1/auth/api-keys/<keyId>/reveal -H "X-API-Key: <key>"
```

API Key 访问可能被用户级开关限制。请求插件 API 返回 403 时，用 Bearer 打开开关：

```bash
curl -s -X PUT http://127.0.0.1:8874/api/v1/auth/api-access \
  -H "Authorization: Bearer <jwt>" -H 'Content-Type: application/json' \
  -d '{"enabled":true}'
```

## 2. 接口发现：capabilities 是唯一真源

**不要硬编码接口路径。** 先拉能力清单，再按清单里的 `method + path` 发请求：

```bash
curl -s http://127.0.0.1:8874/api/v1/plugins/capabilities -H "X-API-Key: <key>"
```

响应结构（实测，`actionId` 格式为 `plugin.action`，无 group 字段——
分组从 `path` 第 5 段即插件名推断）：

```json
{
  "protocolVersion": 1,
  "actions": [
    {
      "actionId": "notes.create",
      "method": "POST",
      "path": "/api/v1/plugins/notes/notes",
      "resource": "notes",
      "permission": "user:data:write",
      "capabilityVersion": 1,
      "requestModel": "json-object",
      "responseModel": "plugin-result-v1"
    }
  ]
}
```

MCP 工具与 HTTP 的映射关系：

| MCP 调用 | HTTP 等价 |
|---|---|
| `aboutme_data_capabilities` | `GET /api/v1/plugins/capabilities` |
| `aboutme_data_call {pluginId, action, params}` | 按 capabilities 中该 action 的 `method` + `path` 直接请求；params 中路径/query 参数拼 URL，其余进 body |
| `aboutme_<plugin>_<action>(...)` | 同上（如 `aboutme_chat_sendMessage` → `POST /api/v1/plugins/chat/channels/:channelId/messages`，4 个参数进 JSON body） |

## 3. 请求构造规则

- **路径参数**：清单中形如 `:id` / `:channelId`，替换为实际值并 URL 编码。
- **Query 参数**：GET 常用 `offset` / `count` / `fuzzy`，搜索类用 `keyword`（或 `field` + `value` + `fuzzy`）。
- **请求体**：非 GET 方法发送 JSON **对象**（不允许数组或裸标量）；留空则不发 body。
- **Content-Type**: 有 body 时必须 `application/json`。
- **响应**：JSON，外层 `{"success":bool, "data":..., "timestamp":..., "version":<数据版本号>}`。
  创建/更新返回的资源对象就在 `data`（新 ID 取 `data.id`）；
  **列表是双层嵌套**：数组在 `data.data`，分页信息 `data.total` / `data.offset` / `data.hasMore`。

完整示例（笔记生命周期，Git Bash / curl）：

```bash
BASE=http://127.0.0.1:8874/api/v1/plugins
H='-H X-API-Key:xxx -H Content-Type:application/json'

# 列出笔记
curl -s "$BASE/notes/notes?offset=0&count=10" -H "X-API-Key: $KEY"

# 创建笔记，从 data.id 拿到 noteId
curl -s -X POST "$BASE/notes/notes" $H \
  -d '{"title":"测试","content":"hello","tags":["agent"]}'

# 更新 / 删除
curl -s -X PUT "$BASE/notes/notes/<noteId>" $H -d '{"title":"改名"}'
curl -s -X DELETE "$BASE/notes/notes/<noteId>" -H "X-API-Key: $KEY"
```

## 4. 插件分组一览

`assets` 资源 · `chat` 聊天 · `notes` 笔记 · `nodes` 笔记本节点 · `activity` 活动 ·
`goods` 物品 · `bill` 账单 · `todo` 待办 · `diary` 日记 · `checkin` 打卡 ·
`calendar` 日历 · `calendar_album` 日历相册 · `contact` 联系人 · `tracker` 追踪 ·
`day` 纪念日 · `habits` 习惯 · `agent_chat` AI 会话 · `store` 积分商店 ·
`media_log` 媒体记录 · `database` 自定义数据库 · `timer` 计时器 ·
`achievement` 成就 · `reminder` 提醒 · `live2d` · `tts` 语音 · `toolbox` 工具箱 ·
`photo_editor` 图片编辑 · `webview` 网页组件 · `openai` AI 助手 ·
`scripts_center` 脚本中心 · `system` 系统

各插件的端点、方法与请求体字段速查见 [references/endpoints.md](references/endpoints.md)
（提取自官方调试页 `packages/aboutme_server/debug/index.html` 的测试场景）。
**速查表仅供参考，具体路径以 capabilities 实时返回为准**——两者冲突时信 capabilities。

## 5. 典型模式

大多数插件遵循同一 CRUD 模式，配合 capabilities 可零文档上手：

- 列表：`GET /<plugin>/<resource>?offset&count`；详情：`GET .../:id`
- 创建：`POST /<plugin>/<resource>` + JSON body（`data.id` 返回新 ID）
- 全量更新：`PUT .../:id`；部分更新：`PATCH .../:id`（部分插件）
- 动作类端点：`POST .../:id/<verb>`（如 `complete` / `checkin` / `use` / `purchase`）
- 搜索：`GET /<plugin>/search?keyword=...`
- 快照类插件（timer/achievement/reminder/live2d/tts）：`GET /<plugin>/snapshot`
  读后**原样** `PUT /<plugin>/snapshot {"snapshot": <读到的 data>}` 写回，不要改结构
- 二级资源挂在父资源路径下（如 `bill/accounts/:accountId/bills`、
  `nodes/notebooks/:notebookId/nodes`），删除时可能要求 body 里带父 ID
