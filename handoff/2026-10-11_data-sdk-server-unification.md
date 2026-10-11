# Handoff: 数据 SDK 化 + Dart 服务器统一架构（前后端分离 / 明文统一数据区）

- 日期：2026-10-11
- 状态：**全部完成，测试全绿**（SDK 42 / server 29 / client analyze 0 error + 4 tests），未提交 git（用户未要求）
- 会话主题：三轮递进架构改造（SDK 分离 → 替换 nodejs server → 取消加密统一数据区 + 全插件迁移 + 局部刷新）

## 一、最终架构（一段话版）

业务逻辑唯一存在于 `packages/aboutme_data_sdk`；`packages/aboutme_server` 是纯 HTTP 壳（路由/认证/WS 广播/FCM/admin 托管）；客户端只调 `AboutmeDataService`（全局单例，SDK 自动决定本地直处理还是远程 REST）。数据明文存于统一数据区：本地 `app_data/{plugin}/{file}.json` ⇄ 服务端 `DATA_DIR/users/{userId}/{plugin}/{file}.json`，storage files API、插件 REST（19 插件）、MCP（68 工具）、SDK 本地/远程全部操作同一批文件。所有写操作（REST/MCP/SDK）→ 服务端 WS `file_updated`（真实文件路径）→ 客户端 SDK 事件流 → 已接入的 10 个 controller 局部刷新。

```
AboutmeData.local(root) | AboutmeData.remote(url, apiKey)   ← 客户端代码完全一致
  ├─ 文件层: readPath/writePath/readPathText/deletePath/existsPath/listPathKeys/clearPathPrefix
  │          readFile/writeFile（插件分区版）
  └─ 业务层: call(pluginId, action, params) / get(...)     ← 经路由表解析 method+path
             与 REST /api/v1/plugins/*、MCP /mcp 同一套 handler
```

## 二、关键产物（路径）

| 产物 | 路径 |
| --- | --- |
| SDK 核心（全平台） | `packages/aboutme_data_sdk/lib/aboutme_data_sdk.dart`（含 `services/`：plugin_data/types/utils/route_config/crud/invoker/handler_factory/aboutme_data/action_resolver + 12 个 handlers） |
| SDK IO 侧 | `packages/aboutme_data_sdk/lib/io.dart`（LocalPluginBackend、LocalFileStorage、AuthStore、LegacyEncryption 等） |
| 客户端全局入口 | `lib/core/data/aboutme_data_service.dart`（单例、local/remote 自动决定、`onPluginChanged` 局部刷新订阅） |
| WS 转发 | `lib/core/storage/storage_websocket_service.dart`（file_updated → publishRemoteEvent） |
| 服务器壳 | `packages/aboutme_server/`（server_builder 装配；plugin_routes/mcp_endpoint 每请求构建 LocalPluginBackend(userDir)，事件→WS） |
| 旧数据迁移工具 | `packages/aboutme_server/tool/migrate_to_plaintext.dart`（信封 12B-IV + legacy 16B-IV 双格式 → 明文，自动备份） |
| 已废弃 | `packages/server-nodejs/`（README/package.json 已标记 deprecated，未删除） |
| 文档 | 两包 README + 根 CLAUDE.md（架构指向已更新） |

## 三、本轮已完成清单（验证证据）

1. **SDK 统一服务层**：12 专用 handler + 7 通用 CRUD 明文化迁入 SDK；handler 签名 `(PluginData, params)`；**每请求重建 handlers（闭包捕获当前 backend）保证多用户隔离**（invoker 无缓存——这是有意设计）
2. **明文化**：HttpStorage 去 envelope；config.encryptionKey 保留但废弃；服务端/插件区/传输全明文
3. **统一数据区**：`LocalFileStorage.getStorageDir = 用户根目录`（原 `.storage` 前缀已移除）；listRawFiles 过滤隐藏文件
4. **额外字段保留**：todo/crud handler 写回保留文件级额外字段（viewMode/completedTasks 等），与客户端整文件写共存
5. **客户端全量迁移**：68 文件 330+ 处 `StorageManager.read/write/...` → `AboutmeDataService.instance.readPath/...`（4 组子代理并行，grep 复查零遗漏）；保留项：readBytes/writeBytes 二进制、目录工具、StorageManager 构造签名（兼容）
6. **局部刷新**：`onPluginChanged`（过滤本机写入 source=client/local、300ms 防抖、返回取消句柄）；已接入 10 controller：todo、chat timeline、agent_chat conversation、day、tracker、calendar、bill、store、nodes（dispose 取消）
7. **测试**：SDK 42 / server 29（含跨通路同数据：storage API 写→插件读→MCP 改→字段保留→读回；AboutmeData.remote 端到端；FCM RS256 与 nodejs 逐字节一致）/ client http_storage_test 4

## 四、重要设计决策（勿推翻）

- **invoker 不缓存 handlers**：handler 工厂捕获 backend 实例，缓存会跨用户串数据
- **readPath 缺省返回 `{}`**（对齐 StorageManager.read 历史语义）；个别调用点需 null 语义时显式传 `readPath(path, null)`（chat/agent_chat 组已这样处理）
- **自己设备的写不回流**：服务端 WS 广播按 X-Device-ID 排除来源设备；本地模式事件 source='client' 被 onPluginChanged 过滤——避免写后自我 reload
- **远程写文件层走 storage files API，业务层走 plugins API**——两者同数据区，条件写（If-Match）+ 强写回退保留
- **web 安全**：AboutmeData 经条件导入隔离 dart:io（local_plugin_backend_stub），umbrella 可在 Web 引用

## 五、已知遗留 / 后续候选

- contact/habits/notes controller 非 ChangeNotifier，未接局部刷新（RouteRefreshManager 兜底中）
- 各文件保留的 StorageManager 构造参数/字段有 unused_field warning（有意保留，纯整洁问题）
- 服务端可做磁盘级加密（bitlocker/LUKS）补偿明文存储
- `writeBytesIfCurrent` 严格条件写已就绪，可接 UI 冲突提示
- nodejs 目录（~50MB node_modules）确认不回退后可删
- **用户存量数据需手动迁移**：`cd packages/aboutme_server && dart run tool/migrate_to_plaintext.dart <DATA_DIR> <旧base64密钥>`（先停服务器；幂等、自动备份）

## 六、运行与验收速查

```bash
# 测试
cd packages/aboutme_data_sdk && dart test        # 42
cd packages/aboutme_server && dart test          # 29
flutter analyze                                  # 0 error
flutter test test/http_storage_test.dart         # 4

# 启动（procm 或直跑）
procm-command start server                       # = cd packages/aboutme_server && dart run bin/server.dart (port 8874)
# exe 编译: procm-command start server-build

# 端到端验证局部刷新：app 打开 todo 页 → MCP 调 aboutme_todo_createTask → 列表 ~0.3s 自动刷新
```

## 七、建议技能（Suggested skills）

- `planning-with-files`：若下一轮做多插件 controller ChangeNotifier 改造，建议用文件计划跟踪
- 子代理并行模式：本轮大量机械迁移用 4 组 general-purpose 后台代理完成，规则表模板见本会话（可直接复用迁移规则段落）
- CodeGraph MCP：查客户端调用关系（如 RouteRefreshManager / EventManager 的消费方）

## 八、敏感信息说明

本会话测试均使用假密钥/临时目录；服务端默认管理员账密为代码内默认值（见 serverConfig，部署应改环境变量）；未在文档中保留任何真实凭据。
