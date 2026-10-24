# 测试与质量

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## 测试现状（2026-10-25 扫描）

| 模块 | 单元测试 | 集成/E2E | 说明 |
|------|----------|----------|------|
| Flutter 应用（`lib/`） | ✅ 73 个测试文件（`test/`） | 部分 | 顶层 72 个 + `plugins/agent_chat/` 1 个；运行 `flutter test`。2026-10-24 数据 SDK 八轮重构新增大量 `*_tool_regression_test`（bill/calendar_album/day/goods/habits/store/timer/todo/tracker/checkin_display 等域工具回归）、plugin_manager_config_save、system 相关；另有 mobile_js_engine、deepseek_thinking_transport、thinking_config、suggested_question、nodes/notes 分页等（2026-10-20 时为 34 个） |
| aboutme_data_sdk | ✅ 42 个测试文件（**214 项全过**，2026-10-24 基线） | 部分（aboutme_data_remote_test 真实 Shelf 端到端） | 覆盖各域 contract/business/migration、assets 迁移与分块上传、system config 演练、命令运行时、自检；`dart test --concurrency=1` |
| aboutme_server | ✅ 6 个测试文件（**38 项全过**，2026-10-24 基线） | 部分 | remote / business_request_body / fcm / plugin_mcp / server_integration / system_config_migration；`dart test` |
| admin-vue | 类型检查 | — | `npx vue-tsc -b`（packages/aboutme_server/admin-vue） |
| dartantic_ai（vendor） | ✅ 67+1 个（上游全量 + 本地 baseUrl 测试） | 部分 | `dart test` 可离线跑本地定制测试 |
| agentlib | ✅ `test/agentlib_client_test.dart` | ❌ 无 | MockClient 验证鉴权头与流式解析 |

## 质量工具

- Flutter：`flutter analyze`（`analysis_options.yaml`，flutter_lints ^5；注意 `use_build_context_synchronously`、`avoid_print`、`invalid_use_of_protected_member` 等规则被降级/忽略）。2026-10-24 基线：`flutter analyze lib` 无 error（14 项历史 lint）。
- Dart 子包：各自 `dart analyze` / `dart test`；SDK `dart analyze` 须无 issue。
- CI（`.github/workflows/`）：5 平台**构建**验证 + `aboutme server docker image`（version tag 触发，镜像内构建 admin 资产）+ 全部 workflow 跟随 main 推送运行；不含 Flutter 测试步骤。
- 测试注入约定：构造损坏/遗留数据用磁盘 File 直写注入（照 `packages/aboutme_data_sdk/test/checkin_migration_test.dart` 的 inject 模式）。

## 质量风险与建议

1. **硬编码 API Key**：`lib/plugins/openai/aliveness/services/aliveness_store.dart:11-12`（默认 Jev Key）与 `test/aliveness_e2e_test.dart:15-17`（真实 Jev + DeepSeek Key）——开源或分发前必须移除。
2. `lib/core/services/encryption_service.dart` 已删除（2026-10-12），但 `storage_backend_config` 中仍有 encryption 字样残留；同步现为明文，排查存储问题时勿再找加密层。
3. `radial_disc_bottom_bar/build/` 编译产物被误提交进 git；`skills/moe-ui-skill` 为无 .gitmodules 的 gitlink。
4. `analysis_options.yaml` 忽略了多条常见错误规则，`BuildContext` 跨 async 使用等隐患不会被分析器拦截。
5. 客户端测试覆盖自 2026-10-20 的 34 个增至 73 个（SDK 八轮重构带来大量域工具回归测试），核心层（StorageManager、ConfigManager）仍缺直接测试，建议优先补。
6. 多个平台目录（android/ios/macos 等）为生成的宿主工程，改动需谨慎且难以自动验证。
