# 文件地图

> 所属：shared_models · [返回索引](../CLAUDE.md)

共 46 个 Dart 文件（不含 build_runner 生成物）：

```
lib/
├── shared_models.dart                  # 总导出
├── auth/auth_models.dart
├── sync/sync_request.dart · sync_response.dart
├── utils/  pagination · validation · result · md5_utils · iterable_extensions
├── repositories/<plugin>/<plugin>_repository.dart   # ×20：
│    activity agent_chat bill calendar calendar_album chat checkin contact
│    database day diary goods habits nodes notes openai store timer todo tracker
└── usecases/<plugin>/<plugin>_usecase.dart          # ×20（与上同域）
```

配置：`pubspec.yaml`（依赖 json_annotation/crypto/uuid）；`pubspec.lock`；`.dart_tool/` 为工具生成目录。
