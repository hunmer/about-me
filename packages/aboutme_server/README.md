# aboutme_server (Dart)

基于 [`aboutme_data_sdk`](../aboutme_data_sdk) 数据核心的 Aboutme 同步服务器，**完整替代已废弃的 `packages/server-nodejs`**。

## 开放的 API

| 端点 | 说明 |
| --- | --- |
| `GET /health`、`GET /version` | 健康检查 / 版本（无需认证） |
| `POST /api/v1/auth/register\|login\|refresh` | 用户注册 / 登录 / 刷新 Token |
| `GET/POST/DELETE /api/v1/auth/api-keys` | API Key 管理（Bearer Token） |
| `GET /api/v1/auth/user-info\|devices\|api-access` 等 | 用户信息 / 设备 / 访问控制 |
| `POST /api/v1/auth/devices/push` | FCM 推送（service-account.json + OAuth2 RS256，遵循 HTTPS_PROXY） |
| `GET /api/v1/storage/health` | 存储连接检查（X-API-Key） |
| `GET/HEAD/PUT/DELETE /api/v1/storage/files/*` | 加密文件 CRUD（ETag 条件写、限流、审计） |
| `WS /api/v1/storage/ws` | 文件实时同步广播 |
| `/api/v1/plugins/{pluginId}/*` | **19 个插件 REST API**（12 专用 handler + 7 通用 CRUD；X-API-Key + X-Encryption-Key；写操作广播同步） |
| `POST /mcp` | **MCP 端点**（Streamable HTTP 无状态，68 个 AI 工具，进程内直调插件处理器） |
| `/api/v1/system/plugins*` | 插件注册表/商店配置（管理员；安装 JS 插件返回 501） |
| `/admin/` | 管理界面静态资源托管（复用 admin-vue 构建产物） |

## 运行

```bash
cd packages/aboutme_server
dart run bin/server.dart                     # 开发
dart compile exe bin/server.dart -o bin/aboutme-server   # 编译单文件可执行（约 8MB，无需 Dart 运行时）
```

环境变量与 nodejs 服务器同名同默认值：`PORT`(8874)、`DATA_DIR`、`JWT_SECRET`、`ADMIN_USERNAME/PASSWORD`、`ALLOW_REGISTER`、`STORAGE_RATE_LIMIT_PER_MINUTE`(1200)、`MAX_STORAGE_FILE_SIZE_BYTES`(10MB)、`ADMIN_DIR`（管理界面目录，缺省自动探测 DATA_DIR/admin、./admin、../server-nodejs/admin）、`FCM_SERVICE_ACCOUNT`，见 `lib/src/config.dart`。

## 与 nodejs server 的关系（已取代）

- **数据目录完全兼容**：同一 `DATA_DIR` 直接接管（users/api_keys/.storage/插件加密文件互认，PBKDF2/JWT/RS256/GCM 已实测逐字节兼容）
- **已全部迁移**：存储 API、认证、19 个插件 REST、MCP（68 工具）、FCM 推送、管理界面托管
- **有意不迁移**：nodejs 动态 require 的服务端 JS 插件系统（安装/钩子）——对应接口返回 501 并说明
- 客户端（Flutter app）无需任何改动，同一配置直接切换

## 测试

```bash
cd packages/aboutme_server
dart test    # 23 个测试：存储全链路 + WS 广播 + ETag 冲突 + 19 插件 API + MCP + FCM 签名向量 + system
```
