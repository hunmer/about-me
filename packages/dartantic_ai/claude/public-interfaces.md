# 对外接口

> 所属：packages/dartantic_ai · [返回索引](../CLAUDE.md)

## 入口 barrel：`lib/dartantic_ai.dart`

转出 `dartantic_interface` 全部 + 本包模块：`agent/agent.dart`、`model_string_parser.dart`、`orchestrators/`、`chat_models/`、`embeddings_models/`、`media_gen_models/`、`providers/`、`logging_options.dart`、`mcp_client.dart`。

## 本包定义的核心类

| 类 | 位置 | 说明 |
|----|------|------|
| `Agent` | `lib/src/agent/agent.dart:35` | `Agent(String model)` / `Agent.forProvider(...)`；`send`、`sendFor<TOutput>`（typed output）、`sendStream`、`generateMedia(Stream)`、`embedQuery/Documents` |
| `Chat` | `lib/src/chat_models/chat.dart` | 带历史的多轮会话封装 |
| `AnthropicProvider` 等 9 个 | `lib/src/providers/` | Anthropic/Cohere/Google/Mistral/Ollama/OpenAI/OpenAIResponses/XAI/XAIResponses；**AnthropicProvider 含本地 baseUrl 定制** |
| `McpClient` | `lib/src/mcp_client.dart` | MCP 服务器连接（stdio 本地 / HTTP 远程） |
| `CustomHttpClient` / `RetryHttpClient` | lib/src 根 | HTTP 包装（覆盖 baseUrl/headers、重试） |

抽象类型（`ChatMessage`/`ChatResult`/`Provider`/`Tool<TInput>` 等）在 `dartantic_interface` 包。

## 消费方用法（agent_chat）

`lib/plugins/agent_chat/services/native_tool_agent_service.dart`：

- Anthropic 格式：`Agent.forProvider(AnthropicProvider(apiKey, baseUrl, headers), ...)`（走本地 baseUrl 定制）。
- OpenAI 格式：`OpenAIProvider`；deepseek 域名换本地子类 `AppOpenAIProvider`（重写 `createChatModel` 注入 `DeepSeekCompatClient`，关闭 thinking——注释明言"dartantic 的 Provider 未暴露 httpClient"）。
- `sendStream` 消费 `chunk.thinking` / `chunk.output`；历史与图片附件用 `ChatMessage/TextPart/DataPart` 转换；工具用 `Tool` 装载。

`services/tool_schema_builder.dart`：应用 `ToolConfig` → `Tool(name, description, inputSchema)` 的 JSON Schema 转换（对应测试 `test/native_tool_schema_test.dart`）。
