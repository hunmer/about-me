# 数据模型

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## 客户端本地存储

- `lib/core/storage/`（`StorageManager`）：跨平台文件存储抽象——移动/桌面走 IO 文件，Web 走 IndexedDB；数据以 JSON 文件为主（底层已由 `aboutme_data_sdk` 承担）。
- `lib/core/data/aboutme_data_service.dart`：**全局数据入口（2026-10 新增）**，基于 `packages/aboutme_data_sdk` 的本地/远程自动路由；media_log、贴图、AI 线程、脚本执行日志等新代码统一走它。
- `lib/core/config_manager.dart`：应用级配置（locale、主题等）+ 插件级配置，基于 `shared_preferences`。
- 各插件数据由自身 Service/Controller 管理，目录约定见各插件文档；跨端统一 CRUD 形态由 `shared_models` 约束。

## 共享模型（`shared_models/`，客户端与服务端共用）

- `lib/repositories/<plugin>/`：20 个插件域的 Repository **抽象接口**（chat、notes、todo、bill、activity、goods、diary、checkin、day、tracker、database、calendar、calendar_album、contact、habits、nodes、openai、store、timer、agent_chat）。
- `lib/usecases/<plugin>/`：与 Repository 对应的业务用例层（UseCase 架构，迁移指南见 `docs/USECASE_MIGRATION_GUIDE.md`）。
- `lib/sync/`：同步协议模型 `sync_request.dart` / `sync_response.dart`。
- `lib/auth/`：认证模型。
- `lib/utils/`：`pagination`（分页参数）、`validation`、`result`（统一结果类型）、`md5_utils`、`iterable_extensions`。
- 序列化：`json_annotation` + `json_serializable`（`build_runner` 生成）。

## 数据 SDK（`packages/aboutme_data_sdk`，2026-10-11 起为数据核心）

- 分层：存储/安全层（`data_store.dart`、`http_storage.dart` 明文+条件写、`local_file_storage.dart`、`storage_interface.dart`、`auth_store.dart`、`jwt_hs256.dart`、`pbkdf2.dart`——后两者保留与旧 nodejs 服务器的认证兼容）→ 服务层（`aboutme_data.dart` 本地/远程自动路由客户端唯一入口、`route_config.dart` 路由表、`crud.dart` 通用 CRUD、`handler_factory.dart`）→ **12 个插件处理器**（`services/handlers/`：activity、bill、calendar、chat、checkin、contact、day、diary、goods、notes、todo、tracker）。
- 客户端、服务器 REST、MCP 共用同一套处理器；**端到端加密已移除，现为明文同步**（客户端 `encryption_service.dart` 已删除，仅 `storage_backend_config` 残留字样）。

## 同步模型

- 远程通道为自建 `aboutme_server`（Dart，默认 8874）的 HTTP 存储后端（`http_storage.dart` + `storage_backend_config.dart`，ETag 条件写）；WebDAV 通道早已移除。
- 旧插件域同步器 `lib/core/services/sync/*_syncer.dart`（23 个）仍在，但新数据链路统一走 AboutmeDataService + data_sdk 处理器（演进中）。
- 实时同步：服务器 `ws_hub.dart` 广播 `file_updated`（WebSocket）。
- API Key（`mk_live_` 前缀）用于第三方/MCP 访问。

## 服务端存储（`packages/aboutme_server`，薄壳）

- 纯文件存储、无数据库：数据在统一数据区目录（用户 `data/auth/users.json`、插件数据、令牌、API Key）；全部业务逻辑来自 aboutme_data_sdk。
- MCP 端点 `/mcp`（Streamable HTTP）：68 个 AI 工具，与 REST 同一套处理器。

## 事件与消息

- 客户端：`lib/core/event/` 全局事件总线（插件间解耦通信，用法见 `docs/event.md`；achievement 插件即事件驱动，消费 41 个信号）。
- 服务器：WS 广播（`ws_hub.dart`）+ FCM 推送（`fcm_service.dart`）。
- 推送：FCM（客户端 `fcm_service.dart` ↔ 服务器 `fcm_service.dart`）。
