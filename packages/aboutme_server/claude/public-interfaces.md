# 对外接口

> 所属：packages/aboutme_server · [返回索引](../CLAUDE.md)

## HTTP/WS 端点

| 端点 | 说明 |
| --- | --- |
| `GET /health`、`GET /version` | 健康检查（免认证） |
| `/api/v1/auth/*` | 注册/登录/Token/API Key/设备/FCM 推送/访问控制 |
| `/api/v1/storage/files/*` | 文件 CRUD（明文，**ETag 条件写** + 限流 + 审计），与插件数据同区 |
| `WS /api/v1/storage/ws` | 实时同步广播 `file_updated`（真实文件路径；REST/MCP 触发的变更同样广播） |
| `/api/v1/plugins/{id}/*` | 各域业务 REST（仅需 X-API-Key；转发 SDK 同一套处理器；含斜杠 key 的 query json-v1 编码约定） |
| `POST /mcp` | MCP（Streamable HTTP，AI 工具；工具定义在 mcp/tools.dart） |
| `GET /debug` | 插件 API 调试页（磁盘静态页，页面内填 API Key） |
| `/api/v1/system/*` | 管理员：插件注册表/商店配置（JS 插件执行 501） |
| `/admin/` | Vue 管理界面托管 |

## 常用 REST 形态（节选）

- system 域 config：`GET/PUT/DELETE /api/v1/plugins/system/config`（key 含 `/` 不走路径参数；GET 走 query json-v1 编码）。
- chat 贴图迁移：`POST /chat/sticker-collections/migrate-legacy`。
- capabilities：暴露 `protectedPrefixes`（admin FilesTab 删除双检查消费）。

## 认证

- JWT（用户登录，TOKEN_EXPIRY_DAYS 默认 36500 天）与 API Key（`mk_live_` 前缀，第三方/MCP）双轨；实现复用 SDK 的 auth_store/jwt_hs256/pbkdf2。
- 管理员：ADMIN_USERNAME/ADMIN_PASSWORD（basic 凭据，默认 admin/admin123——生产必改）。

## 客户端视角

客户端 SDK `AboutmeData.remote(serverUrl, apiKey)` 消费 storage files + plugins 两族端点；断言落盘路径时记住**用户隔离前缀 `users/{id}/`**。
