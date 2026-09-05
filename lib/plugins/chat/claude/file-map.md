# chat 目录速查

> 所属：`lib/plugins/chat/` · [返回索引](../CLAUDE.md)
> 共 109 个 Dart 文件。

| 路径 | 内容 |
|------|------|
| `chat_plugin.dart` | 主类（服务装配、兼容 getter、Watch 同步、refreshData） |
| `chat_js_api.dart`（part） | JS API 实现（未挂接，见 public-interfaces） |
| `chat_data_selectors.dart`（part） | chat.channel / chat.message 选择器 |
| `services/` | ChatDataService（频道+消息）、ChatConfigService（用户+设置）、TagService、UIService、ChatWidgetService、FileService |
| `repositories/client_chat_repository.dart` | IChatRepository 实现 → ChatUseCase |
| `models/` | Channel / Message / User / MessageTag / FileMessage / serializers |
| `screens/channel_list/` | 频道列表 + controller + tile/分组选择器/频道对话框 |
| `screens/chat_screen/` | 聊天界面：controller、dialogs（日历/清空/编辑）、`widgets/message_bubble/`（avatar、favorite_icon、fixed_symbol、reply_widget、thinking_indicator 等）、`widgets/message_input/`、`widgets/message_input_actions/handlers/`（audio/file/image/local_video/video/advanced_editor 六种） |
| `screens/timeline/` | 时间线（卡片/瀑布流）+ `controllers/timeline_controller/` 6 个 part（base/channel/message_handler/pagination/scroll/search）+ models/timeline_filter |
| `screens/tags/` | 标签管理与标签消息页 |
| `home_widgets/` | 主屏小组件（监听 chat 事件刷新） |
| `events/` | user_events 等 |
| `l10n/` | zh / en / jp |
| `utils/` | message_operations 等 |
| `widgets/`（顶层） | audio_player / file_message / image_message 等 |
| `data/sample_data.dart` | 首启示例数据 |
