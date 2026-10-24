# 架构总览

> 所属：packages/aboutme_data_sdk · [返回索引](../CLAUDE.md)

## 定位

**所有数据业务逻辑的唯一所在地**。客户端（本地模式零网络）、aboutme_server（REST/MCP）都只是这个 SDK 的宿主；改数据行为只改这里，三条通路同时生效。

```
┌────────────────────────────────────────────┐
│           aboutme_data_sdk                  │
│  文件层: readFile / writeFile（受 426 封闭） │
│  业务层: 33 个 handler 文件（28 域 + 支撑） │
│  AboutmeData: local | remote 自动路由       │
└──────┬─────────────────────┬───────────────┘
       │ 本机直处理           │ REST
┌──────▼──────┐   ┌──────────▼──────────────┐
│ 客户端本地    │   │ aboutme_server           │
│ app_data/    │   │ users/{id}/{plugin}/     │
└─────────────┘   └─────────────────────────┘
```

## 分层

1. **存储/安全层**（`lib/src/`）：`storage_interface.dart`（抽象，宿主转发点）、`data_store.dart`、`local_file_storage.dart`（服务端文件存储）、`http_storage.dart`（远端后端，明文 + ETag 条件写）、`auth_store.dart`、`jwt_hs256.dart`、`pbkdf2.dart`（后两者保留 nodejs 认证兼容）、`legacy_write_policy.dart`（426 写封闭）、`storage_errors.dart`、`storage_config.dart`。
2. **服务层**（`lib/src/services/`）：`aboutme_data.dart`（客户端唯一入口）、`route_config.dart`（路由表）、`invoker.dart` / `handler_factory.dart` / `crud.dart` / `query_store.dart` / `types.dart` / `utils.dart`、各 Facade（chat / diary / assets）、`capabilities.dart`、`plugin_data.dart` / `*_plugin_backend.dart`（本地/持久后端）、`asset_*`（资源化管线）、`data_config.dart`、`host_file_input*`（宿主文件 IO 注入）。
3. **业务处理器**（`lib/src/services/handlers/`）：33 个文件（见 [模块职责](module-responsibilities.md)）。
4. **迁移**（`lib/src/services/migrations/`）：record_domains / diary / notes_nodes——保留为 dormant（服务端/管理后台依赖，Flutter 已不调用）。

## 关键设计取舍

- **写封闭（2026-10-24 八轮完成）**：28 域 + configs/ 前缀的原始写（writePath/writeFile/writeBytes/deletePath/clearPathPrefix）一律 426；读 API 不受限。目的：所有写入经业务命令，保证校验/快照/引用计数。
- **明文**：端到端加密已随 SDK 化移除；认证兼容（JWT/PBKDF2/API Key）保留。
- **零 Flutter 依赖 + 依赖倒置**：SDK 纯 Dart；宿主实现 `StorageInterface` 注入（`host_file_input*` / `asset_materialization*` 的 io/stub 条件导入），实现"SDK 契约 + 宿主实现"。
- **不拆 flutter 变体包**（2026-10-24 评估结论）：物理拆包无架构收益，仅结构搬家。
- **旧数据失效策略（第八轮用户决策）**：Flutter 侧迁移兼容层全删，旧数据区旧格式引用不再被程序迁移、直接失效；SDK 迁移命令保留 dormant 供服务端/管理后台使用。
