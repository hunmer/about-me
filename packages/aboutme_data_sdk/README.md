# aboutme_data_sdk

Aboutme 纯数据 SDK（纯 Dart，无 Flutter 依赖）。**数据处理统一在这里**——客户端、服务器 REST、MCP 使用同一套业务处理器；数据明文存储于统一数据区。

```
                 ┌──────────────────────────────────────┐
                 │      aboutme_data_sdk（唯一逻辑）       │
                 │  文件层: readFile / writeFile          │
                 │  业务层: 12 插件处理器 + 通用 CRUD      │
                 │  AboutmeData: local | remote 自动路由  │
                 └──────┬─────────────────┬───────────────┘
                        │ 本机直处理        │ REST
        ┌───────────────▼──┐   ┌──────────▼──────────────┐
        │ 客户端(本地模式)    │   │ aboutme_server          │
        │ app_data/{plugin}/│   │ users/{id}/{plugin}/    │
        └──────────────────┘   │  ├─ /api/v1/storage/files│
   客户端只调 SDK 方法           │  ├─ /api/v1/plugins/*    │
   （该走哪条路 SDK 决定）       │  └─ /mcp（同一套处理器）   │
                              └─────────────────────────┘
```

## 统一数据区（明文 JSON）

- 本地：`{rootDir}/{pluginId}/{file}.json`（客户端为 app_data 目录）
- 服务端：`DATA_DIR/users/{userId}/{pluginId}/{file}.json`
- storage files API、插件 REST、MCP、SDK 本地/远程全部指向**同一批文件**
- 业务处理器写回时保留文件级额外字段（如客户端 todo 的 viewMode/completedTasks）

## AboutmeData（客户端唯一入口）

```dart
// 本地模式（零网络） / 远程模式（REST）——调用方代码完全一致
final data = AboutmeData.local(appDataDir);
// 或 AboutmeData.remote(serverUrl: ..., apiKey: ...)

// 文件层
await data.writeFile('todo', 'tasks.json', {...});
final file = await data.readFile('todo', 'tasks.json');

// 业务层（与 REST/MCP 同一套处理器，按路由表自动解析 method+path）
final r = await data.call('todo', 'create', {'title': '买牛奶'});
await data.call('todo', 'completeTask', {'id': taskId});
await data.get('todo', 'getStats');

// 事件流：本地写操作自动广播；远端 WS 变更经 publishRemoteEvent 转发
data.events.listen((e) => print('$e'));
```

## 组成

| 入口 | 内容 |
| --- | --- |
| `aboutme_data_sdk.dart` | 全平台：`AboutmeData`、`PluginData`、插件服务层（types/route_config/invoker/crud/12 handler）、`StorageInterface`、`HttpStorage`（明文+条件写）、`DataStore`、`StorageBackendConfig` |
| `io.dart` | IO：`LocalPluginBackend`、`LocalFileStorage`（服务端文件存储/认证/审计）、`AuthStore`、`LegacyEncryption`（仅供旧数据迁移解密） |

## 历史兼容与迁移

- 旧端到端加密已取消：数据明文传输与存储；`StorageBackendConfig.encryptionKey` 字段保留但已废弃
- 旧数据迁移：`aboutme_server` 包的 `dart run tool/migrate_to_plaintext.dart <DATA_DIR> <KEY>`（信封 + 旧版两种密文一次性转明文，自动备份）
- 与 nodejs 服务器的认证兼容性（PBKDF2/JWT/API Key）保留

## 测试

```bash
cd packages/aboutme_data_sdk
dart test    # 41 个测试：AboutmeData 本地全链路/事件流/额外字段保留 + 存储条件写 + 认证兼容向量
```
