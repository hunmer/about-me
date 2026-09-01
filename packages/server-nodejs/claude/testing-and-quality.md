# 测试与质量

> 所属：packages/server-nodejs · [返回索引](../CLAUDE.md)

## 测试设置

- 框架：jest + ts-jest + supertest（`jest.config.js`）。
- 入口：`tests/api.test.ts`；配套 `globalSetup.ts` / `globalTeardown.ts`（起停测试环境、准备 `tests/test_data/`）。
- 执行：`npm test`（`--runInBand` 串行——测试触碰文件系统状态，并行会互踩）；覆盖率 `npm run test:coverage`。

## 覆盖情况（2026-09 扫描）

- 仅一个聚合测试文件 `api.test.ts`，聚焦 API 层；services 层单测与 handler 级用例未见。
- 建议新增 handler 时同步补 supertest 用例（工厂路由模式下成本低）。

## 静态检查

- `npm run lint`（eslint，仅 `src/**/*.ts`）。
- `tsc` 编译即类型检查；admin-vue 侧由 `vue-tsc -b` 把关。

## 风险

- 测试依赖真实文件系统与全局 setup，本地跑测试前确认 `data/` 不含生产数据（测试目录独立为 `tests/test_data/`，但串行执行仍建议干净环境）。
- 无 CI 步骤跑本包测试（根 `.github/workflows/` 只构建 Flutter 应用）。
