# 模块职责

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## 客户端核心层（`lib/core/`，详见 [lib/CLAUDE.md](../lib/CLAUDE.md)）

| 子系统 | 职责 |
|--------|------|
| `plugin_manager.dart` / `plugin_base.dart` / `builtin_plugins.dart` | 插件注册、生命周期、访问追踪（现 28 个内置插件） |
| `data/aboutme_data_service.dart` | 全局数据入口：基于 aboutme_data_sdk 的本地/远程(REST)自动路由（2026-10 新增，新代码统一走它） |
| `storage/` / `storage_service.dart` | 跨平台文件存储抽象（IO / Web IndexedDB）+ HTTP 远端存储后端（底层同为 aboutme_data_sdk 转发） |
| `config_manager.dart` | 应用级与插件级配置 |
| `event/` | 全局事件总线，插件间通信 |
| `js_bridge/` | JavaScript 引擎（flutter_js）与双向通信 |
| `floating_ball/` | 悬浮球组件与动作管理 |
| `action/` | 自定义动作与快捷操作 |
| `app_widgets/` / `services/plugin_widget_sync_helper.dart` | 桌面小组件宿主与数据同步 |
| `services/sync/` | 插件域双向同步器（数据 SDK 化后逐步由 aboutme_data_sdk 处理器承担） |
| `services/` | FCM、日志、剪贴板、快捷方式、统一计时器、App 使用统计（app_usage_service）、桌面窗口几何记忆（window_geometry_service）等 |
| `routing/` / `route/` | 路由历史与插件路由处理 |

## 功能插件（`lib/plugins/`，28 个内置插件）

| 插件 | 职责 | 旧版文档 |
|------|------|----------|
| achievement | 成就系统：定义 + 统计解析 + 解锁弹窗 + 桌面小组件（2026-10 新增） | [查看](../lib/plugins/achievement/CLAUDE.md) |
| activity | 活动记录：时间轴、标签、统计 | [查看](../lib/plugins/activity/CLAUDE.md) |
| agent_chat | Agent 聊天：工具调用、语音识别 | [查看](../lib/plugins/agent_chat/CLAUDE.md) |
| bill | 账单：多账户、统计、订阅管理 | [查看](../lib/plugins/bill/CLAUDE.md) |
| calendar | 日历：8 种视图、Todo 集成 | [查看](../lib/plugins/calendar/CLAUDE.md) |
| calendar_album | 日记相册：照片标签 | [查看](../lib/plugins/calendar_album/CLAUDE.md) |
| chat | 聊天：多频道、消息管理 | [查看](../lib/plugins/chat/CLAUDE.md) |
| checkin | 签到：分组、统计、连续签到 | [查看](../lib/plugins/checkin/CLAUDE.md) |
| contact | 联系人：信息管理、互动历史 | [查看](../lib/plugins/contact/CLAUDE.md) |
| database | 自定义数据库：11 种字段类型 | [查看](../lib/plugins/database/CLAUDE.md) |
| day | 纪念日：倒计时/正计时 | [查看](../lib/plugins/day/CLAUDE.md) |
| diary | 日记：日历视图、Markdown | [查看](../lib/plugins/diary/CLAUDE.md) |
| goods | 物品管理：分类、使用记录 | [查看](../lib/plugins/goods/CLAUDE.md) |
| habits | 习惯管理：技能关联、一万小时 | [查看](../lib/plugins/habits/CLAUDE.md) |
| nfc | NFC：近场通信读写 | [查看](../lib/plugins/nfc/CLAUDE.md) |
| nodes | 节点：笔记本树结构 | [查看](../lib/plugins/nodes/CLAUDE.md) |
| notes | 笔记：无限层级、全文搜索 | [查看](../lib/plugins/notes/CLAUDE.md) |
| openai | AI 中枢：多服务商、Agent/预设管理、**aliveness 活人感**（延迟回复/分条气泡/记忆/日程/主动消息/语音，2026-10-04）、**moments 朋友圈**（AI 动态流/资产图/自主生图，2026-10-05） | [查看](../lib/plugins/openai/CLAUDE.md) |
| reminder | 定时提醒：本地通知、每天/每周/每月调度、错过补触发 | [查看](../lib/plugins/reminder/CLAUDE.md) |
| scripts_center | 脚本中心：JS 脚本管理 | [查看](../lib/plugins/scripts_center/CLAUDE.md) |
| store | 物品兑换：积分系统 | [查看](../lib/plugins/store/CLAUDE.md) |
| timer | 计时器：多种计时方式 | [查看](../lib/plugins/timer/CLAUDE.md) |
| todo | 任务：子任务、优先级、日期范围 | [查看](../lib/plugins/todo/CLAUDE.md) |
| tracker | 目标追踪：量化目标、数据记录 | [查看](../lib/plugins/tracker/CLAUDE.md) |
| tts | 文本转语音：系统 TTS + HTTP API | [查看](../lib/plugins/tts/CLAUDE.md) |
| webview | WebView：浏览器、应用商店 | [查看](../lib/plugins/webview/CLAUDE.md) |
| live2d | Live2D 桌宠：存档管理（模型+绑定 Agent）、TTS 自动朗读、在线模型仓库（渲染层在 jelly_home） | [查看](../lib/plugins/live2d/CLAUDE.md) |
| media_log | 媒体记录：阅读 + 观影记录（瀑布流封面网格，手绘纸墨风，2026-10 新增） | [查看](../lib/plugins/media_log/CLAUDE.md) |

