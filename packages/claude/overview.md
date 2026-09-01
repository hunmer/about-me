# 子包总览

> 所属：packages/ · [返回索引](../CLAUDE.md)

## 两类子包

**Node.js/TypeScript 服务（3 个，独立部署）**

| 子包 | npm 包名 | 端口/传输 | 角色 |
|------|----------|-----------|------|
| `server-nodejs/` | `@hunmer/memento-server` | HTTP/WS，默认 8874 | 数据同步中枢：认证、加密文件同步、插件数据 API、服务端插件系统、管理面板 |
| `mcp-memento-server/` | `@hunmer/mcp-memento-server` | stdio（MCP） | AI 工具网关：把 server 的插件 API 包装成 MCP 工具 |
| `api_forwarding_server/` | `memento-api-forwarding-server` | WebSocket 8654 | 前端↔客户端配对转发：让 Web 前端借 Flutter 客户端的 JSBridge 调插件 |

三者关系：MCP 与 api_forwarding 都是 server-nodejs / 客户端的"侧翼"接入层，server-nodejs 是唯一的数据源。

**Flutter 原生插件（6 个，path 依赖进客户端）**

悬浮球（floating_ball_plugin）、前台服务（memento_foreground_service）、通知（memento_notifications）、Android Intent/快捷方式（memento_intent）、NFC（memento_nfc）、桌面小组件（memento_widgets）。客户端对应消费点集中在 `lib/core/`（services、app_widgets、floating_ball 等）。

## 规模与复杂度

- 最大：`server-nodejs`（约 618 文件，含 admin-vue 前端）与 `memento_widgets`（265 文件，双平台原生代码）。
- 最小：`api_forwarding_server`（9 文件，src 仅 index/server/session/types 四个 TS 文件）。
- 原生插件中 `memento_intent`（121）与 `memento_nfc`（113）包含较多平台示例与配置。

## 设计取舍

- 服务端坚持**纯文件存储**（无数据库），部署门槛低，数据可整目录备份/导出 ZIP。
- 原生能力一律抽成独立插件包而非堆在宿主工程，便于复用与隔离平台代码。
- `memento_foreground_service`、`memento_notifications` 是对三方包（flutter_foreground_task、awesome_notifications）的**二次封装**，对上层提供精简 API。
