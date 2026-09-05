# 测试与质量

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## 测试现状（2026-09-05 扫描）

| 模块 | 单元测试 | 集成/E2E | 说明 |
|------|----------|----------|------|
| Flutter 应用（`lib/`） | ⚠️ 3 个冒烟测试（`test/`） | ❌ 无 | `design_system_bridge_smoke_test.dart`（CustomBottomBar + DS 主题桥 + home_grid）、`jelly_live2d_crop_region_test.dart`、`live2d_online_models_test.dart`；运行 `flutter test` |
| server-nodejs | ✅ jest | ✅ supertest 接口测试 | `tests/api.test.ts` + `globalSetup/globalTeardown`（`npm test`，`--runInBand` 串行执行） |
| mcp-aboutme-server | ❌ 无 | ❌ 无 | 提供 `npm run inspector`（MCP Inspector）手动调试 |
| api_forwarding_server | ❌ 无 | ❌ 无 | — |

## 质量工具

- Flutter：`flutter analyze`（`analysis_options.yaml`，flutter_lints ^5；注意 `use_build_context_synchronously`、`avoid_print`、`invalid_use_of_protected_member` 等规则被降级/忽略）。
- server-nodejs：`npm run lint`（eslint，仅覆盖 `src/**/*.ts`）、`npm run test:coverage`。
- TypeScript 编译本身作为类型检查（`tsc`）。
- CI（`.github/workflows/`）只做**构建**验证（android/ios/windows/macos/web），不含测试步骤。

## 质量风险与建议

1. 客户端仅 3 个冒烟测试（design_system 桥、live2d 相关）：建议优先补核心层（PluginManager、StorageManager、ConfigManager），其次插件 Service 层，最后 UI。
2. `analysis_options.yaml` 忽略了多条常见错误规则，`BuildContext` 跨 async 使用等隐患不会被分析器拦截。
3. server-nodejs 测试串行（`--runInBand`）且集中在 `api.test.ts`，覆盖率依赖 `npm run test:coverage` 输出确认。
4. 多个平台目录（android/ios/macos 等）为生成的宿主工程，改动需谨慎且难以自动验证。
