# HTTP 可选存储后端实施计划

## 1. 目标与边界

### 目标

- 保留当前本地文件存储作为默认后端，现有用户无需迁移即可继续使用。
- 新增可选的 HTTP 存储后端，客户端通过 `packages/server-nodejs` 的 REST API 读写同一份用户数据。
- 多个 About Me 客户端配置同一个服务器账号后，直接共享服务端数据，不再依赖客户端之间的文件同步。
- 删除已经失去职责的 API forwarding WebSocket 代理实现。

### 非目标

- 本阶段不在 Flutter 客户端内启动 Dart HTTP 服务。
- 不把 HTTP 后端强制为默认模式。
- 不把旧的 WebDAV 或 `/api/v1/sync` 文件同步协议直接改名后复用。
- 不把日志、临时目录、下载缓存、WebView 解压目录等运行时文件自动变成远端数据。

## 2. 现状与约束

- 业务数据大部分通过 `StorageManager -> StorageInterface` 访问。
- `MobileStorage` 和 `WebStorage` 负责当前本地持久化。
- `StorageManager` 当前硬编码选择存储实现，并有仅进程内的 `_cache`；远端模式必须支持依赖注入并禁用会造成跨客户端陈旧数据的缓存。
- `server-nodejs` 已有 JWT/API Key 认证、按用户隔离的数据目录和文件索引。
- `server-nodejs` 当前 `/api/v1/sync` 保存的是加密文件封装（`encrypted_data/md5/is_binary`），不等同于透明的字节 CRUD。
- 多处代码仍直接访问 `app_data` 下的 `File`/`Directory`，这些调用不会自动经过新的 HTTP 后端。

## 3. 目标架构

```text
业务代码
  -> StorageManager
  -> LocalStorage（默认）或 HttpStorage（可选）

HttpStorage
  -> /api/v1/storage/*
  -> server-nodejs 认证中间件
  -> 用户数据目录
```

新增 `StorageBackendConfig`，配置保存在本地 `SharedPreferences`（服务器地址、认证方式、Token/API Key、用户标识、启用状态）。数据源配置不能保存在远端数据目录内，否则启动时无法确定远端地址。

`StorageManager` 在初始化阶段读取配置并创建后端；配置切换后重新初始化全局存储，禁止同一进程同时对两个后端写入。

## 4. REST API 契约

建议新增 `/api/v1/storage` 路由，统一使用认证中间件：

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| `GET` | `/api/v1/storage/files/{path}` | 返回原始字节；不存在返回 `404` |
| `PUT` | `/api/v1/storage/files/{path}` | 全量覆盖，支持文本和二进制 |
| `HEAD` | `/api/v1/storage/files/{path}` | 判断存在并返回 `ETag`、大小和修改时间 |
| `DELETE` | `/api/v1/storage/files/{path}` | 删除单文件 |
| `GET` | `/api/v1/storage/files?prefix=...` | 返回相对路径列表 |
| `DELETE` | `/api/v1/storage/files?prefix=...` | 清除前缀下的文件 |
| `GET` | `/api/v1/storage/health` | 认证后的数据源连通性检查 |

实现要求：

- 统一使用正斜杠相对路径，拒绝绝对路径、`..`、空路径和符号链接逃逸。
- 路径解析后必须再次确认结果位于当前用户目录内。
- 写入采用临时文件加原子替换，索引更新与文件写入保持一致。
- `PUT` 支持 `If-Match`；版本冲突返回 `412`，不能静默覆盖其他客户端的更新。
- 新文件支持 `If-None-Match: *`，删除也支持条件版本校验。
- 明确响应 `Content-Type`、`Content-Length`、`ETag`、`Last-Modified`。
- 服务端不保存明文。客户端在 HTTP 传输前使用现有加密服务加密，服务端只保存不可解析的密文、版本和必要元信息；HTTPS 仍然是必需的传输层保护。
- 强制覆盖使用显式 `X-Force-Overwrite: true`（或等价的专用参数），仅在用户确认/管理操作中发送，并记录审计日志；普通 `PUT` 仍必须校验 `If-Match`。

