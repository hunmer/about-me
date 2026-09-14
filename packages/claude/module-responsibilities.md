# 模块职责

> 所属：packages/ · [返回索引](../CLAUDE.md)

## Node 服务（详见各自 CLAUDE.md）

| 子包 | 核心能力 |
|------|-----------|
| `server-nodejs/` | 用户注册/登录（JWT）与 API Key；文件 push/pull/list/delete（AES-256-GCM 端到端加密）；19 个插件域 REST API（工厂 + handler 模式）；服务端插件系统（ZIP/商店安装、启停、before/after 钩子）；WebSocket 实时同步（chokidar 文件监听）；FCM 推送；ZIP 数据导出；Vue3 + Naive UI 管理面板 |
| `server-nodejs/src/mcp/` | 内置 MCP 端点（/mcp，Streamable HTTP）；`aboutme_{plugin}_{action}` 工具集（chat/notes/activity/goods/bill/todo/diary/checkin/calendar/contact/tracker/day，75 工具）；`client.ts` 的 AboutmeClient 进程内直调插件处理器 |

> 已删除：`mcp-aboutme-server/`（独立 stdio MCP）、`api_forwarding_server/`（WebSocket 配对转发）。

## 本地 Dart 库（2 个）

| 子包 | 职责 | 客户端消费点 |
|------|------|--------------|
| `agentlib/` | OpenAI 兼容 HTTP/SSE 传输门面：`AgentLibClient`、`agent_slots`、`chat_models`、`openai_compat` | `lib/plugins/openai`（AI Agent 请求） |
| `super_cupertino_navigation_bar/` | iOS 风格大标题导航栏组件库 | `lib/widgets/super_cupertino_navigation_wrapper/`、bill 统计屏等 |

## Flutter 原生插件（6 个）

| 插件 | 平台 | 职责 | 客户端消费点 |
|------|------|------|--------------|
| `floating_ball_plugin` | Android 为主 | 系统级悬浮球（无需应用前台） | `lib/core/floating_ball/`（Flutter 侧另有 app_widgets/floating_ball_service） |
| `aboutme_foreground_service` | Android/iOS | 封装 flutter_foreground_task：常驻前台服务（语音通话等长任务） | `lib/core/app_initializer.dart` 初始化 |
| `aboutme_notifications` | Android/iOS | 封装 awesome_notifications：本地通知与频道管理 | `lib/core/notification_controller.dart` |
| `aboutme_intent` | Android | Intent 处理、桌面快捷方式（dedicated intents） | 快捷方式管理、`docs/SHORTCUTS_*` 系列 |
| `aboutme_nfc` | Android/iOS | NFC 标签读写 | `lib/plugins/nfc` |
| `aboutme_widgets` | Android/iOS | 桌面小组件原生渲染：20 插件域 × 2 尺寸 + 9 个专用（四象限/签到月历/习惯计时等）+ 快速小组件（[文档](../aboutme_widgets/CLAUDE.md)） | `lib/core/app_widgets/home_widget_service.dart` + `plugin_widget_sync_helper.dart` |

## 补充说明

- 原生插件 pubspec 多为默认描述（"A new Flutter plugin project."），真实用途以本表与 `docs/` 对应文档为准。
- `server-nodejs/plugins/` 内含示例服务端插件 `data-sync-logger-v2` 与 `plugin-store.json`（商店清单）。
- 各插件实现细节文档：`docs/floating_ball_plugin.md`、`docs/aboutme_widgets.md`、`docs/NFC_PLUGIN_IMPLEMENTATION.md`、`docs/ABOUTME_INTENT_IMPLEMENTATION.md`、`docs/NATIVE_SERVICE_PLUGIN_PLAN.md`。
