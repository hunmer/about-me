# 入口与导出

> 所属：packages/aboutme_data_sdk · [返回索引](../CLAUDE.md)

## 双入口（条件平台拆分）

| 入口 | 导出 |
| --- | --- |
| `lib/aboutme_data_sdk.dart`（全平台） | DataStore、HttpStorage、AboutmeData、crud、handler_factory、invoker、PluginData、persistent_plugin_backend、query_store、ChatFacade/DiaryFacade/AssetsFacade、asset_media_type、MaterializedAsset、data_config、capabilities、route_config、types、utils、storage_config、storage_errors、legacy_write_policy、StorageInterface、AssetDto（shared_models） |
| `lib/io.dart`（IO 平台，含上面全部） | 追加：AuthStore、jwt_hs256、LocalFileStorage、pbkdf2、local_plugin_backend、file_plugin_persistence、asset_materialization、diary 迁移备份/报告（restoreDiaryMigrationBackup / diaryMigrationReport） |

另有 `lib/examples.dart` 为使用示例。

## 运行时入口

- `AboutmeData.local(appDataDir)`：本地模式（零网络），直连本地后端。
- `AboutmeData.remote(serverUrl:, apiKey:)`：远程模式（REST），调用方代码与本地完全一致。
- 事件流：本地写操作自动广播；远端 WS 变更经 publishRemoteEvent 转发，`data.events` 统一消费。

## 宿主接线

- Flutter 客户端：`lib/core/storage/`（StorageManager）实现 storage_interface 转发；业务入口 `lib/core/data/aboutme_data_service.dart`。
- 服务器：`packages/aboutme_server` 以 io.dart 入口使用（LocalFileStorage/AuthStore + 处理器）。
