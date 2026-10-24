# 数据模型

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## 客户端本地存储

- `lib/core/storage/`（`StorageManager`）：跨平台文件存储抽象——移动/桌面走 IO 文件，Web 走 IndexedDB；数据以 JSON 文件为主（底层已由 `aboutme_data_sdk` 承担）。
- `lib/core/data/aboutme_data_service.dart`：**全局数据入口（2026-10 新增）**，基于 `packages/aboutme_data_sdk` 的本地/远程自动路由；media_log、贴图、AI 线程、脚本执行日志等新代码统一走它。**只暴露业务层（call/get 域命令）；原文件层转发 API（readPath/writePath/existsPath/listPathKeys）已于 2026-10-24 第八轮全部删除**，历史等少量只读场景直接用 `data.existsPath` 等直达。
- `lib/core/config_manager.dart`：应用级配置（locale、主题等）+ 插件级配置，基于 `shared_preferences`；落盘 `configs/` 的写入统一走 system 域 config 命令（见下"写封闭策略"）。
- 各插件数据由自身 Service/Controller 管理，目录约定见各插件文档；跨端统一 CRUD 形态由 `shared_models` 约束。

## 共享模型（`shared_models/`，客户端与服务端共用）

- `lib/repositories/<plugin>/`：20 个插件域的 Repository **抽象接口**（chat、notes、todo、bill、activity、goods、diary、checkin、day、tracker、database、calendar、calendar_album、contact、habits、nodes、openai、store、timer、agent_chat）。
- `lib/usecases/<plugin>/`：与 Repository 对应的业务用例层（UseCase 架构，迁移指南见 `docs/USECASE_MIGRATION_GUIDE.md`）。
- `lib/sync/`：同步协议模型 `sync_request.dart` / `sync_response.dart`。
- `lib/auth/`：认证模型。
- `lib/utils/`：`pagination`（分页参数）、`validation`、`result`（统一结果类型）、`md5_utils`、`iterable_extensions`。
- 序列化：`json_annotation` + `json_serializable`（`build_runner` 生成）。

## 数据 SDK（`packages/aboutme_data_sdk`，2026-10-11 起为数据核心）

- 分层：存储/安全层（`data_store.dart`、`http_storage.dart` 明文+条件写、`local_file_storage.dart`、`storage_interface.dart`、`auth_store.dart`、`jwt_hs256.dart`、`pbkdf2.dart`——后两者保留与旧 nodejs 服务器的认证兼容）→ 服务层（`aboutme_data.dart` 本地/远程自动路由客户端唯一入口、`route_config.dart` 路由表、`crud.dart` 通用 CRUD、`handler_factory.dart`、`legacy_write_policy.dart` 写封闭策略）→ **插件处理器**（`services/handlers/` 33 个文件：28 个封闭域各有 handler，timer/achievement/reminder/live2d/tts 共用 `snapshot_domain.dart` 单文件快照模式，另有 `system.dart` 全局配置域、`assets.dart` 资源域、`chat_stickers.dart`、`record_domain_support.dart` / `structured_support.dart` 共享支撑）。
- 客户端、服务器 REST、MCP 共用同一套处理器；**端到端加密已移除，现为明文同步**（客户端 `encryption_service.dart` 已删除，仅 `storage_backend_config` 残留字样）。
- SDK 纯 Dart 零 Flutter 依赖（依赖仅 shared_models/crypto/encrypt/http/path/pointycastle/uuid），宿主 `storage_interface` 转发实现依赖倒置；已评估不拆 flutter 变体包（2026-10-24 结论）。

## 写封闭策略（2026-10-24 八轮重构完成，原始文件写一律 426）

