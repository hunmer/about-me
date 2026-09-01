# packages/ 子包集合

`packages/` 汇集 Aboutme 的 9 个子包，分两类：**3 个 Node.js/TypeScript 服务**（同步服务器、MCP 服务器、API 转发服务器）与 **6 个 Flutter 原生插件**（悬浮球、前台服务、通知、Intent、NFC、桌面小组件）。原生插件经根 `pubspec.yaml` 的 path 依赖被客户端直接引用；Node 服务独立部署。

## 约定的规则

- 修改原生插件 Dart API 后需在客户端同步更新调用处（path 依赖，无版本缓冲）。
- Node 子包各自独立 `npm install` / `npm run build`；server-nodejs 的 `npm run build` 内含 admin-vue 面板构建。
- 原生插件的平台代码（android/ ios/）改动需同时在客户端宿主工程验证。
- 部署端口约定：server-nodejs **8874**，api_forwarding_server **8654**。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [子包总览](claude/overview.md) | 9 个子包的定位与关系 | 了解 packages 全貌 |
| [模块职责](claude/module-responsibilities.md) | 各子包职责明细（含 6 个原生插件） | 选择要改的子包 |
| [依赖与配置](claude/dependencies-and-config.md) | path 依赖接线、各包清单要点 | 动依赖 / 加新包 |

## 模块索引

| 模块 | 类型 | 职责摘要 | 文档 |
|------|------|----------|------|
| `server-nodejs/` | Node 服务 | 同步服务器：REST/WS、认证、E2E 加密、19 插件 API、服务端插件系统、Vue3 管理面板 | [server-nodejs/CLAUDE.md](server-nodejs/CLAUDE.md) |
| `mcp-aboutme-server/` | Node 服务 | MCP 服务器：向 AI 暴露 12 插件域 60+ 工具 | [mcp-aboutme-server/CLAUDE.md](mcp-aboutme-server/CLAUDE.md) |
| `api_forwarding_server/` | Node 服务 | WebSocket 配对转发（Web 前端 ↔ Flutter 客户端） | [api_forwarding_server/CLAUDE.md](api_forwarding_server/CLAUDE.md) |
| `floating_ball_plugin/` | 原生插件 | 系统级悬浮球 | 无独立文档（见 [模块职责](claude/module-responsibilities.md)） |
| `aboutme_foreground_service/` | 原生插件 | 前台服务（封装 flutter_foreground_task） | 无独立文档 |
| `aboutme_notifications/` | 原生插件 | 通知管理（封装 awesome_notifications） | 无独立文档 |
| `aboutme_intent/` | 原生插件 | Android Intent / 桌面快捷方式 | 无独立文档（`docs/ABOUTME_INTENT_IMPLEMENTATION.md`） |
| `aboutme_nfc/` | 原生插件 | NFC 读写 | 无独立文档（`docs/NFC_PLUGIN_IMPLEMENTATION.md`） |
| `aboutme_widgets/` | 原生插件 | Android/iOS 桌面小组件（40+ Provider，双尺寸） | [aboutme_widgets/CLAUDE.md](aboutme_widgets/CLAUDE.md) |

## 扫描状态

- 更新时间：2026-09-02（第二轮：补扫 aboutme_widgets 与 admin-vue）
- 已扫描：9 个子包的 pubspec/package.json、server-nodejs 与 mcp、api_forwarding 的源码结构、`aboutme_widgets` Dart API 与 Provider 全景、`server-nodejs/admin-vue` 全部源码与端点清单。
- 未深扫：其余 5 个原生插件（intent/nfc/foreground_service/notifications/floating_ball）的 android/ios 平台代码；server-nodejs 各 handler 实现细节与 plugins 运行时目录。
- 下一步建议：为 `aboutme_intent`（121 文件）与 `aboutme_nfc`（113 文件）补充独立文档。
