# agentlib · 架构与 API 面

> 所属：packages/agentlib · [返回索引](../CLAUDE.md)

## 定位

纯 Dart 本地包（无 Flutter 依赖，v1.1.0，仅依赖 `http ^1.3.0`）：**OpenAI 兼容传输门面**。Agent 编排留在 App 内，本包只管传输——HTTP POST `/chat/completions` 一次性补全与 SSE 流式（`stream:true` + LineSplitter 解析 `data:` 行与 `[DONE]`）。无 WebSocket、无轮询。另有通用 `requestJson` 调任意 path。

## 公开 API

| 文件 | 导出 |
|------|------|
| agentlib.dart | `AgentLibClient`（requestJson/complete/stream）、`AgentLibException` |
| chat_models.dart | `ChatCompletionMessage`（system/user/assistant 工厂）+ 多模态 content parts（text/image/audio/refusal）、`ChatCompletionModel`、`CreateChatCompletionRequest`、`JsonSchemaObject`、`ResponseFormat`（text/json_object/json_schema） |
| agent_slots.dart | `AgentResourceItem`（可勾选资源条目）、`AgentResourceSlots`（全局与 per-agent 的 skills + mcpServers 槽位）——agent 市场/资源商店数据模型 |
| openai_compat.dart | 纯 re-export chat_models.dart（兼容旧导入路径） |

## 消费方（lib/ 内 20 处导入）

- **openai 插件**（主消费方）：RequestService（请求发送）、chat_aliveness_channel（上下文组装）、proactive_service、ai_agent 模型、agent 资源服务（agent_slots）、若干 screens/widgets。
- **agent_chat 插件**：agent_chain_executor / ai_request_handler / template_executor / tool_orchestrator（经 openai_compat）+ message_input（agent_slots）。

## 测试

`test/agentlib_client_test.dart`（包内）：MockClient 验证鉴权头与流式解析。