- **28 个迁移封闭域**：diary、todo、tracker、notes、nodes、contact、day、calendar、checkin、habits、bill、goods、store、calendar_album、media_log、database、agent_chat、activity、timer、achievement、reminder、live2d、tts、webview、scripts_center、openai、toolbox、photo_editor（`legacy_write_policy.dart` 的 migratedDomains）。
- **configs/ 前缀同样封闭**（在 `_protectedRoots`）：唯一写入口 = system 域 config 命令——`getConfig {key}` / `setConfig {key, value}` / `deleteConfig {key}`（key 为 configs/ 下相对路径，落盘原位）；REST 对应 `GET/PUT/DELETE /api/v1/plugins/system/config`。Flutter 薄封装在 `AboutmeDataService.instance.getConfig/setConfig/deleteConfig`。
- 顶层裸配置已收编：floating_ball_config / action_config 主配置走 system 命令（key 沿用原文件名），`action_config_backups/` 快照目录留文件层。
- 读 API（readPath/listPathKeys/existsPath 等）不受封闭限制；SDK 各域迁移命令（migrateLegacyAssets / migrateLegacyStickers 等）保留为 dormant（Flutter 已不调用，服务端/管理后台仍依赖）。**旧数据区旧格式引用不再被程序迁移，直接失效**（第八轮用户决策：手动清空旧数据）。
- handler 内部 data.read/write 不受限制；`writeBytes/writeFile/writePath/deletePath/clearPathPrefix` 均受 426 拦截。
- capabilities 暴露 `protectedPrefixes`，admin FilesTab 删除时双检查（域 + 保护前缀）。

## 媒体资源与上传

- 新写二进制走 `SdkMediaService` 存 `asset://`（引用计数）；旧图批量迁移 `migrateLegacyAssets {items:[{sourcePath,fileName?,mediaType?}]}`（白名单 27 域 + stickers 前缀，legacy_migration.json 幂等，迁后删旧，单次 50 项分批）。
- 孤立资源回收：`sweep {dryRun=true, minAgeHours=24}`（引用=0 回收）。
- 分块上传：`initUpload / appendChunk / completeUpload`（8MiB/块、总上限 256MiB、24h 暂存 GC）；Flutter 侧 `AssetsFacade.uploadChunked`（端到端 sha256、onProgress），`SdkMediaService.uploadBytes` >16MiB 自动路由分块。
- chat 贴图旧引用迁移：`migrateLegacyStickers` 命令（dryRun 默认、幂等）+ REST `POST /chat/sticker-collections/migrate-legacy`，由 chat 插件 initialize 幂等触发。

## 同步模型

- 远程通道为自建 `aboutme_server`（Dart，默认 8874）的 HTTP 存储后端（`http_storage.dart` + `storage_backend_config.dart`，ETag 条件写）；WebDAV 通道早已移除。
- 旧插件域同步器 `lib/core/services/sync/*_syncer.dart` 仍在，但数据链路已统一走 AboutmeDataService + data_sdk 处理器（八轮重构 2026-10-24 完成）。
- 实时同步：服务器 `ws_hub.dart` 广播 `file_updated`（WebSocket）。
- API Key（`mk_live_` 前缀）用于第三方/MCP 访问。**服务器业务命令按认证用户隔离落盘 `users/<id>/`**（remote 测试断言路径勿用数据区根）。
- AuthStore 并发写入已治理（2026-10-24）：`verifyApiKey` 回写 lastUsedAt 加进程内互斥锁 + 临时文件原子写；api_keys/users 数据损坏由静默空表改为显式 `StorageException(invalidData)`。

## 服务端存储（`packages/aboutme_server`，薄壳）

- 纯文件存储、无数据库：数据在统一数据区目录（用户 `data/auth/users.json`、插件数据、令牌、API Key）；全部业务逻辑来自 aboutme_data_sdk。
- MCP 端点 `/mcp`（Streamable HTTP）：68 个 AI 工具，与 REST 同一套处理器。

## 事件与消息

- 客户端：`lib/core/event/` 全局事件总线（插件间解耦通信，用法见 `docs/event.md`；achievement 插件即事件驱动，消费 41 个信号）。
- 服务器：WS 广播（`ws_hub.dart`）+ FCM 推送（`fcm_service.dart`）。
- 推送：FCM（客户端 `fcm_service.dart` ↔ 服务器 `fcm_service.dart`）。
