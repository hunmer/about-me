# 依赖与配置

> 所属：packages/dartantic_ai · [返回索引](../CLAUDE.md)

- SDK：`^3.10.0`；version 3.4.2；无配置文件、无环境变量（apiKey/baseUrl 由消费方构造 Provider 时传入）。
- 核心抽象：`dartantic_interface ^4.0.1`（消息/结果/Provider/Tool 全部抽象在此）。
- 厂商 SDK：`anthropic_sdk_dart ^5.0.0`、`googleai_dart ^8.0.0`、`mistralai_dart ^4.0.0`、`ollama_dart ^2.3.0`、`openai_dart ^7.0.0`、`mcp_dart ^2.2.2`。
- 通用：`http`、`logging`、`rxdart`、`sse_channel`、`uuid`、`collection`、`html`、`meta`、`mime`。
- dev：`test`、`all_lint_rules_community`。
- 接线方式：根 `pubspec.yaml` path 依赖 `packages/dartantic_ai`；修改本包后无需 publish，客户端 `flutter pub get` 即生效（agent_chat 是唯一消费方）。
