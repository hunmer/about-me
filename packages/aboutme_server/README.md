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
| `GET /debug` | 插件 API 调试页（纯静态 `debug/index.html`，现读磁盘、改完刷新即生效，页面内填 API Key） |
| `/api/v1/system/*` | 管理员：插件注册表/商店配置（JS 插件执行返回 501） |
| `/admin/` | 管理界面静态托管（Vue 管理面板，源码在本包 `admin-vue/`） |

## 运行

```bash
dart run bin/server.dart                                    # 开发
dart compile exe bin/server.dart -o bin/aboutme-server      # 单文件可执行
```

环境变量同前（`PORT`/`DATA_DIR`/`JWT_SECRET`/`ADMIN_*` 等，见 `lib/src/config.dart`）。

### Docker 部署

在本仓库根目录执行：

```bash
cd packages/aboutme_server
cp .env.example .env
```

编辑 `.env`，为 `JWT_SECRET` 和 `ADMIN_PASSWORD` 设置强随机值，然后构建并启动：

```bash
docker compose up -d --build
docker compose logs -f
```

服务仅映射到本机 `127.0.0.1:8874`，管理界面地址为 `http://127.0.0.1:8874/admin/`；健康检查为 `http://127.0.0.1:8874/health`。数据持久化在本包的 `data/` 目录。停止服务：

```bash
docker compose down
```

### 导出镜像与服务器部署

导出镜像（gzip 压缩后约为原大小的 1/3，`docker load` 可直接读取）：

```bash
cd packages/aboutme_server
docker save aboutme_server-aboutme-server | gzip > aboutme-server.tar.gz
```

本机为 Apple Silicon（arm64）而目标是 x86 服务器时，必须显式指定平台构建，否则服务器上会报 `exec format error`：

```bash
docker buildx build --platform linux/amd64 -t aboutme-server:amd64 -f Dockerfile ../.. --load
docker save aboutme-server:amd64 | gzip > aboutme-server-amd64.tar.gz
```

服务器上 `docker load -i aboutme-server-amd64.tar.gz` 导入后，用镜像版 compose 启动（与上面 build 模式的区别仅在 `image` 替代 `build`）：

```yaml
services:
  aboutme-server:
    image: aboutme-server:amd64
    container_name: aboutme-server
    restart: unless-stopped
    env_file: .env
    ports:
      - "127.0.0.1:8874:8874"
    volumes:
      - ./data:/app/data
```

注意事项：

- 容器以非 root 用户（uid/gid 999）运行，Linux 宿主机需先 `chown -R 999:999 ./data`，否则启动时报 `Permission denied`（macOS 的 Docker Desktop 不受影响）
- 需要公网访问时把端口映射改为 `"8874:8874"` 并在云安全组放行；本服务为明文 HTTP，公网使用建议置于 HTTPS 反代之后，并设置强 `JWT_SECRET`/`ADMIN_PASSWORD`、注册完账号后设置 `ALLOW_REGISTER=false`
- 镜像内已含管理界面与调试页，升级镜像即可同步更新 `/admin/` 与 `/debug`

## 管理界面（admin-vue）

```bash
cd admin-vue
npm install && npm run build    # 构建产物输出到 ../admin，由服务器托管于 /admin/
npm run dev                     # 开发模式（/api 代理到 localhost:8874）
```

服务器按 `ADMIN_DIR` 环境变量 → `DATA_DIR/admin` → 本包 `admin/` 的顺序解析托管目录。

## 测试

```bash
cd packages/aboutme_server
dart test    # 29 个测试：存储全链路 + WS 广播 + ETag 冲突 + 19 插件 +
             # 跨通路同数据（storage API 写 ↔ MCP 改 ↔ 读回）+
             # AboutmeData.remote 端到端 + FCM 签名向量 + system
```
