# chat 对外接口

> 所属：`lib/plugins/chat/` · [返回索引](../CLAUDE.md)

## 路由

- 主页经 `/plugin/chat`（PluginManager.openPlugin）打开 `ChatBottomBar` 三页签。
- `ChatMainView({channelId})` 可编程式直达指定频道。

## JS API（⚠️ 当前未实际注册）

`chat_js_api.dart`（part 文件）实现了完整 API 并全部代理到 `chatUseCase`：

- 频道：`getChannels` / `createChannel` / `deleteChannel` / `findChannelBy(Id|Title)`
- 消息：`sendMessage` / `getMessages` / `getMessagesByDate` / `deleteMessage` / `findMessageBy(Id|Content)`
- 用户：`getCurrentUser` / `getAIUser`

**但主类 `chat_plugin.dart:143` 的 `defineJSAPI()` override 返回空 map**，上述 API 当前未进入 JSBridgeManager——迁移中间态。扩展前先核实并接回（删掉空 override 或改为调用 part 文件实现）。

## 数据选择器

`chat_data_selectors.dart` 注册到 PluginDataSelectorService：

- `chat.channel` — 单级频道选择
- `chat.message` — 两级选择（频道 → 消息）

## 事件（供其他模块订阅）

| 事件 | 载荷要点 | 订阅方 |
|------|----------|--------|
| `chat_message_sent` | 消息对象（`metadata['agents']` 含被 @ 的助手） | openai ChatEventHandler（流式 AI 回复）、store（积分）、home_widgets |
| `chat_message_updated` | 消息对象 | home_widgets |

## Dart 层调用方

- openai：`ChatEventHandler._processAgentResponse` 生成回复写回 chat 消息
- core：`services/sync/chat_syncer`（同步）、`home_widget_service`、`floating_ball_manager`、`WatchConnectivityManager`（Apple Watch，chat_plugin.dart:185-191）
