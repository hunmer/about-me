# 入口与启动

> 所属：packages/server-nodejs · [返回索引](../CLAUDE.md)

## `src/index.ts` → `main()`

1. `dotenv/config` 加载环境变量；`printConfig()` 打印（脱敏）配置。
2. `FileStorageService(config.dataDir).initialize()` —— 初始化/校验数据目录。
3. 实例化服务：`AuthService`（JWT 密钥、管理员账号、令牌有效期）→ `PluginDataService` → `PluginService` → `WebSocketManager` → `FileWatcherService`。
4. 创建 Express app + http server：`cors`（可配置源）→ `express-ws` 升级 → multer 上传中间件（10MB）。
5. 挂载路由：`createAuthRoutes` / `createSyncRoutes` / `createPluginRoutesIndex` / `createPluginSystemRoutes`。
6. 静态托管：管理面板（`admin/`，含 MIME 映射表）与其他静态资源。
7. 监听 `config.port`（默认 **8874**）。

## CLI 入口

- `bin/memento-server.js`：npm 全局安装后的 `memento-server` 命令，直接拉起 `dist/index.js`。
- `package.json` `files: ["dist"]` —— 发布物只含 dist（内含编译代码 + admin 面板 + plugins 清单）。

## 管理面板（admin-vue）

- 开发：`cd admin-vue && npm run dev`（Vite）。
- 构建：`npm run build:admin`（根脚本内）→ `vue-tsc -b && vite build`，产物拷入 `dist/admin` 由服务器托管。
- 首次启动数据目录中会生成默认管理员（admin/admin123，可由环境变量覆盖）。
