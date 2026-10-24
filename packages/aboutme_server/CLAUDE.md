# aboutme_server

Aboutme 的**同步服务器**（Dart 薄壳，lib 仅 15 文件约 2650 行）：所有数据业务逻辑来自 [`aboutme_data_sdk`](../aboutme_data_sdk/CLAUDE.md)，本包只做 HTTP 路由、认证、WS 广播、FCM 推送与静态托管。提供存储文件 API（ETag 条件写）、插件业务 REST、MCP 端点（AI 工具）与 Vue 管理界面托管；数据明文存于统一数据区 `DATA_DIR/users/{userId}/{pluginId}/{file}.json`（按认证用户隔离）。含 `admin-vue/` 管理前端源码与 Docker 部署（version tag 触发 CI 镜像构建）。

## 约定的规则

- 本地开发 `procm-command start server`（仓库根 procm-commands.json；即 `dart run bin/server.dart`，cwd 本包）；默认端口 **8874**，数据区默认 `./data`（`DATA_DIR` 覆盖）。
- 质量门槛：`dart analyze` + `dart test`（**38 项全过**，6 个测试文件）；管理前端 `cd admin-vue && npx vue-tsc -b`。
- 改 SDK（aboutme_data_sdk）后需重新构建 SDK 并在本包重新 install（path 依赖）。
- 生产部署走 Docker（`docker compose up -d --build`，本机映射 127.0.0.1:8874；必须设强随机 `JWT_SECRET` 与 `ADMIN_PASSWORD`）；admin 构建产物输出 `../admin/` 由服务器托管于 `/admin/`。
- README 中"19 插件 API / 29 测试 / 68 工具"等数字为历史快照，以本索引为准（现 28+ 域 REST、38 项测试、mcp/tools.dart 为工具事实源）。
- 服务器业务命令按认证用户隔离落盘 `users/<id>/`——写测试断言时勿用数据区根路径。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 薄壳定位、请求拓扑、用户隔离 | 第一次接手本包 |
| [开发约定](claude/conventions.md) | 运行/Docker/admin 构建命令 | 部署、起服务 |
| [模块职责](claude/module-responsibilities.md) | 15 个 lib 文件职责速查 | 定位路由/中间件 |
| [入口与启动](claude/entrypoints.md) | bin/server.dart 启动链、Dockerfile、CI | 改启动/部署 |
| [对外接口](claude/public-interfaces.md) | 全部端点、MCP、WS 协议 | 对接客户端/外部工具 |
| [依赖与配置](claude/dependencies-and-config.md) | shelf 系依赖、ServerConfig 环境变量全表 | 改配置 |
| [数据模型](claude/data-model.md) | 数据区布局、auth 数据、审计 | 排查数据落盘 |
| [测试与质量](claude/testing-and-quality.md) | 6 测试文件构成与注意事项 | 补测试 |
| [文件地图](claude/file-map.md) | 目录速查（含 admin-vue） | 找文件 |
| [索引变更记录](claude/changelog.md) | 本文档体系更新历史 | 重复运行 /init-project 时 |

> 常见问题见仓库根 [claude/faq.md](../../claude/faq.md)，本包不单独维护 FAQ。

## 扫描状态

- 更新时间：2026-10-25（首次建档，/init-project 后续优化轮）：15 个 lib 文件全量、config.dart 环境变量、bin/ 与 Dockerfile/docker-compose、6 个测试文件、admin-vue 归属核实。
- 未深扫：admin-vue 前端源码细节（Vue3 组件结构）、mcp/tools.dart 逐工具清单（83 处 name 定义未逐个核对）、debug/ 静态页。
