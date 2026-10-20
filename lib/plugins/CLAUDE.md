# lib/plugins/ 功能插件层

29 个内置功能插件的宿主目录（约 1166 个 Dart 文件）。插件体系基于两层基类（`core/plugin_base.dart` 的 `PluginBase` → `base_plugin.dart` 的 `BasePlugin`），通过四大能力接入核心：**JS API**（`JSBridgePlugin` mixin）、**路由**（声明式 routes 文件 + `PluginRouteHandler` 深链）、**主页小组件**（`home_widgets/` + `HomeWidgetRegistry`）、**数据选择器**（悬浮球动作面板）。多数插件走 UseCase 分层（接口在 `shared_models/`，插件内实现 `client_*_repository.dart`）；2026-10 新增的 media_log/achievement 改走 `AboutmeDataService`/事件总线。存储统一为 JSON 文件（`plugin.storage`），无数据库。**全部 29 个插件均有 `l10n/` 翻译文件**（zh/en，经 `lib/l10n/unified_translations.dart` 聚合到 GetX）。

关键依赖链：`agent_chat → openai → chat`（AI 三件套，均有独立文档）；**moments（UI 壳）→ openai/moments（数据层）**；`jelly_home 首页伙伴卡片 / live2d` 复用 agent_chat 与 openai 的请求链；`webview/LocalHttpServer` 是 goods/store/contact/calendar_album 的 HTTP 底座；`nfc/card_handlers` 直达 checkin/goods/habits/tracker；`scripts_center` 脚本可调全部暴露 JS API 的插件。

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
| [插件职责速查](claude/module-responsibilities.md) | 29 个插件职责与要点分类表 | 定位功能归属 |
| [插件开发约定](claude/conventions.md) | 新插件步骤、主类模式、JS API/存储/事件规范 | 写新插件之前 |
| [入口与生命周期](claude/entrypoints.md) | 注册链、挂载时机、小组件注册、数据刷新 | 排查插件初始化问题 |
| [对外接口全景](claude/public-interfaces.md) | 全部路由、JS API、数据选择器、事件 | 对接路由/脚本/悬浮球 |
| [目录速查](claude/file-map.md) | 每个插件的子目录结构与 part 文件 | 找代码 |
| [索引变更记录](claude/changelog.md) | 本目录文档更新历史 | 重复运行 /init-project 时 |

## 模块索引

| 插件 | 职责摘要 | 文档 |
|------|----------|------|
| `chat/`（120 文件） | 频道式聊天/消息记录、时间线 | [chat/CLAUDE.md](chat/CLAUDE.md) |
| `agent_chat/`（97 文件） | 一对一 AI 对话、工具调用、语音通话 | [agent_chat/CLAUDE.md](agent_chat/CLAUDE.md) |
| `openai/`（112 文件） | AI 中枢：服务商/Agent/预设 + **aliveness 活人感**（延迟/分条/记忆/日程/主动消息）+ **moments 数据层**（`openai/moments/` + moments_js_api） | [openai/CLAUDE.md](openai/CLAUDE.md) |
| `moments/`（13 文件） | **朋友圈 UI 壳插件**（2026-10 独立）：动态流/回忆/个人主页三页签，数据在 openai/moments | [moments/CLAUDE.md](moments/CLAUDE.md) |
| `live2d/`（10 文件） | Live2D 桌宠存档与播报设置（渲染在 jelly_home） | [live2d/CLAUDE.md](live2d/CLAUDE.md) |
| `media_log/`（15 文件） | 媒体记录：阅读+观影（瀑布流封面网格；14 个 JS API 名；数据走 AboutmeDataService） | [media_log/CLAUDE.md](media_log/CLAUDE.md) |
| `achievement/`（16 文件） | 成就系统：74 条定义、事件驱动（消费 41 个信号）、解锁结算（无 JS API 无路由） | [achievement/CLAUDE.md](achievement/CLAUDE.md) |
| 其余 22 个 | 详见 [插件职责速查](claude/module-responsibilities.md) | 旧版 CLAUDE.md（待迁移） |

## 扫描状态

- 更新时间：2026-10-20（第七轮增量：moments 独立成插件并建档，28→29；文件数 1140→1166；核实 29 插件全部具备 l10n 目录、插件文件数全量重统计）。
- 已扫描：29 个插件注册逐一核对（`builtin_plugins.dart`）、moments 插件 13 源文件全量、moments 数据层归属（openai/moments + moments_js_api）、各插件 Dart 文件数重统计、chat/agent_chat/openai/live2d/media_log/achievement 前几轮深扫沿用。
- 未深扫：其余 22 个插件的 screens/widgets 内部实现（沿用各插件旧版 CLAUDE.md 与职责表）、notes 的 todo 子功能与 calendar_album entry_detail 删除后的归属细节。
- 下一步建议：逐步迁移其余旧版插件 CLAUDE.md 为"索引 + claude/" 格式（已迁移 media_log/achievement/moments）。
