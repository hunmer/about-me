# 对外接口

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## 应用内路由（Flutter）

- 汇总入口：`lib/screens/route.dart`（`AppRoutes.initialRoute / routes / generateRoute`）；**初始路由为 `/jelly_home`（果冻小屋）**。
- 各插件路由注册表：`lib/screens/routing/routes/*_routes.dart`（core / test / widget_gallery / chat / diary / agent_chat / bill / calendar / notes / store / habits / tracker / activity / calendar_album / contact / todo / webview / plugin_common）。
- 部分插件自带 RouteHandler（checkin / todo / goods / habits / tracker），由 `core/routing/plugin_route_handler.dart` 分发。

## JS Bridge API（应用内 JavaScript 可调用）

- 各插件在 `defineJSAPI()` 中注册方法（命名约定见 [conventions.md](conventions.md)），经 `lib/core/js_bridge/` 暴露给内置 JS 引擎。
- 消费方：`scripts_center` 插件（用户脚本）、`online/` 小程序（WebView 预注入，见 `online/apps/README.md`）。
- AI 伙伴工具面（2026-10 新增，注册在 openai 插件、由 agent_chat 工具配置描述给 LLM）：`search_memory`（记忆检索）、`generate_image` / `post_moment` / `list_agent_assets`（朋友圈与生图），详见 [openai 对外接口](../lib/plugins/openai/claude/public-interfaces.md)。
- 内置脚本：`assets/scripts/ai_image/`（AI 图片生成，QuickJS 运行，OpenAI 兼容异步图像 API；scripts_center 启动时同步到本地并按版本覆盖升级）。

## 同步服务器 REST / WebSocket（`packages/server-nodejs`）

- 认证：`routes/authRoutes.ts`——注册/登录，签发 JWT；管理面板另支持 API Key（`mk_live_` 前缀）。
- 文件同步：`routes/storageRoutes.ts`——push / pull / list / delete，端到端 AES-256-GCM 加密。
- 插件数据：`routes/pluginRoutes/`——路由工厂配置 **19 个插件域**（12 个专用 handler + 7 个默认 CRUD），REST 前缀 `/api/v1`。
- 服务端插件系统：`routes/pluginSystemRoutes.ts`——插件安装（ZIP 上传/商店）、启用/禁用/卸载、before/after 钩子（hookable）。
- 实时通道：`storageWebSocketService`（`/api/v1/storage/ws`，2026-09-15 新增）——连接 10 秒内客户端须发 `{type:'auth', token, device_id}` 完成认证；文件变更以 `file_updated`（file_path/modified_at/source_device_id）广播，只发**同 user 不同 device**；启动后 100ms 自预热消除冷启动。

## MCP 工具（server-nodejs 内置端点 `POST /mcp`，Streamable HTTP）

- 工具命名：`aboutme_{plugin}_{action}`，定义于 `src/mcp/tools.ts`。
- 覆盖 12 个插件域、75 个工具：chat（频道/消息增删改查、搜索）、notes、activity（含今日统计）、goods、bill（含统计）、todo（含完成/今日/过期）、diary、checkin、calendar、contact、tracker、day。
- 通过 `src/mcp/client.ts`（`AboutmeClient`）在进程内直调 server-nodejs 插件处理器（请求头 `X-API-Key` / `X-Encryption-Key` 认证）。

## Web 小程序清单（`online/`）

- `online/apps/apps.json`：小应用列表（password_manager、pure_read、timeline、emoji-time-capsule）；`online/scripts/scripts.json`：在线脚本；`online/agents.json`：AI Agent 配置示例。
