# 依赖与配置

> 所属：packages/server-nodejs · [返回索引](../CLAUDE.md)

## 运行时依赖

| 依赖 | 用途 |
|------|------|
| express / cors / multer | HTTP 框架、跨域、上传（内存存储，10MB 上限） |
| ws / express-ws | WebSocket 实时同步 |
| jsonwebtoken | JWT 签发与校验 |
| firebase-admin | FCM 推送 |
| adm-zip / archiver | 插件 ZIP 安装与数据导出 |
| chokidar | 文件变更监听 |
| winston | 日志 |
| hookable | 服务端插件钩子 |
| https-proxy-agent | 出站代理支持 |
| dotenv / uuid | 环境变量 / ID 生成 |

开发依赖：TypeScript ^5.5、ts-node-dev、jest + ts-jest + supertest、eslint、@types/*。

## 环境变量全集（`src/config/serverConfig.ts`）

| 变量 | 默认 | 说明 |
|------|------|------|
| `PORT` | `8874` | 监听端口 |
| `DATA_DIR` | `./data` | 数据目录 |
| `JWT_SECRET` | 开发固定值（告警） | 生产必须设置 |
| `TOKEN_EXPIRY_DAYS` | `36500` | JWT 有效期（天） |
| `ENABLE_CORS` | `true` | CORS 开关 |
| `CORS_ORIGINS` | `*` | 允许源（逗号分隔） |
| `MAX_REQUEST_SIZE` | `10mb` | 请求体上限 |
| `ENABLE_LOGGING` | `true` | 日志开关 |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | `admin` / `admin123` | 管理员账号 |
| `ALLOW_REGISTER` | `true` | 是否开放注册 |

## admin-vue 依赖

Vue ^3.5、naive-ui ^2.44、pinia ^3、@vicons/ionicons5、jszip；构建：Vite ^8 + vue-tsc ^3.2 + TypeScript ~5.9。
