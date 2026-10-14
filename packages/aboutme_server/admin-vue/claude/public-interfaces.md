# 对外接口

> 所属：packages/server-nodejs/admin-vue · [返回索引](../CLAUDE.md)

本面板是**纯消费方**：以下为 `src/api/index.ts` 调用的宿主服务器端点（前缀 `/api/v1`），同时这份清单可作为 server-nodejs REST API 的权威对照。

## 认证与账户 `/api/v1/auth/*`

| 端点 | 用途 |
|------|------|
| `POST /auth/login` | 登录（签发 JWT） |
| `GET /auth/register-status` | 查询是否开放注册 |
| `POST /auth/register` | 注册 |
| `GET/POST /auth/api-keys`、`DELETE /auth/api-keys/:keyId` | API Key 列表 / 创建 / 删除（`mk_live_`） |
| `GET /auth/key-verification` | Key 校验 |
| `GET /auth/user-info` | 当前用户信息 |
| `GET/POST /auth/api-access` | 接口可用性开关（ApiControl） |
| `POST /auth/verify-encryption-key` | 加密密钥校验 |
| `GET/POST /auth/devices`、`DELETE /auth/devices/:deviceId`、`POST /auth/devices/push` | 设备列表 / 注册 / 删除 / 推送 |

## 文件同步 `/api/v1/sync/*`

| 端点 | 用途 |
|------|------|
| `GET /sync/list` | 文件列表 |
| `GET /sync/status` | 同步状态 |
| `DELETE /sync/delete/:filePath` | 删除文件 |
| `GET /sync/pull-decrypted/:filePath` | 拉取并解密（面板预览/下载用） |
| `POST /sync/export` | ZIP 导出 |
| `GET /sync/download/:fileName` | 下载导出物 |

（插件数据/插件系统端点由 `plugins.ts` store 经通用 request 调用，具体路径见 store 与服务端 `pluginRoutes`/`pluginSystemRoutes`。）
