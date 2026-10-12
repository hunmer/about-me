# aboutme_server (Dart)

Aboutme 同步服务器——**薄壳**：所有数据业务逻辑来自 [`aboutme_data_sdk`](../aboutme_data_sdk)，本包只做 HTTP 路由、认证、广播与托管。

## 架构

```
客户端(AboutmeData) ──REST──► 本服务器 ──同一套 SDK 处理器──► 统一数据区
MCP(AI 工具)      ──JSON-RPC──►        ▲
所有写操作 ──WS file_updated(真实文件路径)──► 客户端/其它设备刷新
```

- **统一数据区**：`DATA_DIR/users/{userId}/{pluginId}/{file}.json`（明文）。storage files API、插件 REST、MCP、SDK 本地模式全部操作同一批文件
- **无加密**：明文传输与存储
- **客户端离线可用**：数据在服务端持续可被 REST/MCP 处理；客户端 SDK 自动回退本地

## 端点

| 端点 | 说明 |
| --- | --- |
| `/health`、`/version` | 健康检查（免认证） |
| `/api/v1/auth/*` | 注册/登录/Token/API Key/设备/FCM 推送/访问控制 |
| `/api/v1/storage/files/*` | 文件 CRUD（明文，ETag 条件写 + 限流 + 审计）——与插件数据同区 |
| `WS /api/v1/storage/ws` | 实时同步广播（含 REST/MCP 触发的变更，广播真实文件路径） |
| `/api/v1/plugins/{id}/*` | 19 插件业务 API（仅需 X-API-Key） |
| `POST /mcp` | MCP（68 AI 工具，与 REST/客户端同一套处理器） |
| `/api/v1/system/*` | 管理员：插件注册表/商店配置（JS 插件执行返回 501） |
| `/admin/` | 管理界面静态托管 |

## 运行

```bash
dart run bin/server.dart                                    # 开发
dart compile exe bin/server.dart -o bin/aboutme-server      # 单文件可执行
```

环境变量同前（`PORT`/`DATA_DIR`/`JWT_SECRET`/`ADMIN_*` 等，见 `lib/src/config.dart`）。

## 测试

```bash
cd packages/aboutme_server
dart test    # 29 个测试：存储全链路 + WS 广播 + ETag 冲突 + 19 插件 +
             # 跨通路同数据（storage API 写 ↔ MCP 改 ↔ 读回）+
             # AboutmeData.remote 端到端 + FCM 签名向量 + system
```
