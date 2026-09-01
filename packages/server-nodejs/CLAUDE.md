# server-nodejs 同步服务器

`@hunmer/aboutme-server` v1.0.3 —— Aboutme 的 Node.js + TypeScript 同步服务器（Express），是客户端与第三方 AI 工具的**唯一数据中枢**：负责用户认证（JWT + API Key）、端到端加密（AES-256-GCM）的文件同步、19 个插件域的 RESTful API、WebSocket 实时同步、服务端插件系统（钩子/商店/ZIP 安装）以及内置 Vue 3 管理面板。存储为**纯文件**（默认 `./data`），无数据库依赖；默认端口 8874，可 npm 全局安装后以 `aboutme-server` 启动。

它取代了早期根目录下的 Dart（Shelf）版服务器——旧文档中 `cd server && dart run bin/server.dart` 已失效。

## 约定的规则

- 开发：`npm run dev`（ts-node-dev 热重载）；构建 `npm run build`（**会先构建 admin-vue 面板再 tsc**）；测试 `npm test`（jest 串行）；`npm run lint`。
- 新插件 API：在 `src/routes/pluginRoutes/handlers/` 添加 handler 并注册到 `handlers/index.ts`，路由由 `factory.ts` 工厂生成。
- 配置只从环境变量 / `.env` 读取（`src/config/serverConfig.ts`）；生产必须设置 `JWT_SECRET` 与管理员密码，默认值仅限开发。
- `data/` 为运行时数据目录，`plugins/` 为服务端插件与商店清单，均不要手工编辑后不备份。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 服务分层、请求流、管理面板 | 第一次接触本包 |
| [开发约定](claude/conventions.md) | 命令、目录纪律、插件开发规范 | 改代码之前 |
| [入口与启动](claude/entrypoints.md) | main() 装配顺序、CLI 入口 | 排查启动问题 |
| [对外接口](claude/public-interfaces.md) | REST 路由、WebSocket、认证方式 | 对接客户端/MCP |
| [依赖与配置](claude/dependencies-and-config.md) | 依赖表、环境变量全集 | 部署、升级依赖 |
| [数据模型](claude/data-model.md) | data/ 目录结构、同步与加密模型 | 改存储/同步逻辑 |
| [测试与质量](claude/testing-and-quality.md) | jest 设置、覆盖情况 | 提测、补测试 |
| [文件地图](claude/file-map.md) | src 全量文件速查 | 找代码 |
| [常见问题](claude/faq.md) | 端口/面板/插件安装等高频问题 | 遇到问题先查 |

## 模块索引

| 模块 | 说明 |
|------|------|
| `src/routes/` | authRoutes、syncRoutes、pluginSystemRoutes、pluginRoutes（工厂 + 19 个 handler） |
| `src/services/` | 认证、加密、存储、插件数据、插件系统、WebSocket、文件监听、FCM、事件 |
| `src/middleware/` | authMiddleware、apiEnabledMiddleware |
| `admin-vue/` | Vue3 + Naive UI + Pinia 管理面板（构建产物进 `dist/admin`）→ [admin-vue/CLAUDE.md](admin-vue/CLAUDE.md) |
| `plugins/` | 服务端插件目录 + `plugin-store.json` 商店清单 |
| `bin/aboutme-server.js` | npm 全局安装的 CLI 入口 |

## 扫描状态

- 更新时间：2026-09-02（第二轮：补扫 admin-vue，梳理插件路由工厂细节）
- 已扫描：package.json、README、src 全量文件清单、config、index.ts 装配逻辑、tests 目录、pluginRoutes 工厂/配置/handler 注册表、admin-vue 全部源码清单与 `/api/v1` 端点。
- 未深扫：各 handler/service 实现细节（路由模式已梳理，见 [对外接口](claude/public-interfaces.md)）、`plugins/data-sync-logger-v2` 示例插件内部、admin-vue 组件模板细节。
