# lib/plugins/ 功能插件层

26 个内置功能插件的宿主目录（约 1113 个 Dart 文件）。插件体系基于两层基类（`core/plugin_base.dart` 的 `PluginBase` → `base_plugin.dart` 的 `BasePlugin`），通过四大能力接入核心：**JS API**（`JSBridgePlugin` mixin）、**路由**（声明式 routes 文件 + `PluginRouteHandler` 深链）、**主页小组件**（`home_widgets/` + `HomeWidgetRegistry`）、**数据选择器**（悬浮球动作面板）。17/26 插件走 UseCase 分层（接口在 `shared_models/`，插件内实现 `client_*_repository.dart`），存储统一为 JSON 文件（`plugin.storage`），无数据库。

关键依赖链：`agent_chat → openai → chat`（AI 三件套，均有独立文档）；`jelly_home 首页伙伴卡片 / live2d` 复用 agent_chat 与 openai 的请求链；`webview/LocalHttpServer` 是 goods/store/contact/calendar_album 的 HTTP 底座；`nfc/card_handlers` 直达 checkin/goods/habits/tracker；`scripts_center` 脚本可调全部暴露 JS API 的插件。

## 约定的规则

- 新插件：建目录 → `core/builtin_plugins.dart` 注册 → 路由 → `home_widgets/register()`；详见 [插件开发约定](claude/conventions.md)。
- JS API 命名 `get{Entity}s` / `create{Entity}` / `update{Entity}` / `delete{Entity}`；`initialize()` 最后一步 `await registerJSAPI()`。
- **chat 插件 `defineJSAPI()` 当前返回空 map（迁移中间态）**，扩展其 JS API 前先核实 `chat_plugin.dart:143`。
- bill 用 `controls/`、timer 用 `views/`、calendar 有 `pages/`——历史目录名，勿顺手统一。
- reminder/nfc 无路由；reminder 无小组件无 JS API；live2d 的 `/live2d` 在外部注册且**指向设置页**（主列表走 `PluginManager.openPlugin`），渲染层在 `lib/screens/jelly_home/`。
- openai 是 AI 中枢：@AI 消息统一从 openai 的 ChatEventHandler 分流，活人感宿主差异只写在 `openai/aliveness/channels/`。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [插件体系架构](claude/overview.md) | 基类链、生命周期、四大能力、注册流程 | 第一次理解插件机制 |
| [插件职责速查](claude/module-responsibilities.md) | 26 个插件职责与要点分类表 | 定位功能归属 |
| [插件开发约定](claude/conventions.md) | 新插件步骤、主类模式、JS API/存储/事件规范 | 写新插件之前 |
| [入口与生命周期](claude/entrypoints.md) | 注册链、挂载时机、小组件注册、数据刷新 | 排查插件初始化问题 |
| [对外接口全景](claude/public-interfaces.md) | 全部路由、JS API、数据选择器、事件 | 对接路由/脚本/悬浮球 |
| [目录速查](claude/file-map.md) | 每个插件的子目录结构与 part 文件 | 找代码 |
| [索引变更记录](claude/changelog.md) | 本目录文档更新历史 | 重复运行 /init-project 时 |

## 模块索引

| 插件 | 职责摘要 | 文档 |
|------|----------|------|
| `chat/`（109 文件） | 频道式聊天/消息记录、时间线 | [chat/CLAUDE.md](chat/CLAUDE.md) |
| `agent_chat/`（91 文件） | 一对一 AI 对话、工具调用、语音通话 | [agent_chat/CLAUDE.md](agent_chat/CLAUDE.md) |
| `openai/`（104 文件） | AI 中枢：服务商/Agent/预设 + **aliveness 活人感**（延迟/分条/记忆/日程/主动消息）+ **moments 朋友圈**（2026-10 新增双子系统） | [openai/CLAUDE.md](openai/CLAUDE.md) |
| `live2d/`（9 文件） | Live2D 桌宠存档与播报设置（渲染在 jelly_home） | [live2d/CLAUDE.md](live2d/CLAUDE.md) |
| 其余 22 个 | 详见 [插件职责速查](claude/module-responsibilities.md) | 旧版 CLAUDE.md（待迁移） |

## 扫描状态

- 更新时间：2026-10-05（第五轮增量：openai 重写为新格式并补 aliveness/moments 文档；live2d 首次建档）
- 已扫描：26 个插件全部主类（继承关系/mixin/路由/分层标记逐个 grep 验证）、路由全集、home_widgets 覆盖、chat 与 agent_chat 内部实现（deep）、openai 全量（含 aliveness 23 文件与 moments 10 文件逐个）、live2d 全部 9 文件、跨插件依赖关系。
- 未深扫：其余 22 个插件的 screens/widgets 内部实现（沿用各插件旧版 CLAUDE.md 与职责表）、openai 的市场(soul_forge)/通用 UI 细节。
- 下一步建议：逐步迁移其余旧版插件 CLAUDE.md 为"索引 + claude/" 格式。
