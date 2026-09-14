# 数据模型

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## 客户端本地存储

- `lib/core/storage/`（`StorageManager`）：跨平台文件存储抽象——移动/桌面走 IO 文件，Web 走 IndexedDB；数据以 JSON 文件为主。
- `lib/core/config_manager.dart`：应用级配置（locale、主题等）+ 插件级配置，基于 `shared_preferences`。
- 各插件数据由自身 Service/Controller 管理，目录约定见各插件文档；跨端统一 CRUD 形态由 `shared_models` 约束。

## 共享模型（`shared_models/`，客户端与服务端共用）

- `lib/repositories/<plugin>/`：20 个插件域的 Repository **抽象接口**（chat、notes、todo、bill、activity、goods、diary、checkin、day、tracker、database、calendar、calendar_album、contact、habits、nodes、openai、store、timer、agent_chat）。
- `lib/usecases/<plugin>/`：与 Repository 对应的业务用例层（UseCase 架构，迁移指南见 `docs/USECASE_MIGRATION_GUIDE.md`）。
- `lib/sync/`：同步协议模型 `sync_request.dart` / `sync_response.dart`。
- `lib/auth/`：认证模型。
- `lib/utils/`：`pagination`（分页参数）、`validation`、`result`（统一结果类型）、`md5_utils`、`iterable_extensions`。
- 序列化：`json_annotation` + `json_serializable`（`build_runner` 生成）。

## 同步模型

- 远程通道统一为自建 `server-nodejs` 的 HTTP 存储后端（`lib/core/storage/http_storage.dart` + `storage_backend_config.dart`）；**WebDAV 通道与 `webdav_client` 依赖已移除**。
- 各插件域同步器：`lib/core/services/sync/*_syncer.dart`（activity、agent_chat、bill、calendar、calendar_album、chat、checkin、contact、database、day、diary、goods、habits、nodes、notes、openai、plugin_widget、store、timer、todo、tracker 等 23 个）。
- 端到端加密：客户端 `encrypt`（AES-256-GCM）↔ 服务端 `encryptionService.ts`；API Key（`mk_live_` 前缀）用于第三方/MCP 访问。
- 实时同步：服务端 `FileWatcherService`（chokidar）监听 data 目录变更 → `WebSocketManager` 推送。

## 服务端存储（`packages/server-nodejs`）

- **纯文件存储、无数据库**：全部数据在 `DATA_DIR`（默认 `./data`）下的目录结构中（用户、令牌、API Key、插件数据、已安装服务端插件）。
- 服务端插件：`plugins/` 目录 + `plugin-store.json`（插件商店清单），支持 ZIP 安装与 before/after 钩子。

## 事件与消息

- 客户端：`lib/core/event/` 全局事件总线（插件间解耦通信），用法见 `docs/event.md`。
- 服务端：`services/eventEmitter.ts` + hookable 钩子。
- 推送：FCM（客户端 `fcm_service.dart`，服务端 `fcmService.ts`）。
