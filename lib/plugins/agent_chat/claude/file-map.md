# agent_chat 目录速查

> 所属：`lib/plugins/agent_chat/` · [返回索引](../CLAUDE.md)
> 共 90 个 Dart 文件。

| 路径 | 内容 |
|------|------|
| `agent_chat_plugin.dart` | 主类（PluginBase + ChangeNotifier） |
| `controllers/chat_controller.dart` | 每会话聊天控制器，组合 7 个管理器 |
| `controllers/managers/` | AgentManager / AIRequestHandler / AgentChainExecutor / ToolOrchestrator / ToolExecutor / TemplateExecutor / MessageSender / ChatForegroundServiceManager |
| `controllers/conversation_controller.dart` | 会话列表控制器 |
| `screens/chat_screen/` | 聊天界面 + 15 个组件（agent_chain_config_dialog、agent_mode_selection_dialog、chain_message_container、markdown_content、message_bubble、tool_call_steps、tool_detail_dialog、voice_call_screen、voice_input_dialog 等） |
| `screens/conversation_list_screen/` | 会话列表 |
| `screens/tool_management_screen/` / `tool_template_screen/` | 工具与模板管理 |
| `screens/agent_chat_settings_screen.dart` | 设置 |
| `services/` | conversation_service、message_service、message_detail_service、conversation_sync_service（iOS 快捷指令）、shortcuts_handler_service、shortcut_result_storage、watch_connectivity_service、widget_service、agent_chain_preset_service、route_agent_config_service、chat_task_handler、token_counter_service、suggested_questions_service、`speech/`（tencent_asr_service）、`voice_call/`（voice_call_manager 等）、tool_service、tool_config_manager、tool_template_service |
| `models/` | 12 个模型文件（见 data-model） |
| `repositories/` | ClientAgentChatRepository（IAgentChatRepository） |
| `home_widgets/` | 主屏小组件 |
| `l10n/`、`data/sample_data` | 国际化与示例数据 |
| `managers/ai_message_status_manager.dart` | AI 消息状态管理 |
