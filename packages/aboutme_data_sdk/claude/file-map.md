# 文件地图

> 所属：packages/aboutme_data_sdk · [返回索引](../CLAUDE.md)

```text
aboutme_data_sdk/
├── CLAUDE.md                  # 本索引
├── README.md                  # 官方说明（部分数字为历史快照）
├── pubspec.yaml               # 纯 Dart，零 Flutter 依赖
├── lib/
│   ├── aboutme_data_sdk.dart  # 全平台入口（导出核心）
│   ├── io.dart                # IO 入口（追加存储/认证/迁移导出）
│   ├── examples.dart          # 使用示例
│   └── src/
│       ├── storage_interface.dart / data_store.dart / http_storage.dart
│       ├── local_file_storage.dart / auth_store.dart
│       ├── jwt_hs256.dart / pbkdf2.dart          # nodejs 认证兼容
│       ├── legacy_write_policy.dart              # 426 写封闭核心
│       ├── storage_config.dart / storage_errors.dart
│       └── services/
│           ├── aboutme_data.dart                 # 客户端唯一入口
│           ├── route_config.dart / handler_factory.dart / invoker.dart
│           ├── crud.dart / query_store.dart / types.dart / utils.dart
│           ├── chat_facade.dart / diary_facade.dart / assets_facade.dart
│           ├── asset_*.dart（5 个：materialization×3/media_type/references）
│           ├── capabilities.dart / data_config.dart
│           ├── plugin_data.dart / *_plugin_backend*.dart / file_plugin_persistence.dart
│           ├── host_file_input*.dart（3 个）
│           ├── handlers/        # 33 个域 handler（见 module-responsibilities.md）
│           ├── migrations/      # record_domains / diary / notes_nodes（dormant）
│           └── templates/       # chat / diary 示例数据
└── test/                        # 42 个测试文件（见 testing-and-quality.md）
```
