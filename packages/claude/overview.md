# 子包总览

> 所属：packages/ · [返回索引](../CLAUDE.md)

## 四类子包

**同步服务器链路（现行，Dart）**

| 子包 | 端口/传输 | 角色 |
|------|-----------|------|
| `aboutme_data_sdk/` | 纯 Dart 库 | **数据核心**：存储接口/HTTP 远端存储（明文+ETag 条件写）/认证（JWT+PBKDF2）/12 个插件处理器/AboutmeDataService 本地-远程路由；客户端、服务器 REST、MCP 三方共用 |
| `aboutme_server/` | HTTP/WS，默认 8874 | **同步服务器（薄壳）**：认证、文件存储、19 插件 REST、WS `file_updated` 广播、FCM、**内置 MCP 端点（/mcp，68 工具）**、托管 `/admin` 管理面板（Vue3，见 `admin-vue/`） |

> 已删除：`server-nodejs/`（Node.js + TypeScript，2026-10-11 整体平移至 aboutme_server，**2026-10-14 目录彻底删除**）；更早的 `mcp-aboutme-server/`、`api_forwarding_server/` 亦已删除。

**本地 Dart 库（4 个，path 依赖进客户端）**

- `agentlib/`：OpenAI 兼容 HTTP/SSE 传输门面（`AgentLibClient` 等 4 个导出文件），替代曾直接依赖的 `openai_dart`。
- `dartantic_ai/`：上游 3.4.2 的本地 vendor 镜像（[文档](../dartantic_ai/CLAUDE.md)）；为 Anthropic provider 增加自定义 `baseUrl`，细节见 [定制与同步说明](../dartantic_ai/CUSTOMIZATION.md)。
- `super_cupertino_navigation_bar/`：iOS 风格大标题导航栏 UI 库。
- `radial_disc_bottom_bar/`：弧形圆盘浮动底部导航栏（含 golden 测试）。

**vendor UI 库（1 个）**：`material_emoji_picker/`（表情选择器，数据源 emoji.json）。

**Flutter 原生插件（6 个，path 依赖进客户端）**

悬浮球（floating_ball_plugin）、前台服务（aboutme_foreground_service）、通知（aboutme_notifications）、Android Intent/快捷方式（aboutme_intent）、NFC（aboutme_nfc）、桌面小组件（aboutme_widgets）。客户端对应消费点集中在 `lib/core/`（services、app_widgets、floating_ball 等）。

## 规模与复杂度

- 现行链路：`aboutme_data_sdk`（45 源文件）+ `aboutme_server`（23 源文件 + admin-vue 前端）；最大子包为 `aboutme_widgets`（265 文件，双平台原生代码）。
- 最小：`agentlib`（15 文件）与 `super_cupertino_navigation_bar`（32 文件）。
- 原生插件中 `aboutme_intent`（121）与 `aboutme_nfc`（113）包含较多平台示例与配置。

## 设计取舍

- **数据 SDK 化（2026-10-11）**：业务处理器只写一份（data_sdk），客户端/REST/MCP 共用；服务器退化为路由/认证/广播薄壳（迁移底稿见 `handoff/2026-10-11_data-sdk-server-unification.md`）。
- 服务端坚持**纯文件存储**（无数据库），部署门槛低，数据可整目录备份/导出 ZIP；同步为**明文**（端到端加密已随迁移移除）。
- 原生能力一律抽成独立插件包而非堆在宿主工程，便于复用与隔离平台代码。
- `aboutme_foreground_service`、`aboutme_notifications` 是对三方包（flutter_foreground_task、awesome_notifications）的**二次封装**，对上层提供精简 API。
- AI 传输收敛为本地 `agentlib`（仅依赖 http）+ 本地 `dartantic_ai`（原生工具调用），不再依赖外部 `openai_dart`。