## 5. 客户端改造

### 5.1 存储抽象

- 新增 `HttpStorage implements StorageInterface`，复用现有 `http` 包。
- 将 `StorageManager` 的后端选择改为构造注入或工厂创建。
- HTTP 读取按字节实现，字符串接口负责 UTF-8 编解码，JSON 接口负责序列化/解析。
- `createDirectory` 在 HTTP 后端中作为幂等空操作，目录由文件路径隐式创建。
- 移除或绕过 `StorageManager._cache`，确保远端变更可见；本地后端如需性能缓存需有明确失效规则。
- 为网络超时、401/403、404、409/412、5xx 和离线状态定义统一异常类型。

### 5.2 配置与设置

- 新增“数据存储后端”设置：本地文件 / HTTP 服务器。
- HTTP 设置包含服务器地址、认证凭据、连接测试和当前后端状态；Web 平台也使用该远端后端，不启动本地服务。
- Token/API Key 使用安全存储；禁止把凭据拼进 URL 或普通日志。
- 切换后提示重新加载应用；切换前提供当前数据导出/备份和未提交写入检查。
- 默认仍为本地文件，已有 `app_data` 不迁移、不删除。

### 5.3 直接文件访问迁移

逐项盘点并迁移所有属于共享数据的直接文件访问，至少包括：

- `lib/utils/image_utils.dart` 的 `app_images`。
- Agent Chat 工具配置和模板。
- Chat 附件元数据及用户附件。
- WebView 应用数据、卡片和下载资源。
- 数据导出、完整备份、文件预览对共享数据的访问。

需要真实本地路径的功能改为“远端读取后落地到临时缓存”，并区分缓存生命周期和共享数据生命周期。日志、临时音频、TTS 文件、WebView 解压目录等保留本地实现。

## 6. server-nodejs 改造

- 新增 `storageRoutes.ts`，挂载到 `/api/v1/storage`，复用 `authMiddleware` 和 `getUserIdFromContext`。
- 扩展 `FileStorageService` 提供原始字节读写、元信息、前缀列表和条件写入能力；不要直接复用只处理 `EncryptedFile` 的方法。
- 文件索引更新必须支持外部写入后的缓存失效或版本校验，避免多进程/多实例读取旧索引。
- 增加请求体上限、单文件大小限制、速率限制和审计日志。
- 明确 `server-nodejs` 的数据目录格式，提供从当前本地 `app_data`/同步数据目录导入的迁移工具或文档。
- 新接口继续复用现有 JWT/API Key 认证，但不复用 `/api/v1/sync` 的同步快照协议。
- 由于服务端不保存明文，服务端新增的 storage 路由应接收客户端加密后的字节/封装，并在索引中保存密文版本信息。

## 7. API forwarding 移除

删除以下内容及引用：

- `lib/core/api_forwarding/`
- `lib/screens/settings_screen/widgets/api_forwarding_settings_dialog.dart`
- `settings_screen.dart` 中的配置入口、连接状态、事件订阅和生命周期代码。
- `app_initializer.dart` 中的自动启动逻辑和相关 import。
- `packages/api_forwarding_server/`
- `procm-commands.json` 中的 `forwarding` 命令。
- 根文档、包文档和测试中的 forwarding 说明。

保留 `web_socket_channel`，因为同步 WebSocket 和腾讯 ASR 仍然使用它。

## 8. 移除旧 WebDAV/文件同步

新 HTTP 存储后端覆盖跨端共享职责后，旧 WebDAV 和文件同步链路整体移除，不再保留“双轨模式”。保留本地文件后端，但不再通过 WebDAV 或 `/api/v1/sync` 做同步。

客户端删除范围包括：

