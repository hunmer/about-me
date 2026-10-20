# 测试与质量

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## 测试现状（2026-10-20 扫描）

| 模块 | 单元测试 | 集成/E2E | 说明 |
|------|----------|----------|------|
| Flutter 应用（`lib/`） | ✅ 34 个测试（`test/`） | 部分 | 顶层 33 个 + `plugins/agent_chat/` 1 个；运行 `flutter test`。构成：活人感/记忆 8（aliveness logic+e2e、memory_extraction×2、agent_thinking_entry、agent_tool_process_view、agent_tool_turn_texts、ai_agent_version）、design_system 5（bridge/gallery/input smoke、stroke_edge_probe、adaptive_image_svg）、live2d/jelly 4（crop/interaction/layout/online_models）、学习与笔记 UI 4（learning_ui_cards、study_dashboard_cards、cute_notepad_edit/editor_title）、agent_chat 工具 4（plugin_tool_registry、native_tool_schema、native_fc_e2e、plugins/agent_chat 实例）、通用组件 4（bottom_bar_position、smooth_bottom_sheet_form、super_navbar_focus_safearea、chat_message_bubble_entrance）、moments_nyc_map_demo、calendar_api_params、http_storage、media_log_model、startup_navigation_stack |
| aboutme_data_sdk | ✅ 7 个文件（README 称 42 测试） | ❌ 无 | aboutme_data / auth_store / data_store / http_storage / jwt_hs256 / local_file_storage / pbkdf2_compat；`dart test` |
| aboutme_server | ✅ 4 个文件（README 称 29 测试） | 部分 | remote / fcm / plugin_mcp / server_integration；`dart test` |
| dartantic_ai（vendor） | ✅ 67+1 个（上游全量 + 本地 baseUrl 测试） | 部分 | `dart test` 可离线跑本地定制测试 |
| agentlib | ✅ `test/agentlib_client_test.dart` | ❌ 无 | MockClient 验证鉴权头与流式解析 |
| server-nodejs（已删除） | — | — | 2026-10-14 目录彻底删除，jest/supertest 随之移除 |

## 质量工具

- Flutter：`flutter analyze`（`analysis_options.yaml`，flutter_lints ^5；注意 `use_build_context_synchronously`、`avoid_print`、`invalid_use_of_protected_member` 等规则被降级/忽略）。
- Dart 子包：各自 `dart analyze` / `dart test`。
- CI（`.github/workflows/`）只做**构建**验证（android/ios/windows/macos/web），不含测试步骤。

## 质量风险与建议

1. **硬编码 API Key**：`lib/plugins/openai/aliveness/services/aliveness_store.dart:11-12`（默认 Jev Key）与 `test/aliveness_e2e_test.dart:15-17`（真实 Jev + DeepSeek Key）——开源或分发前必须移除。
2. `lib/core/services/encryption_service.dart` 已删除（2026-10-12），但 `storage_backend_config` 中仍有 encryption 字样残留；同步现为明文，排查存储问题时勿再找加密层。
3. `radial_disc_bottom_bar/build/` 编译产物被误提交进 git；`skills/moe-ui-skill` 为无 .gitmodules 的 gitlink。
4. `analysis_options.yaml` 忽略了多条常见错误规则，`BuildContext` 跨 async 使用等隐患不会被分析器拦截。
5. 客户端测试覆盖自 2026-10-14 的 17 个增至 34 个（新增集中在 agent 工具调用、学习/笔记 UI、通用组件、moments 地图 demo），但核心层（PluginManager、StorageManager、ConfigManager）仍缺测试，建议优先补。
6. 多个平台目录（android/ios/macos 等）为生成的宿主工程，改动需谨慎且难以自动验证。
