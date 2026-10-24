# 依赖与配置

> 所属：packages/aboutme_server · [返回索引](../CLAUDE.md)

## pubspec 依赖（version 0.1.0，Dart SDK ^3.10.0）

| 依赖 | 用途 |
| --- | --- |
| aboutme_data_sdk（path） | 全部数据业务（处理器/存储/认证） |
| shelf ^1.4.0 / shelf_router ^1.1.4 | HTTP 服务器与路由 |
| shelf_web_socket ^3.0.0 + web_socket_channel ^3.0.0 | WS 广播 |
| basic_utils ^5.7.0 | 工具（JWT/编码等） |

dev：test ^1.25.0、http ^1.3.0。

## ServerConfig 环境变量全表（lib/src/config.dart，与 nodejs 同名同默认）

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `PORT` | 8874 | 监听端口 |
| `DATA_DIR` | `当前目录/data` | 统一数据区根 |
| `JWT_SECRET` | 固定 dev 密钥（stderr 警告） | 签名密钥，生产必设 |
| `TOKEN_EXPIRY_DAYS` | 36500 | JWT 有效期 |
| `ENABLE_CORS` / `CORS_ORIGINS` | true / `*` | 跨域 |
| `MAX_STORAGE_FILE_SIZE_BYTES` | 10 MiB | 单文件上限 |
| `STORAGE_RATE_LIMIT_PER_MINUTE` | 1200 | 存储限流 |
| `ENABLE_LOGGING` | true | 日志 |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | admin / **admin123** | 管理凭据，生产必改 |
| `ALLOW_REGISTER` | true | 开放注册 |
| `ADMIN_DIR` | 自动探测 | 管理界面目录（→ DATA_DIR/admin → 本包 admin/） |
| `FCM_SERVICE_ACCOUNT` | DATA_DIR/当前目录探测 | service-account.json 路径 |
