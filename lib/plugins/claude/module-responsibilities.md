# 插件职责速查（29 个）

> 所属：`lib/plugins/` · [返回索引](../CLAUDE.md)
> 括号内为 Dart 文件数（2026-10-20 统计）。主文件均为 `<id>/<id>_plugin.dart`。

## AI 类

| 插件 | 职责 | 要点 |
|------|------|------|
| **chat**（120） | 本地频道式聊天/消息记录 | 频道-消息模型、时间线、标签；被 openai 的 ChatEventHandler 监听实现 @AI 回复；[独立文档](../chat/CLAUDE.md) |
| **agent_chat**（97） | 一对一 AI 对话 | 三阶段工具调用、Agent 链、语音通话循环、腾讯 ASR WebSocket；[独立文档](../agent_chat/CLAUDE.md) |
| **openai**（112） | AI 服务基础设施 | AIAgent/ServiceProvider/PromptPreset 管理，OpenAI 兼容 + Anthropic 双格式流式请求（传输经本地 `agentlib` 包）；aliveness 活人感宿主；moments 数据层（`openai/moments/` + `moments_js_api.dart`）；被 agent_chat 强依赖 |
| **live2d**（10） | Live2D 看板娘桌宠 | 气泡对话（经 agent_chat/openai 请求链）、TTS 自动朗读、在线模型仓库；jelly_home 首页的伙伴卡片消费它 |
| **moments**（13） | 朋友圈 UI 壳 | skygram 参考稿动态流/回忆/个人主页三页签 + 投稿面板 + die-cut 贴纸；数据与 AI 工具在 openai 插件；[独立文档](../moments/CLAUDE.md) |

## 记录与生活类

| 插件 | 职责 | 要点 |
|------|------|------|
| **diary**（32） | 日记 | 按日撰写、日历视图、DiaryUseCase、diary_entry_* 事件 |
| **activity**（59） | 活动/时间记录 | 时间线、周/日统计、标签统计、通知与 TTS 播报（依赖 tts） |
| **habits**（56） | 习惯追踪 | 打卡、计时器、技能点、分组；`/habit/timer` 深链被小组件与 NFC 共用 |
| **checkin**（37） | 打卡/习惯养成 | 打卡项+记录+统计；NFC 刷卡落点之一 |
| **todo**（41） | 待办任务 | TaskController + ReminderController；watchOS 同步接口 |
| **notes**（42） | 笔记 | 文件夹、快速创建；`notes/` 文件刷新前缀 |
| **nodes**（33） | 节点笔记本 | Notebook 内树形 Node（todo/doing/done 状态色 + Quill 富文本）；复用 goods 的 CustomField |
| **day**（30） | 纪念日/倒计时 | memorial_day 模型、日期区间 |
| **calendar**（28） | 日历/日程 | syncfusion_flutter_calendar 月视图、事件 CRUD |
| **calendar_album**（38） | 日历相册 | 按日期/标签照片墙；图片处理走 webview 的 LocalHttpServer |
| **media_log**（15） | 媒体记录（阅读+观影） | 瀑布流封面网格、16 款封面样式、14 个 JS API 名；数据走 AboutmeDataService；[独立文档](../media_log/CLAUDE.md) |
| **reminder**（11） | 本地定时提醒 | 按天/周/月本地通知；无路由无小组件无 JS API；杀进程后 `_checkMissedReminders` 补触发 |

## 物品与账务类

| 插件 | 职责 | 要点 |
|------|------|------|
| **bill**（43） | 账单/财务 | 记账、账户、统计、快捷记账；supercupertino 风格统计屏 |
| **goods**（48） | 物品/资产管理 | 多仓库、使用记录、自定义字段（被 nodes 复用） |
| **store**（44） | 积分商店 | 商品兑换、积分历史、积分事件系统（events/point_award_event） |
| **contact**（33） | 联系人管理 | 联系人、互动记录 |
| **tracker**（36） | 目标追踪 | Goal + Record、进度、缓存更新事件；NFC 落点之一 |

## 工具与系统类

| 插件 | 职责 | 要点 |
|------|------|------|
| **database**（19） | 自定义数据库（Notion 式） | 11 种字段类型、列表/网格视图；JSON 存储非 SQL，查询在 JS API 层 |
| **timer**（28） | 计时器 | 门面模式：核心在 `core/services/timer/unified_timer_controller.dart` |
| **tts**（24） | TTS 语音朗读 | 系统 TTS / 自定义 HTTP / MiniMax 三通道；消费方 activity、agent_chat |
| **nfc**（24） | NFC 标签读写 | 底层 `packages/aboutme_nfc` 原生子包；card_handlers 跨插件触发 |
| **webview**（41） | 内嵌浏览器 | 多标签、网址卡片、LocalHttpServer（全应用 HTTP 底座，8899 端口） |
| **scripts_center**（32） | 脚本中心 | JS 脚本编辑/商店/执行，经 JSBridgeManager 调插件 API；2026-10 新增脚本执行日志子系统 |
| **achievement**（16） | 成就系统 | 74 条定义、事件驱动（消费 41 个信号）、解锁结算与弹窗、桌面小组件；无 JS API 无路由；[独立文档](../achievement/CLAUDE.md) |
