# 开发约定

> 所属：packages/aboutme_data_sdk · [返回索引](../CLAUDE.md)

## 命令

```bash
cd packages/aboutme_data_sdk
dart pub get
dart test --concurrency=1    # 基线 214 项全过（必须单并发）
dart analyze                 # 须无 issue
```

## handler 编写规则

- 路由注册在 `route_config.dart`（**静态路由先于参数路由**）；`PUT /xxx/:id` 类路由的 handler 必须从 `params` 取同名路径参数键。
- handler 工厂在 `handler_factory.dart` 加各域 case。
- handler 内部 `data.read/write` 不受写封闭限制；`writeBytes/writeFile/writePath/deletePath/clearPathPrefix` 受 426 拦截（`legacy_write_policy.dart`）。
- `data.get/call` 返回完整响应 `{success, data, error, code}`，取值先判 success。
- **事务重放**：`_TransactionData` 事务内任何 read 抛 StorageException 都会被提交层重放，handler 内 catch 无效（参照 agent_chat getPreference 注释）。
- 某域要进 migratedDomains 的前提：该域 Flutter 侧**零残留直写**；加完跑全量测试。

## 新域实现模式选型（参照现成实现）

| 模式 | 参照文件 | 适用 |
| --- | --- | --- |
| 记录域迁移（migrate/restoreBackup/exportData、首写后快照、孤儿/损坏 CORRUPT_DATA 拒绝） | migrations/record_domains_migration.dart + handlers/tracker.dart | 记录集合域 |
| 单文件快照域（getSnapshot/saveSnapshot + listKeys 类型校验） | handlers/snapshot_domain.dart | timer/achievement/reminder/live2d/tts |
| 薄文件层命令（客户端逻辑不上移，整文件读写） | handlers/agent_chat.dart 外围段、handlers/openai.dart | 有全量缓存+保存链的域 |
| 媒体资源化（新写走 asset://，旧图 migrateLegacyAssets 批量迁移） | handlers/assets.dart | 含二进制的域 |
| 数据搬家（事务内读旧→写新→删旧） | handlers/database.dart + plugin_data.dart 的 removeLegacyAsset | 顶层旧文件 |

## 测试约定

- 构造损坏/遗留数据用**磁盘 File 直写注入**（照 `test/checkin_migration_test.dart` 的 inject 模式）。
- remote 相关断言：服务器业务命令按认证用户隔离落盘 `users/<id>/`，勿用数据区根路径断言。
- 并行 agent 勿同时改共享文件（route_config / handler_factory / legacy_write_policy / aboutme_data.dart）。
