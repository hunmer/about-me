# 测试与质量

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## 测试现状（2026-10-05 扫描）

| 模块 | 单元测试 | 集成/E2E | 说明 |
|------|----------|----------|------|
| Flutter 应用（`lib/`） | ⚠️ 8 个测试（`test/`） | ❌ 无 | `aliveness_logic_test.dart`（591 行 9 组：配置/拆条/状态机/记忆激活/问题池/日程/导入解析）、`aliveness_e2e_test.dart`（真实 API 验收）、`design_system_bridge_smoke_test.dart`、`design_system_input_test.dart`、`http_storage_test.dart`、`jelly_live2d_crop_region_test.dart`、`live2d_online_models_test.dart`、`plugins/agent_chat/agent_chat_plugin_instance_test.dart`；运行 `flutter test` |
| agentlib | ✅ `test/agentlib_client_test.dart` | ❌ 无 | MockClient 验证鉴权头与流式解析（`dart test`） |
| server-nodejs | ✅ jest | ✅ supertest 接口测试 | `tests/api.test.ts` + `globalSetup/globalTeardown`（`npm test`，`--runInBand` 串行执行） |
| server-nodejs (MCP) | ✅ `tests/mcp.test.ts` | ❌ 无 | 可用 MCP Inspector 连接 `http://localhost:8874/mcp` 手动调试 |

## 质量工具

- Flutter：`flutter analyze`（`analysis_options.yaml`，flutter_lints ^5；注意 `use_build_context_synchronously`、`avoid_print`、`invalid_use_of_protected_member` 等规则被降级/忽略）。
- server-nodejs：`npm run lint`（eslint，仅覆盖 `src/**/*.ts`）、`npm run test:coverage`。
- TypeScript 编译本身作为类型检查（`tsc`）。
- CI（`.github/workflows/`）只做**构建**验证（android/ios/windows/macos/web），不含测试步骤。

## 质量风险与建议

1. **硬编码 API Key**：`lib/plugins/openai/aliveness/services/aliveness_store.dart:11-12`（默认 Jev Key）与 `test/aliveness_e2e_test.dart:15-17`（真实 Jev + DeepSeek Key）——开源或分发前必须移除。
2. 客户端仅 8 个测试（活人感占 2、design_system 2、http_storage 1、live2d 2、agent_chat 1）：建议优先补核心层（PluginManager、StorageManager、ConfigManager），其次插件 Service 层，最后 UI。
3. `analysis_options.yaml` 忽略了多条常见错误规则，`BuildContext` 跨 async 使用等隐患不会被分析器拦截。
4. server-nodejs 测试串行（`--runInBand`）且集中在 `api.test.ts`，覆盖率依赖 `npm run test:coverage` 输出确认；storageWebSocketService（2026-09-15 新增）尚无专门测试。
5. 多个平台目录（android/ios/macos 等）为生成的宿主工程，改动需谨慎且难以自动验证。
