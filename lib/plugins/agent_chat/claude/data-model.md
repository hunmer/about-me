# agent_chat 数据模型与存储

> 所属：`lib/plugins/agent_chat/` · [返回索引](../CLAUDE.md)

## 模型（models/，12 个文件）

| 类 | 用途 |
|----|------|
| `Conversation`（含 `ToolAgentConfig`） | 会话：`agentId`（单 Agent）或 `agentChain`（链式）；toolDetectionConfig / toolExecutionConfig（两阶段工具专用 Agent）；groups / contextMessageCount / isPinned / ttsConfig / voiceCallConfig |
| `ChatMessage` | 消息：isUser / tokenCount / attachments / toolCall / matchedTemplateIds / parentId / isSessionDivider / generatedByAgentId / **chainStepIndex + chainExecutionId + isFinalSummary**（链调用标记）/ thinkingContent（Claude thinking 单独存储） |
| `AgentChainNode` + `AgentContextMode` | 链节点与上下文模式（conversationContext / chainContext / previousOnly） |
| `AgentChainPreset` | 可复用 Agent 链预设 |
| `ToolCallStep` / `ToolCallResponse` / `ToolCallStatus` | 工具调用步骤与状态机 |
| `SavedToolTemplate` | 保存的工具调用步骤模板 |
| `ToolConfig`（含 ToolParameter / ToolReturns） | JS 工具配置（从各插件 JS API 自动生成） |
| `ChatCommand` / `ConversationGroup` / `FileAttachment` | 命令、分组、附件 |
| `VoiceCallConfig` + `TTSConfig` | 语音通话与 TTS 配置 |
| `AIMessageStatus`（Data/StepInfo） | AI 消息生成状态 |

## 存储

| 路径 | 内容 |
|------|------|
| `agent_chat/conversations.json` | 会话列表（串行保存链防并发写损坏） |
| `agent_chat/messages/<conversationId>.json` | 每会话消息单文件 |
| `app_data/agent_chat/tools/<pluginId>.json` + `index.json` | 工具配置（dart:io 直写，从各插件 JS API 自动生成） |

注意：旧文档写"每条消息一个 JSON、tools/ 放手工 JSON"——已过时，现为每会话单文件 + 工具配置自动生成。

## 服务层

`ConversationService` / `MessageService` / `MessageDetailService`（会话与消息业务）→ 经 `ClientAgentChatRepository`（IAgentChatRepository 实现）供 `AgentChatUseCase`。其余服务见 [file-map](file-map.md)。
