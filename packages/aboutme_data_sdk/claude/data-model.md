# 数据模型

> 所属：packages/aboutme_data_sdk · [返回索引](../CLAUDE.md)

## 统一数据区（明文 JSON）

- 本地：`{rootDir}/{pluginId}/{file}.json`（客户端为文档目录 `app_data/`）。
- 服务端：`DATA_DIR/users/{userId}/{pluginId}/{file}.json`（按认证用户隔离）。
- storage files API、插件 REST、MCP、SDK 本地/远程全部指向**同一批文件**。
- 业务处理器写回时保留**文件级额外字段**（如客户端 todo 的 viewMode/completedTasks）。

## 写封闭（426）

- `legacy_write_policy.dart`：migratedDomains（28 域）+ `_protectedRoots`（configs/ 前缀）。域名清单见仓库根 [claude/data-model.md](../../../claude/data-model.md)。
- handler 内部 data.read/write 不受限；writeBytes/writeFile/writePath/deletePath/clearPathPrefix 受拦截；读 API 全不受限。

## 媒体资源（asset://）

- 二进制统一存 asset://（引用计数，`asset_references.dart`）；物化经 `asset_materialization*`（宿主 IO）。
- `legacy_migration.json`：迁移幂等记录（migrateLegacyAssets / migrateLegacyStickers 共用），中断重跑安全，迁后删旧。
- 分块上传暂存：8MiB/块、总 256MiB、24h GC。

## 事务

- `_TransactionData`：事务内写缓冲 + 提交层重放——任何 read 抛 StorageException 都会触发重试，handler 内 catch 无效。
- AuthStore 并发治理（2026-10-24）：进程内互斥锁 + 临时文件原子写；api_keys/users 损坏由静默空表改为显式 `StorageException(invalidData)`。

## 域数据形态（三种）

1. 记录集合域：JSON 数组/分表 + 首写后快照 + migrate/restoreBackup/exportData（损坏/孤儿返回 CORRUPT_DATA 拒绝）。
2. 单文件快照域：整文件 getSnapshot/saveSnapshot，listKeys 做类型校验。
3. 薄文件层域：整文件读写命令，客户端保有逻辑。

各域字段结构以 `shared_models/` 的模型与各域 `*_test.dart` 为准（未逐一扫描）。
