# 模块职责

> 所属：packages/ · [返回索引](../CLAUDE.md)

## 同步服务器链路（现行，Dart）

| 子包 | 核心能力 |
|------|-----------|
| `aboutme_data_sdk/` | 数据核心：`AboutmeDataService` 本地/远程自动路由、存储接口（HTTP 远端明文+ETag 条件写 / 本地文件）、认证存储（JWT HS256 + PBKDF2，保留旧 nodejs 兼容）、12 个插件处理器（activity/bill/calendar/chat/checkin/contact/day/diary/goods/notes/todo/tracker）、通用 CRUD 与 handler 工厂 |
| `aboutme_server/` | 同步服务器（薄壳，默认 8874）：注册/登录/Token/API Key/FCM（auth_routes + auth_middleware）、文件 push/pull/list/delete（storage_routes，ETag 条件写）、19 插件域 REST（plugin_routes）、管理员（system_routes）、WS `file_updated` 广播（ws_hub）、**内置 MCP 端点 /mcp（68 工具，与 REST 共用 data_sdk 处理器）**、静态托管 `/admin` 管理面板（`admin-vue/`，[文档](../aboutme_server/admin-vue/CLAUDE.md)） |

> 已删除：`server-nodejs/`（Node.js：JWT/API Key、AES-256-GCM 加密同步、19 插件 REST、服务端插件系统、chokidar WS、Vue3 面板、MCP 75 工具）——2026-10-11 整体平移至 aboutme_server，**2026-10-14 目录彻底删除**。`mcp-aboutme-server/`、`api_forwarding_server/` 更早已删除。

## 本地 Dart 库（5 个）

| 子包 | 职责 | 客户端消费点 |
|------|------|--------------|
| `agentlib/` | OpenAI 兼容 HTTP/SSE 传输门面：`AgentLibClient`、`agent_slots`、`chat_models`、`openai_compat` | `lib/plugins/openai`（AI Agent 请求） |
| `dartantic_ai/` | dartantic_ai 3.4.2 vendor 镜像（Anthropic baseUrl 等 3 处定制，[文档](../dartantic_ai/CLAUDE.md)） | `lib/plugins/agent_chat` 原生工具调用（native_tool_agent_service） |
| `super_cupertino_navigation_bar/` | iOS 风格大标题导航栏组件库（+sketchFont） | `lib/widgets/super_cupertino_navigation_wrapper/`、bill 统计屏等 |
| `radial_disc_bottom_bar/` | 弧形圆盘浮动底部导航栏 | bill 等插件底部导航 |
| `material_emoji_picker/` | vendor 表情选择器（emoji.json） | chat 贴图/表情选择 |

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
- `server-nodejs/` 已整体删除（曾含示例服务端插件 `data-sync-logger-v2` 与 `plugin-store.json`，勿再检索引用）。
- 各插件实现细节文档：`docs/floating_ball_plugin.md`、`docs/aboutme_widgets.md`、`docs/NFC_PLUGIN_IMPLEMENTATION.md`、`docs/ABOUTME_INTENT_IMPLEMENTATION.md`、`docs/NATIVE_SERVICE_PLUGIN_PLAN.md`。
