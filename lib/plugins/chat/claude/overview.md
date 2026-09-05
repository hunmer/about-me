# chat 插件架构总览

> 所属：`lib/plugins/chat/` · [返回索引](../CLAUDE.md)

## 定位

本地频道式聊天/消息记录插件（仿 IM 的"频道-消息"模型，类似微信文件助手），无网络通信——**无端到端加密、无 WebSocket**（全目录 grep 确认）。AI 回复能力不在本插件内，而是 openai 插件的 `ChatEventHandler` 订阅 `chat_message_sent` 事件实现（见下）。

## 主类与服务层

主类 `ChatPlugin`（`chat_plugin.dart:84`，`extends BasePlugin with ChangeNotifier, JSBridgePlugin`，id=`chat`）。

服务层（`services/`）：

| 服务 | 职责 |
|------|------|
| `ChatDataService` | 频道+消息 CRUD、持久化、事件广播（频道+消息两个域合一，迁移自旧的 ChannelService/MessageService） |
| `ChatConfigService` | 用户 + 设置（迁移自 SettingsService/UserService） |
| `TagService` | 消息标签 |
| `UIService` | UI 组件构建（卡片视图、设置界面） |
| `ChatWidgetService` | 主屏小组件 |
| `FileService` | 文件上传、预览 |

主类保留向后兼容 getter：`channelService/messageService → dataService`、`settingsService/userService → configService`（chat_plugin.dart:129-132，标注"逐步迁移"）——**旧文档中的 ChannelService/MessageService 已合并，勿再引用**。

Repository 层：`repositories/client_chat_repository.dart` 的 `ClientChatRepository extends IChatRepository`（shared_models 接口），适配上述服务供 `ChatUseCase` 使用。

## 界面结构

`buildMainView` 返回 `ChatBottomBar`（TabBarView 三页签）：`ChannelListScreen`（频道列表）/ `TimelineScreen`（跨频道时间线，卡片/瀑布流双视图）/ `TagsScreen`（标签管理）。`ChatMainView({channelId})` 可直接打开指定频道。

时间线控制器拆分为 6 个 part：`timeline_controller/{base,channel,message_handler,pagination,scroll,search}_controller`。

消息输入支持六种处理器（`widgets/message_input_actions/handlers/`）：audio/file/image/local_video/video/advanced_editor。

## 与其他模块的关系

- **openai（@AI 回复）**：openai 的 `handlers/chat_event_handler.dart` 订阅 `chat_message_sent`，解析消息 `metadata['agents']` 中被 @ 的助手，并发生成流式回复写回 chat 消息。
- **store**：积分奖励（订阅 chat 事件）；**scripts_center**：脚本事件选项。
- **iOS**：经 core 的 `WatchConnectivityManager` 与 Apple Watch 同步（chat_plugin.dart:185-191）。
- **core**：floating_ball_manager、home_widget_service、`services/sync/chat_syncer`。

## 存储与刷新

- 纯文件 JSON：`chat/channels.json`（频道 ID 列表）、`chat/channel/<id>.json`（频道详情）、`chat/messages/<id>.json`（每频道消息单文件）、`chat/settings.json`、`chat/users`、`chat/avatars/`。首启从 `sample_data.dart` 灌示例数据。
- 消息中的文件路径存储时相对化（剥离 `./app_data` 前缀，`FilePathConverter`；Message 的异步 create/copyWith 做转换）。
- 文件刷新前缀 `chat/`（`supportsFileRefresh` / `refreshData` → `dataService.reloadChannels()`）。
