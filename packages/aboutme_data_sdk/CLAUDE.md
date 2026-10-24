# aboutme_data_sdk

Aboutme 的**纯数据 SDK**（纯 Dart，零 Flutter 依赖，lib 约 14900 行）：客户端本地模式、服务器 REST、MCP 三条通路共用同一套业务处理器；数据明文存于统一数据区（本地 `{rootDir}/{pluginId}/{file}.json`，服务端 `users/{id}/{pluginId}/...`）。2026-10-24 八轮重构完成：28 个迁移域 + `configs/` 前缀写封闭（原始文件写 426），system 域 config 命令是 configs 唯一写入口，二进制媒体资源化（`asset://` + 分块上传）。`AboutmeData.local / .remote` 是客户端唯一入口，本地/远程调用方代码完全一致。

## 约定的规则

- 测试必须 `dart test --concurrency=1`（基线 **214 项全过**，42 个测试文件）；`dart analyze` 须无 issue。
- **共享文件是多 agent 冲突点**：`route_config.dart`（各域段，静态路由先于参数路由）、`handler_factory.dart`（各域 case）、`legacy_write_policy.dart`（migratedDomains）——并行改动勿同时碰这三个文件。
- 新增域 handler：`PUT /xxx/:id` 类路由必须从 params 取同名路径参数键；某域 Flutter 侧零残留直写后才能加进 migratedDomains，加完跑全量测试。
- `data.get/call` 返回 `{success, data, error, code}`，取值先判 success；事务内 read 抛 StorageException 会被提交层重放，handler 内 catch 无效。
- SDK 保持零 Flutter 依赖（纯 Dart；已评估不拆 flutter 变体包）；客户端经宿主 `storage_interface` 转发实现依赖倒置。
- README 中"12 插件处理器 / 41 测试"等数字为历史快照，以本索引为准（现 33 个 handler 文件 / 214 项测试）。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 分层、三条通路、写封闭设计 | 第一次接手本包 |
| [开发约定](claude/conventions.md) | 测试/分析命令、handler 编写规则、迁移模式 | 写 handler 之前 |
| [模块职责](claude/module-responsibilities.md) | 各层文件职责 + 33 handler 分组清单 | 定位某域实现 |
| [入口与导出](claude/entrypoints.md) | aboutme_data_sdk.dart / io.dart 双入口导出面 | 查公开 API |
| [对外接口](claude/public-interfaces.md) | AboutmeData API、三个 Facade、资源/上传命令 | 客户端/服务端对接 |
| [依赖与配置](claude/dependencies-and-config.md) | pubspec 依赖、data_config/storage_config | 升级依赖、改配置 |
| [数据模型](claude/data-model.md) | 统一数据区布局、事务、asset://、幂等记录 | 改数据结构 |
| [测试与质量](claude/testing-and-quality.md) | 42 测试文件分组、inject 注入模式 | 补测试 |
| [文件地图](claude/file-map.md) | 目录速查 | 找文件 |
| [索引变更记录](claude/changelog.md) | 本文档体系更新历史 | 重复运行 /init-project 时 |

> 常见问题（426 写封闭、迁移命令、文件层 API 去向）见仓库根 [claude/faq.md](../../claude/faq.md)，本包不单独维护 FAQ。

## 扫描状态

- 更新时间：2026-10-25（首次建档，/init-project 后续优化轮）：全量源码树（69 个 lib 文件）、双入口导出面、pubspec、42 个测试文件清单、handoff（2026-10-24 第八轮）交叉核实。
- 未深扫：各 handler 内部命令级语义（以各域 `*_test.dart` 为准）、`templates/` 示例内容。
