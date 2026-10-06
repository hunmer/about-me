# 子包总览

> 所属：packages/ · [返回索引](../CLAUDE.md)

## 三类子包

**Node.js/TypeScript 服务（1 个，独立部署）**

| 子包 | npm 包名 | 端口/传输 | 角色 |
|------|----------|-----------|------|
| `server-nodejs/` | `@hunmer/aboutme-server` | HTTP/WS，默认 8874 | 数据同步中枢：认证、加密文件同步、插件数据 API、服务端插件系统、管理面板、**内置 MCP 端点（/mcp，Streamable HTTP，12 域 75 工具）** |

> 历史：`mcp-aboutme-server/`（stdio MCP）与 `api_forwarding_server/`（WebSocket 8654 配对转发）曾是独立子包，现已删除；MCP 能力并入 server-nodejs。

**本地 Dart 库（3 个，path 依赖进客户端）**

- `agentlib/`：OpenAI 兼容 HTTP/SSE 传输门面（`AgentLibClient` 等 4 个导出文件），替代曾直接依赖的 `openai_dart`。
- `dartantic_ai/`：上游 3.4.2 的本地镜像；为 Anthropic provider 增加自定义 `baseUrl`，细节见 [定制与同步说明](../dartantic_ai/CUSTOMIZATION.md)。
- `super_cupertino_navigation_bar/`：iOS 风格大标题导航栏 UI 库。

**Flutter 原生插件（6 个，path 依赖进客户端）**

悬浮球（floating_ball_plugin）、前台服务（aboutme_foreground_service）、通知（aboutme_notifications）、Android Intent/快捷方式（aboutme_intent）、NFC（aboutme_nfc）、桌面小组件（aboutme_widgets）。客户端对应消费点集中在 `lib/core/`（services、app_widgets、floating_ball 等）。

## 规模与复杂度

- 最大：`server-nodejs`（约 780 文件，含 admin-vue 前端）与 `aboutme_widgets`（265 文件，双平台原生代码）。
- 最小：`agentlib`（15 文件）与 `super_cupertino_navigation_bar`（32 文件）。
- 原生插件中 `aboutme_intent`（121）与 `aboutme_nfc`（113）包含较多平台示例与配置。

## 设计取舍

- 服务端坚持**纯文件存储**（无数据库），部署门槛低，数据可整目录备份/导出 ZIP。
- 原生能力一律抽成独立插件包而非堆在宿主工程，便于复用与隔离平台代码。
- `aboutme_foreground_service`、`aboutme_notifications` 是对三方包（flutter_foreground_task、awesome_notifications）的**二次封装**，对上层提供精简 API。
- AI 传输收敛为本地 `agentlib`（仅依赖 http），不再依赖外部 `openai_dart`。
