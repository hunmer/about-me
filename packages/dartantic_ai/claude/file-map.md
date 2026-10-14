# 文件地图

> 所属：packages/dartantic_ai · [返回索引](../CLAUDE.md)

| 路径 | 说明 |
|------|------|
| `CUSTOMIZATION.md` | **本地定制清单 + 同步上游 6 步流程**（改包前必读） |
| `lib/dartantic_ai.dart` | 入口 barrel |
| `lib/src/agent/agent.dart` | Agent 类（send/sendFor/sendStream/generateMedia/embed*） |
| `lib/src/agent/tool_executor.dart` | 工具执行器 |
| `lib/src/agent/orchestrators/` | 流式编排器 |
| `lib/src/providers/anthropic_provider.dart` | 含本地 baseUrl 定制（仅此一处源码定制） |
| `lib/src/chat_models/` | 65 个文件：各厂商 ChatModel（openai_responses 含 event_handlers/） |
| `lib/src/embeddings_models/` · `media_gen_models/` | embeddings / 媒体生成 |
| `lib/src/mcp_client.dart` · `custom_http_client.dart` · `retry_http_client.dart` | MCP 连接与 HTTP 包装 |
| `test/anthropic_custom_base_url_test.dart` | 本地新增的 baseUrl 回归测试 |
| `example/`（37 个示例）· `run_all_examples.sh` | 上游示例，可批量跑 |
| `README.md` · `CHANGELOG.md` | 上游文档（1152 行 changelog，最新 3.4.2） |
