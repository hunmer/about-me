# 数据模型

> 所属：packages/server-nodejs · [返回索引](../CLAUDE.md)

## 存储原则

**纯文件存储，无数据库。** 所有状态都在 `DATA_DIR`（默认 `./data`）下：

- 用户与凭证（`AuthService` 管理：用户资料、JWT 签发基础、API Key `mk_live_*`）。
- 同步文件仓库（密文形态，经 `syncRoutes` push/pull）。
- 插件数据（`PluginDataService` 按 19 个插件域分目录读写 JSON）。
- 服务端插件与商店清单（`plugins/plugin-store.json`，安装态记录）。

目录内具体文件布局由 `FileStorageService` 约定；删除目录即清空对应数据。

## 同步与加密模型

- 协议模型复用 `shared_models/`：`sync_request.dart` / `sync_response.dart`（客户端侧）与 `syncRoutes` 对应。
- 端到端加密：客户端 `encrypt`（AES-256-GCM）加密 → 服务端 `encryptionService` 只做转发/存储密文；`ABOUTME_ENCRYPTION_KEY` 由客户端与 MCP 侧各自持有。
- 双向同步实现说明：根目录 `docs/bidirectional_sync_implementation.md`。

## 事件与钩子

- `eventEmitter.ts` + `hookable`：服务端插件在数据操作前后挂 before/after 钩子（如示例插件 `data-sync-logger-v2` 记录同步日志）。
- 文件变更 → `FileWatcherService` → `WebSocketManager` 推送，构成实时同步闭环。

## 与客户端模型的对应

- 客户端每个插件在 `shared_models/lib/repositories/<plugin>/` 定义 Repository 接口，服务端 `handlers/<plugin>.ts` 提供同域 REST 实现——**两端插件域清单保持同步扩展**（当前客户端 25 插件 / 服务端 19 域 / MCP 12 域，后两者为子集）。
