# aboutme_data_sdk

Aboutme 纯数据 SDK（纯 Dart，无 Flutter 依赖）。客户端与服务器共享同一套数据核心，实现前后端分离：

```
┌─────────────────────┐         ┌──────────────────────────┐
│ aboutme client      │         │ aboutme_server (Dart)    │
│ StorageManager      │  HTTP   │ /api/v1/storage/files    │
│  └─ DataStore ──────┼────────►│  └─ LocalFileStorage     │
│     └─ HttpStorage  │   WS    │ /api/v1/plugins/*        │
│        (条件写+重试) │◄───────►│  └─ PluginDataStore      │
└─────────────────────┘         │ /mcp (68 AI 工具)         │
        两端引用同一个 SDK 包     └──────────────────────────┘
```

## 组成

| 入口 | 内容 | 平台 |
| --- | --- | --- |
| `aboutme_data_sdk.dart` | `StorageInterface`、`HttpStorage`（AES-GCM 端到端加密 + ETag **条件写**：If-Match/If-None-Match，冲突自动刷新重试、二次冲突回退强写；另有严格模式 `writeBytesIfCurrent`）、`StorageBackendConfig`、`DataStore`（数据管理门面） | 全平台（含 Web） |
| `io.dart` | `LocalFileStorage`（服务端文件存储：条件写/路径安全/审计/统计）、`AuthStore`（users.json/API Key/JWT HS256/PBKDF2）、`LegacyEncryption`（旧版 AES-256-GCM 16 字节 IV，插件数据用）、`PluginDataStore`（插件加密数据读写/密钥验证文件/全量重加密） | 仅 IO（服务端/CLI） |

## 数据兼容性

与 nodejs 服务器（`packages/server-nodejs`，已废弃）的数据目录、文件格式、协议**完全兼容**：

- PBKDF2-SHA256（10000 轮/64 字节）密码哈希与 `crypto.pbkdf2Sync` 一致，users.json 可互用
- API Key `mk_` 格式 + sha256 哈希存储，api_keys/{userId}.json 可互用
- JWT HS256 可验证 nodejs jsonwebtoken 签发的 token；RS256（FCM OAuth2）签名与 nodejs 逐字节一致
- 存储文件 ETag = `"<sha256hex>"`，`.storage` 目录布局一致；写操作支持 If-Match 条件写
- 旧版插件加密文件（`iv.ciphertext` 格式）互通
- 同一 DATA_DIR 可被两种服务器直接接管（已实测双向验证）

## 测试

```bash
cd packages/aboutme_data_sdk
dart test    # 35 个测试，含 nodejs 生成的兼容向量（PBKDF2/JWT/GCM/MD5）
```
