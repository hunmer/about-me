# chat 聊天插件

本地频道式聊天/消息记录插件（仿 IM 的"频道-消息"模型），Flutter 客户端最大的插件（109 个 Dart 文件）。提供多频道管理、六种消息类型（文本/文件/图片/视频/本地视频/音频）、跨频道时间线、消息标签、收藏/固定/回复。**本身不做 AI 与网络**：@AI 回复由 openai 插件的 `ChatEventHandler` 订阅 `chat_message_sent` 事件实现；无加密、无 WebSocket。存储为纯 JSON 文件（每频道一个消息文件），经 `ClientChatRepository` + `ChatUseCase` 分层。

## 约定的规则

- 旧文档的 `ChannelService`/`MessageService` 已合并为 **`ChatDataService`**；主类兼容 getter 标注"逐步迁移"，新代码直接用新服务。
- **JS API 当前未注册**（主类 `defineJSAPI()` 返回空 map，`chat_plugin.dart:143`），part 文件里的完整实现未挂接——扩展前先核实。
- 文件路径入库前相对化（剥离 `./app_data`，`FilePathConverter`），读取时经 Message 异步 create/copyWith 转换。
- 文件刷新前缀 `chat/`。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 服务层、界面结构、与 openai/store 的协作 | 理解插件全貌 |
| [数据模型](claude/data-model.md) | Channel/Message/User 模型与存储路径 | 改数据结构 |
| [对外接口](claude/public-interfaces.md) | JS API（未挂接警示）、选择器、事件 | 写脚本/跨插件对接 |
| [目录速查](claude/file-map.md) | 109 文件的分区导航 | 找代码 |
| [索引变更记录](claude/changelog.md) | 文档更新历史 | 重复运行 /init-project 时 |

## 扫描状态

- 更新时间：2026-09-05（首轮"索引+详情"格式，替换 2025-11-13 旧版单文件文档）
- 已扫描：主类、服务层、模型、时间线控制器拆分、输入处理器、存储路径、跨模块依赖（openai/store/scripts_center/Watch/同步）。
- 未深扫：message_bubble 与 dialogs 的 UI 实现细节、l10n 词条。
