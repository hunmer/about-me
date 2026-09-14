# 对外接口

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## 应用内路由（Flutter）

- 汇总入口：`lib/screens/route.dart`（`AppRoutes.initialRoute / routes / generateRoute`）。
- 各插件路由注册表：`lib/screens/routing/routes/*_routes.dart`（core / test / widget_gallery / chat / diary / agent_chat / bill / calendar / notes / store / habits / tracker / activity / calendar_album / contact / todo / webview / plugin_common）。
- 部分插件自带 RouteHandler（checkin / todo / goods / habits / tracker），由 `core/routing/plugin_route_handler.dart` 分发。

## JS Bridge API（应用内 JavaScript 可调用）

- 各插件在 `defineJSAPI()` 中注册方法（命名约定见 [conventions.md](conventions.md)），经 `lib/core/js_bridge/` 暴露给内置 JS 引擎。
- 消费方：`scripts_center` 插件（用户脚本）、`online/` 小程序（WebView 预注入，见 `online/apps/README.md`）。

## 同步服务器 REST / WebSocket（`packages/server-nodejs`）

- 认证：`routes/authRoutes.ts`——注册/登录，签发 JWT；管理面板另支持 API Key（`mk_live_` 前缀）。
- 文件同步：`routes/syncRoutes.ts`——push / pull / list / delete，端到端 AES-256-GCM 加密。
- 插件数据：`routes/pluginRoutes/`——路由工厂配置 **19 个插件域**（12 个专用 handler + 7 个默认 CRUD），REST 前缀 `/api/v1`。
- 服务端插件系统：`routes/pluginSystemRoutes.ts`——插件安装（ZIP 上传/商店）、启用/禁用/卸载、before/after 钩子（hookable）。
- 实时通道：`WebSocketManager`（express-ws），配合 `FileWatcherService` 实现文件变更实时同步。

## MCP 工具（server-nodejs 内置端点 `POST /mcp`，Streamable HTTP）

- 工具命名：`aboutme_{plugin}_{action}`，定义于 `src/tools/index.ts`。
- 覆盖 12 个插件域、60+ 工具：chat（频道/消息增删改查、搜索）、notes、activity（含今日统计）、goods、bill（含统计）、todo（含完成/今日/过期）、diary、checkin、calendar、contact、tracker、day。
- 通过 `src/client/aboutme-client.ts` 调用 server-nodejs 的 REST API（API Key + 加密）。

## API 转发协议（`packages/api_forwarding_server`）

- WebSocket 端口 8654；Web 前端与 Flutter 客户端用**相同的配对密钥**（形如 `ABCD-1234-EFGH-5678`）连接即完成配对。
- 消息双向转发：前端请求 → 服务器 → 客户端（JSBridge API）→ 服务器 → 前端响应；含心跳检测。协议详情见该包 `README.md` 的"消息协议"章节。

## Web 小程序清单（`online/`）

- `online/apps/apps.json`：小应用列表（password_manager、pure_read、timeline、emoji-time-capsule）；`online/scripts/scripts.json`：在线脚本；`online/agents.json`：AI Agent 配置示例。
