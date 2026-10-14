# 对外接口

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## 应用内路由（Flutter）

- 汇总入口：`lib/screens/route.dart`（`AppRoutes.initialRoute / routes / generateRoute`）；**初始路由为 `/jelly_home`（果冻小屋）**。
- 各插件路由注册表：`lib/screens/routing/routes/*_routes.dart`（core / test / widget_gallery / chat / diary / agent_chat / bill / calendar / notes / store / habits / tracker / activity / calendar_album / contact / todo / webview / plugin_common）。
- 部分插件自带 RouteHandler（checkin / todo / goods / habits / tracker / media_log），由 `core/routing/plugin_route_handler.dart` 分发。

## JS Bridge API（应用内 JavaScript 可调用）

- 各插件在 `defineJSAPI()` 中注册方法（命名约定见 [conventions.md](conventions.md)），经 `lib/core/js_bridge/` 暴露给内置 JS 引擎。
- 消费方：`scripts_center` 插件（用户脚本）、`online/` 小程序（WebView 预注入，见 `online/apps/README.md`）。
- AI 伙伴工具面（2026-10 新增，注册在 openai 插件、由 agent_chat 工具配置描述给 LLM）：`search_memory`（记忆检索）、`generate_image` / `post_moment` / `list_agent_assets`（朋友圈与生图），详见 [openai 对外接口](../lib/plugins/openai/claude/public-interfaces.md)。
- 内置脚本：`assets/scripts/ai_image/`（AI 图片生成，QuickJS 运行，OpenAI 兼容异步图像 API；scripts_center 启动时同步到本地并按版本覆盖升级）。

## 同步服务器 REST / WebSocket（`packages/aboutme_server`，Dart，默认端口 8874）

- 认证：`auth_routes.dart` + `auth_middleware.dart`——注册/登录、Token、API Key（`mk_live_` 前缀）、FCM 绑定。
- 文件存储：`storage_routes.dart`——push / pull / list / delete，**明文** + ETag 条件写（端到端加密已随数据 SDK 化移除）。
- 插件数据：`plugin_routes.dart`——**19 个插件域** REST API，处理器全部来自 `packages/aboutme_data_sdk`。
- 管理员：`system_routes.dart`。
- 实时通道：`ws_hub.dart`——文件变更以 `file_updated` 广播给同用户其他设备。
- 旧 server-nodejs 的 `storageWebSocketService` / `pluginSystemRoutes`（服务端插件系统）已随包彻底删除（2026-10-14）。

## MCP 工具（aboutme_server 内置端点 `POST /mcp`，Streamable HTTP）

- 端点实现 `packages/aboutme_server/lib/src/mcp/mcp_endpoint.dart`，工具定义 `tools.dart`，共 **68 个工具**。
- 与 REST 插件 API **共用同一套 aboutme_data_sdk 处理器**（进程内直调，无重复实现）。
- 认证走 API Key（`mk_live_` 前缀）；旧 server-nodejs 的 75 工具版已随包彻底删除。

## Web 小程序清单（`online/`）

- `online/apps/apps.json`：小应用列表（password_manager、pure_read、timeline、emoji-time-capsule）；`online/scripts/scripts.json`：在线脚本；`online/agents.json`：AI Agent 配置示例。
