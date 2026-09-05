# chat 数据模型与存储

> 所属：`lib/plugins/chat/` · [返回索引](../CLAUDE.md)

## 模型（models/）

| 类 | 文件 | 关键字段 |
|----|------|----------|
| `Channel` | `models/channel.dart` | id / title / icon / backgroundColor / priority / **groups（多分组）** / fixedSymbol / draft / backgroundPath / metadata（存上下文范围与最后选择的智能体） |
| `Message` | `models/message.dart` | `MessageType{received, sent, file, image, video, audio}` / editedAt / fixedSymbol / bubbleColor / metadata（含 fileInfo）/ replyTo / replyToId；**异步 create/copyWith 做文件相对路径转换**（FilePathConverter） |
| `User` | `models/user.dart` | 用户（自己 + AI 用户，isAI 标记） |
| `MessageTag` | `models/` | 消息标签 |
| `FileMessage` | `models/file_message.dart` | 文件消息 |
| `UserSerializer` / `MessageSerializer` | `models/serializers.dart` | 序列化器 |
| `TimelineFilter` | `screens/timeline/models/timeline_filter.dart` | 类型/日期范围/选中频道与用户集/isAI/isFavorite/搜索范围开关 |

注意：旧文档中 Message 的 `isFavorite/isPinned/unreadCount/lastMessage` 等字段描述已过时，以 `models/message.dart` 现行为准（收藏经 metadata/favorite 机制，UI 层有 favorite_icon 组件）。

## 存储路径

| 路径 | 内容 |
|------|------|
| `chat/channels.json` | 频道 ID 列表 |
| `chat/channel/<id>.json` | 频道详情 |
| `chat/messages/<id>.json` | 每频道消息（单文件存整频道） |
| `chat/settings.json` | 插件设置 |
| `chat/users`、`chat/avatars/` | 用户与头像 |

旧文档写"每条消息一个 JSON 文件"——已过时，现为**每频道一个消息文件**。

## 事件

- `chat_message_sent` / `chat_message_updated`（EventManager 广播）——openai 的 ChatEventHandler（@AI 回复）、store（积分）、home_widgets 均订阅。