## 服务端与子包（`packages/`，详见 [packages/CLAUDE.md](../packages/CLAUDE.md)）

| 模块 | 职责 |
|------|------|
| `packages/aboutme_server` | **现行同步服务器（Dart 薄壳）**：REST 19 插件 API、文件存储 ETag 条件写、WS `file_updated` 广播、认证（注册/登录/Token/API Key/FCM）、MCP `/mcp`（68 工具）、管理界面托管；默认端口 8874 |
| `packages/aboutme_data_sdk` | 纯数据 SDK（客户端与服务器共用）：存储接口/HTTP 远端存储/本地文件存储/JWT+PBKDF2 认证/12 个插件处理器/AboutmeDataService 路由 |
| `packages/server-nodejs` | **[已废弃 2026-10-11]** 旧 Node.js 同步服务器（Express + TS + Vue3 面板 + MCP 75 工具），仅历史参考 |
| `packages/agentlib` | 本地 Dart 包：OpenAI 兼容 HTTP/SSE 传输门面（AgentLibClient + agent_slots 资源槽位模型），被 openai 与 agent_chat 插件使用（[文档](../packages/agentlib/CLAUDE.md)） |
| `packages/dartantic_ai` | 上游 dartantic_ai 3.4.2 vendor 镜像（3 处本地定制：Anthropic baseUrl 等），agent_chat 原生工具调用消费（[文档](../packages/dartantic_ai/CLAUDE.md)） |
| `packages/super_cupertino_navigation_bar` | 本地 Dart 包：iOS 风格大标题导航栏 UI 库（+sketchFont） |
| `packages/radial_disc_bottom_bar` | 本地 Dart 包：弧形圆盘浮动底部导航栏 |
| `packages/material_emoji_picker` | vendor 表情选择器（emoji.json 数据源） |
| `packages/floating_ball_plugin` | 系统级悬浮球原生插件 |
| `packages/aboutme_foreground_service` | 前台服务（封装 flutter_foreground_task） |
| `packages/aboutme_notifications` | 通知管理（封装 awesome_notifications） |
| `packages/aboutme_intent` | Android Intent / 快捷方式处理 |
| `packages/aboutme_nfc` | NFC 读写原生能力 |
| `packages/aboutme_widgets` | Android/iOS 桌面小组件原生实现（40+ Provider，[文档](../packages/aboutme_widgets/CLAUDE.md)） |

## 其他顶层目录

| 目录 | 职责 |
|------|------|
| `shared_models/` | 客户端/服务端共享 Dart 模型：Repository 接口、UseCase、同步协议、工具类 |
| `online/` | WebView 小程序仓库（4 应用 + preload 工具注册）、在线脚本、AI Agent 配置（[文档](../online/CLAUDE.md)） |
| `docs/` | 70 篇专题文档：小组件、快捷方式、统一计时器、Live Activities、成就系统、各原生插件实现等（含 emoji_sheet/jelly_icons/achievement_icons 切图资产） |
| `handoff/` | Agent 会话交接底稿（设计系统迁移、Live2D 迭代、ai-image 脚本中心、活人感系统、数据 SDK 化等） |
| `plan/` | 产品规划文档（AI 陪伴活人感增强系统 PRD 与执行方案） |
| `outputs/` | 界面截图产物（todo-app 演示图） |
| `skills/` | 嵌套仓库 moe-ui-skill（gitlink，无 .gitmodules，内容不在本仓追踪） |
| `tools/` | 图片切图脚本资产（agent_covers 封面切分） |
| `scripts/` | 多平台构建与发布脚本（有自己的 [scripts/CLAUDE.md](../scripts/CLAUDE.md)） |
| `tool_templates/` | 插件工具模板（bill / calendar_album / store） |
| `design.md` | 标准页面结构规范（页面 = 导航栏 Wrapper + body） |
| `android/ ios/ macos/ linux/ windows/ web/` | 各平台宿主工程 |
| `.github/workflows/` | android / ios / windows / macos / web 五个构建工作流 |
