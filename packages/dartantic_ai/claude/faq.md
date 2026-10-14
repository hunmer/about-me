# 常见问题

> 所属：packages/dartantic_ai · [返回索引](../CLAUDE.md)

- **Anthropic 兼容端点（如 bigmodel）不通？** 检查 `AnthropicProvider` 的 baseUrl 是否传入；本地定制会去掉尾部 `/v1` 段，SDK 自己追加 `/v1/messages`（`lib/src/providers/anthropic_provider.dart`）。
- **DeepSeek 关不掉 thinking？** 走的是应用侧 `AppOpenAIProvider` + `DeepSeekCompatClient`（agent_chat 内），不是本包；本包 Provider 未暴露 httpClient，这是已知的定制绕行（`native_tool_agent_service.dart:103-152` 注释）。
- **找不到 ChatMessage 定义？** 在 `dartantic_interface` 依赖里，本包只转出。
- **想升级到上游新版？** 按 [CUSTOMIZATION.md](../CUSTOMIZATION.md) 6 步流程，重点是重放 baseUrl 补丁与保留本地测试。
- **`ToolCallStep` 报错？** 它是 agent_chat 的自有类型（`lib/plugins/agent_chat/models/tool_call_step.dart`），不在本包。