- `lib/screens/settings_screen/controllers/webdav_controller.dart`
- `lib/screens/settings_screen/controllers/webdav_sync_controller.dart`
- `lib/screens/settings_screen/models/webdav_config.dart`
- `lib/screens/settings_screen/widgets/webdav_settings_dialog.dart`
- `lib/screens/settings_screen/widgets/webdav_settings_section.dart`
- `lib/core/services/backup_service.dart` 中仅服务于 WebDAV 的逻辑
- `lib/core/services/file_watch_sync_service.dart`
- `lib/core/services/sync_client_service.dart`
- `lib/core/services/sync_record_service.dart`
- `lib/core/services/sync_websocket_service.dart`
- `lib/screens/settings_screen/models/server_sync_config.dart`
- `lib/screens/settings_screen/widgets/server_sync_settings_section.dart`
- `lib/screens/settings_screen/screens/device_sync_screen.dart`（若无其他设备管理职责）
- `lib/core/services/device_registration_service.dart` 中仅服务于旧同步的部分
- `app_initializer.dart` 中文件监听同步初始化
- 相关设置控制器、路由、翻译、测试和文档

服务端删除或下线范围包括：

- `/api/v1/sync` 路由及其 WebSocket `/api/v1/sync/ws`
- `routes/syncRoutes.ts`
- `services/fileWatcherService.ts`
- `services/webSocketManager.ts` 中仅被同步使用的代码
- `index.ts` 中对应初始化、升级处理和启动日志
- 旧同步数据格式和专用索引逻辑（先提供迁移工具，再删除）

删除前必须提供一次性迁移：将现有本地 `app_data` 或旧服务器同步数据加密后写入新的 storage API；迁移成功后旧配置只读并清理。

## 9. 实施顺序

1. 固化 API 契约、认证方式、客户端加密封装、ETag 冲突策略和强制覆盖语义。
2. 为 `FileStorageService` 增加原始文件 CRUD、索引一致性和路径安全测试。
3. 实现 `storageRoutes`，补充 Node.js 路由集成测试。
4. 实现 `HttpStorage` 和可注入的 `StorageManager`，补充 Dart 单元测试。
5. 增加配置模型、设置界面和连接测试。
6. 先迁移核心 JSON 数据，再迁移图片/附件和需要本地路径的功能。
7. 增加 Web 平台 HTTP 后端适配、CORS/预检测试和远端文件缓存物化。
8. 提供旧本地/服务器数据的一次性加密迁移工具。
9. 删除 WebDAV、文件同步和 API forwarding 代码、包、命令和文档。
10. 完成双客户端并发测试、强制覆盖审计测试、断网测试、鉴权测试和旧数据兼容测试。

## 10. 验收标准

- 未配置 HTTP 时，应用行为与当前本地文件模式一致。
- 两个客户端使用同一账号和 HTTP 后端时，A 写入后 B 重新读取可见。
- 同一文件并发修改时，过期 `ETag` 得到 `412`，不会静默丢失更新。
- 文本、JSON、图片和附件均能正确读写；路径遍历请求被拒绝。
- HTTP 服务不可用时显示明确错误，不自动回退本地并制造数据分叉；Web 平台正确处理 CORS 和离线状态。
- 服务端存储内容不可直接解析为明文业务数据。
- forwarding 目录、服务、设置入口和 procm 命令全部移除，其他 WebSocket 功能仍可编译。

## 11. 已确认决策

- HTTP 后端为可选存储后端，本地文件仍是默认后端。
- 不在 Flutter 客户端启动本地 Dart HTTP 服务，统一由 `server-nodejs` 提供接口。
- 服务端不保存明文，采用客户端加密加 HTTPS。
- 必须支持 Web 平台；Web 平台只连接远端 HTTP 服务并配置 CORS。
- 允许显式强制覆盖，但普通写入必须进行版本校验，强制覆盖需要审计。
- 旧 WebDAV 和文件同步整体移除；新 HTTP 存储 API 是唯一的跨端共享方案。
