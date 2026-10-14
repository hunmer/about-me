# 架构总览

> 所属：packages/dartantic_ai · [返回索引](../CLAUDE.md)

## 定位

- 上游 dartantic_ai 3.4.2（github.com/csells/dartantic_ai）的本地 vendor 镜像，2026-10-06 由提交 `11fc480` 一次性引入（253 文件），此后无代码提交。
- 本地定制仅 3 处（[CUSTOMIZATION.md](../CUSTOMIZATION.md)）：
  1. `lib/src/providers/anthropic_provider.dart:26,49-55` — `AnthropicProvider` 开放 `Uri? baseUrl`，`_normalizeBaseUrl` 去掉尾部斜杠与 `/v1` 段（使 `https://open.bigmodel.cn/api/anthropic` 等 Anthropic 兼容端点可用）。
  2. `example/pubspec.yaml` — 改 `path: ../` 引用本地包。
  3. `test/anthropic_custom_base_url_test.dart` — 本地新增，假服务器验证 baseUrl 生效。
- 引入动机：agent_chat 插件把原生 function-calling 循环切到本包的 `Agent`（同一提交改 `lib/plugins/agent_chat/controllers/chat_controller.dart` 与 `test/native_tool_schema_test.dart`）。

## 目录结构（lib/ 共 128 个 .dart）

| 目录 | 文件数 | 职责 |
|------|--------|------|
| `lib/dartantic_ai.dart` | 1 | 唯一入口 barrel |
| `lib/src/agent/` | 10 | Agent 核心：响应累积、model 串解析、ToolExecutor、流式编排（orchestrators/） |
| `lib/src/chat_models/` | 65 | 各厂商 ChatModel：anthropic / cohere / google / mistral / ollama / openai_chat / openai_responses（含 event_handlers/ 8 个）/ xai_responses + Chat 会话类 |
| `lib/src/embeddings_models/` | 17 | 各厂商 EmbeddingsModel + chunk_list |
| `lib/src/media_gen_models/` | 11 | 媒体生成模型（anthropic / google / openai_responses / xai_responses） |
| `lib/src/providers/` | 13 | 9 个厂商 Provider 工厂 + openai_provider_base、chat_orchestrator_provider 等 |
| `lib/src/shared/` | 4 | 跨厂商元数据（thinking、openai_responses 元数据） |
| `lib/src/platform/` | 3 | IO/Web 条件导入 |

根级散文件：`custom_http_client.dart`（覆盖 baseUrl/headers/queryParams）、`retry_http_client.dart`、`mcp_client.dart`、`logging_options.dart`。

## 设计要点

- **抽象外置**：消息/结果/Provider 基类等核心类型全部来自 pub 依赖 `dartantic_interface ^4.0.1`（其中 ChatMessage 族又转出自 `genai_primitives`），本包只做"编排 + 各厂商实现"。
- 消费方仅 2 个文件：`lib/plugins/agent_chat/services/native_tool_agent_service.dart`（主消费，`Agent.forProvider` + `sendStream`，含 DeepSeek 兼容子类 `AppOpenAIProvider`）与 `services/tool_schema_builder.dart`（ToolConfig → dartantic `Tool` JSON Schema）。`agentlib`、`openai` 插件**不**直接依赖本包。
- 应用自有类型 `ToolCallStep` 在 agent_chat 内，不要与本包类型混淆。
