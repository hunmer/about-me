# 依赖与配置

> 所属：packages/aboutme_data_sdk · [返回索引](../CLAUDE.md)

## pubspec 依赖（version 0.1.0，Dart SDK ^3.10.0，publish_to none）

| 依赖 | 用途 |
| --- | --- |
| shared_models（path: ../../shared_models） | 共享模型（如 AssetDto） |
| crypto ^3.0.3 | 哈希（sha256 等） |
| encrypt ^5.0.3 + pointycastle ^3.9.1 | 认证兼容（PBKDF2/JWT） |
| http ^1.3.0 | HttpStorage 远端后端 |
| path ^1.8.3 | 路径处理 |
| uuid ^4.3.3 | ID 生成 |

dev：test ^1.25.0。**无任何 Flutter 依赖**（零 flutter_* 包）。

## 配置模块

- `lib/src/services/data_config.dart`：数据目录/分区配置。
- `lib/src/storage_config.dart`：StorageBackendConfig（远端后端配置；含历史 encryption 字样残留，实际已无加密行为）。
- 统一数据区：本地 `{rootDir}/{pluginId}/{file}.json`（客户端为文档目录 app_data/）；服务端 `DATA_DIR/users/{userId}/{pluginId}/{file}.json`。

## 条件导入（平台拆分）

- `asset_materialization.dart` + `_io.dart` / `_stub.dart`
- `host_file_input.dart` + `_io.dart` / `_stub.dart`
- `local_plugin_backend.dart` + `_stub.dart`

Web/VM 平台差异经这三个族隔离，纯接口在无条件导入的文件中。
