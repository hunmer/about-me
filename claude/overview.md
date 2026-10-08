# 架构总览

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## 仓库形态

Aboutme 是一个**单仓多模块（monorepo）**项目，由四类角色组成：

1. **Flutter 客户端**（`lib/`，约 1900 个 Dart 文件）：跨平台个人助手应用本体，插件化架构，26 个内置功能插件，默认首页为果冻小屋（`/jelly_home`）。
2. **本地/自建子包**（`packages/`，9 个子包）：1 个 Node.js/TypeScript 服务（server-nodejs 同步服务器）+ 8 个 Dart 包（agentlib AI 传输库、super_cupertino_navigation_bar 导航 UI 库、6 个原生插件：悬浮球、前台服务、通知、Intent、NFC、桌面小组件）。
3. **共享模型**（`shared_models/`）：客户端与服务端共用的 Dart 包（Repository 接口、UseCase、DTO、同步协议模型）。
4. **周边资源**：`docs/`（67 篇专题文档）、`online/`（WebView 小程序仓库）、`scripts/`（构建发布脚本）、`tool_templates/`（插件工具模板）、`handoff/`（会话交接底稿）、`.github/workflows/`（5 个平台构建 CI）。

## 运行时拓扑

```mermaid
graph LR
    App[Flutter 客户端<br/>Android/iOS/桌面/Web] -->|REST + WebSocket<br/>AES-256-GCM 端到端加密| Server[server-nodejs<br/>默认端口 8874]
    Server --> Admin[admin-vue 管理面板<br/>Vue3 + Naive UI]
    AI[AI 客户端 / MCP Host] -->|HTTP /mcp 端点| MCP["server-nodejs 内置 MCP"]
    MCP -->|进程内直调插件处理器| Server
```

> 历史：`packages/api_forwarding_server`（WebSocket 配对转发，端口 8654）与独立的 `packages/mcp-aboutme-server`（stdio MCP）已删除；MCP 能力并入 server-nodejs 内置端点。

## 关键设计取舍

- **本地优先**：数据以 JSON 文件形式存于本地（Web 端为 IndexedDB），服务器只是同步与中转通道，无数据库依赖（服务端同为纯文件存储）；远程备份统一走自建服务器的 HTTP 存储后端（`lib/core/storage/http_storage.dart`，WebDAV 通道已移除）。
- **插件化**：功能以 `PluginBase` 子类为单位（`lib/plugins/*`），在 `lib/core/builtin_plugins.dart` 静态注册；插件可向 JS Bridge 暴露 API、注册路由与数据选择器。
- **端到端加密同步**：客户端 `encrypt`（AES-256-GCM）与服务端 `encryptionService.ts` 对应。
- **双入口 AI 集成**：应用内 AI（`openai`/`agent_chat` 插件，HTTP/SSE 传输收敛到本地 `agentlib` 包）与外部 AI 工具（MCP 端点，75 工具，12 个插件域）并存。
- **JS 扩展生态**：内置 `flutter_js` 引擎 + `scripts_center` 插件 + `online/` 小程序仓库，形成应用内脚本/小程序生态。

## 版本与平台

- 应用版本：`0.0.1`（见 `pubspec.yaml`，`publish_to: none`）
- Dart SDK `^3.7.0`；Node.js `>= 18`（所有 Node 子包）
- 目标平台：Android、iOS、Web、Windows、macOS、Linux
- 国际化：中文（zh_CN）、英文（en_US）
