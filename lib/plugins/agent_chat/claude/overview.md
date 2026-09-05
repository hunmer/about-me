# agent_chat 插件架构总览

> 所属：`lib/plugins/agent_chat/` · [返回索引](../CLAUDE.md)

## 定位

"专注于一对一 AI 对话的极简聊天插件"（主类注释，agent_chat_plugin.dart:32-44）：多会话管理（分组/搜索/筛选）、Agent 绑定（单 Agent 或 Agent 链）、文件上传、上下文管理（全局+会话级）、Token 统计、流式响应（打字机）、消息编辑/删除/重新生成、Markdown 渲染。主类 `AgentChatPlugin extends PluginBase with ChangeNotifier`（直接继承 PluginBase，无 JSBridgePlugin——**无 JS API**）。

## 核心机制：AI Agent 工具调用循环

每会话一个 `ChatController`（`controllers/chat_controller.dart`），组合 7 个管理器（`controllers/managers/`）：

| 管理器 | 职责 |
|--------|------|
| `AgentManager` | Agent 加载/切换（经 PluginManager 取 openai 插件） |
| `AIRequestHandler` | **三阶段工具调用**请求（见下） |
| `AgentChainExecutor` | Agent 链式调用编排，三种上下文模式（conversationContext / chainContext / previousOnly） |
| `ToolOrchestrator` | 两阶段工具识别/代码生成（被 AIRequestHandler 与 AgentChainExecutor 共用） |
| `ToolExecutor` | 解析并逐步执行工具调用（经 JSBridgeManager 执行 `run_js`） |
| `TemplateExecutor` / `MessageSender` | 工具模板 / 消息发送 |
| `ChatForegroundServiceManager` | Android 前台服务/通知/后台取消 |

三阶段流程（ai_request_handler.dart:15-21 注释）：第零阶段工具模板匹配 → 第一阶段工具需求识别 → 第二阶段工具执行代码生成。工具调用以 Markdown 格式返回，`ToolService.parseToolCallFromResponse` + `MarkdownToolCallParser` 解析，步骤间结果可传递，工具结果可触发续写（onContinueWithToolResult）。

## 其他机制

- **流式输出**：复用 openai 的 `RequestService.streamResponse`（onToken/onThinking 分离，Claude thinking 单独存储与渲染）。
- **语音通话循环**（voice_call_manager.dart:38-44）：录音 → 语音识别 → 发 AI → TTS 播报 → 循环；状态机 `VoiceCallState{idle, recording, recognized, processing, speaking, paused, error}`。语音识别含腾讯 ASR 实时 WebSocket（`services/speech/tencent_asr_service.dart`）。
- **临时会话**：`getOrCreateTemporaryConversation(routeName)` 供 core 的"当前页面问 AI"上下文查询（`core/action/built_in/ask_context_action`），带过期清理。
- **iOS 生态**：Shortcuts 处理（shortcuts_handler_service）+ 会话同步到 iOS 快捷指令（conversation_sync_service）+ Apple Watch（watch_connectivity_service）。
- 无加密。

## 依赖关系

- **强依赖 openai**：AIAgent 模型、RequestService（流式）、AgentController（经 `PluginManager.getPlugin('openai')`）。
- 依赖 **tts** 插件（voice_call_manager）。
- 依赖 core：JSBridgeManager（工具 JS 执行）、ForegroundTaskManager（aboutme_foreground_service 包）、sync/agent_chat_syncer、home_widget_service。

## 存储

- `agent_chat/conversations.json`（会话列表，串行保存链 `_conversationsSaveChain` 防并发写损坏）
- `agent_chat/messages/<conversationId>.json`（每会话消息单文件）
- 工具配置特殊：`tool_config_manager.dart` 直接用 `dart:io` 写 `app_data/agent_chat/tools/<pluginId>.json` + `index.json`（**从各插件 JS API 自动生成工具配置**，tool_config_manager.dart:84-144）
- Repository：`ClientAgentChatRepository extends IAgentChatRepository` → `AgentChatUseCase`
