# 对外接口

> 所属：packages/server-nodejs · [返回索引](../CLAUDE.md)

> REST 端点统一前缀 `/api/v1`（依据 admin-vue `src/api/index.ts` 的调用路径核实）。

## 认证

| 方式 | 说明 |
|------|------|
| JWT | `routes/authRoutes.ts`：注册（受 `ALLOW_REGISTER` 控制）/ 登录签发；默认有效期 `TOKEN_EXPIRY_DAYS=36500` 天 |
| API Key | 管理面板生成，`mk_live_` 前缀；供 MCP 服务器与第三方程序化调用 |

中间件：`middleware/authMiddleware.ts`（凭证校验）、`middleware/apiEnabledMiddleware.ts`（接口开关）。

## 文件同步（`routes/syncRoutes.ts`）

push / pull / list / delete；内容经 `encryptionService`（AES-256-GCM）端到端加密，服务端只见密文。

## 插件数据 API（`routes/pluginRoutes/`）

- `routeConfig.ts` 的 `PLUGIN_ROUTE_CONFIGS` 定义 **19 个插件域**：chat、notes、activity、goods、bill、todo、diary、checkin、calendar、contact、tracker、day、agent_chat、calendar_album、database、nodes、openai、store、timer。
- 其中 **12 个有专用 handler**（`handlers/index.ts`：chat、notes、bill、todo、diary、goods、activity、checkin、tracker、calendar、contact、day），其余 7 个域回落到通用 CRUD（`crud.ts`：getList / getById / create / update / delete）。
- `factory.ts` 按配置批量生成路由（含路径/查询参数提取），数据读写统一走 `PluginDataService` → 文件存储。

## 服务端插件系统（`routes/pluginSystemRoutes.ts`）

- 插件列表 / 详情；从商店（`plugins/plugin-store.json`）安装；上传 ZIP 安装；启用 / 禁用 / 卸载。
- 插件可挂 **before/after 钩子**（hookable）拦截数据处理。

## WebSocket（`services/webSocketManager.ts`）

- 实时同步通道：`FileWatcherService`（chokidar）监听 data 目录变更 → 推送订阅客户端。
- 推送通知：`fcmService`（firebase-admin）。

## 消费方

- Flutter 客户端（同步设置中配置服务器地址）。
- `packages/mcp-memento-server`（`MEMENTO_SERVER_URL` + API Key）。
- 管理面板 `/admin`（浏览器）：其消费的 `/api/v1` 端点全集见 [admin-vue 对外接口](../admin-vue/claude/public-interfaces.md)。
