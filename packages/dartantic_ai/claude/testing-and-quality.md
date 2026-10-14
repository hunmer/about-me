# 测试与质量

> 所属：packages/dartantic_ai · [返回索引](../CLAUDE.md)

- test/ 共 67 个 .dart（+ test/files/ 3 个素材），全部来自上游，本地新增 1 个：`anthropic_custom_base_url_test.dart`（本地 HTTP/SSE 假服务器，验证请求确实打到配置的 baseUrl，无网络依赖）。
- 主题聚类：Agent 配置/编排、消息模型、工具调用（tool_calling 792 行、tool_id_coordination）、typed output（997 行）、流式、thinking、多模态、多 Provider、embeddings、媒体生成 e2e、服务端工具 e2e、系统级集成（725 行）、异常边界。
- 子目录：`chat_models/`(6)、`openai_responses/`(6)、`providers/`(1)、`media_gen_models/`(1)、`test_helpers/`(1)。
- 跑法：包内 `dart test`（本地 baseUrl 测试可离线跑）；同步上游后必跑 `dart test` + 客户端 `flutter analyze`。
- 应用侧配套测试：根 `test/native_tool_schema_test.dart`（schema builder）、`test/native_fc_e2e_test.dart`（原生工具调用 e2e）。
