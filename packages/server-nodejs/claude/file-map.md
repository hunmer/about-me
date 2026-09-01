# 文件地图

> 所属：packages/server-nodejs · [返回索引](../CLAUDE.md)

## src/（TypeScript 源码）

| 文件 | 说明 |
|------|------|
| `index.ts` | main()：服务装配、路由挂载、静态托管、监听 |
| `config/serverConfig.ts` | 环境变量集中定义与脱敏打印 |
| `middleware/authMiddleware.ts` | JWT / API Key 凭证校验 |
| `middleware/apiEnabledMiddleware.ts` | 接口可用性开关 |
| `middleware/index.ts` | 导出汇总 |
| `routes/authRoutes.ts` | 注册 / 登录 |
| `routes/syncRoutes.ts` | 加密文件同步（push/pull/list/delete） |
| `routes/pluginSystemRoutes.ts` | 服务端插件管理（商店/ZIP 安装、启停、卸载） |
| `routes/pluginRoutes/index.ts` / `factory.ts` / `routeConfig.ts` / `hooks.ts` / `types.ts` / `utils.ts` | 插件路由工厂与公共件 |
| `routes/pluginRoutes/handlers/` | 19 个插件域 handler（activity、bill、calendar、chat、checkin、contact、day、diary、goods、notes、todo、tracker…）+ `index.ts` 注册表 |
| `services/fileStorageService.ts` | 文件存储基座 |
| `services/authService.ts` | 用户 / JWT / API Key |
| `services/encryptionService.ts` | AES-256-GCM |
| `services/pluginDataService.ts` | 插件数据读写 |
| `services/pluginService.ts` | 服务端插件生命周期 |
| `services/webSocketManager.ts` | WebSocket 连接与推送 |
| `services/fileWatcherService.ts` | chokidar 文件监听 |
| `services/fcmService.ts` | FCM 推送 |
| `services/eventEmitter.ts` | 事件与钩子 |
| `types/index.ts` / `types/plugin.ts` | 类型定义 |

## 其他目录

| 路径 | 说明 |
|------|------|
| `admin-vue/` | 管理面板源码（Vue3 + naive-ui + pinia + Vite），含自己的 package.json（[文档](../admin-vue/CLAUDE.md)） |
| `admin/` | 面板静态产物（随 dist 发布） |
| `bin/aboutme-server.js` | CLI 入口 |
| `plugins/` | 服务端插件（`data-sync-logger-v2` 示例 + `plugin-store.json` 商店清单） |
| `tests/` | jest：api.test.ts、globalSetup/globalTeardown、test_data/ |
| `data/` | 运行时数据目录（本地生成，勿提交） |
| `dist/` | 构建产物（勿编辑） |
| `findings.md` / `progress.md` / `task_plan.md` | 历史工作底稿 |
