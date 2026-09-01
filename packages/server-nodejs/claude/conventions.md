# 开发约定

> 所属：packages/server-nodejs · [返回索引](../CLAUDE.md)

## 命令

```bash
npm install
npm run dev              # ts-node-dev --respawn --transpile-only
npm run build            # build:admin（admin-vue 安装+构建）→ tsc → 拷贝 plugins/ 与 admin/ 到 dist
npm start                # node dist/index.js
npm test                 # jest --runInBand（串行，涉及文件系统状态）
npm run test:coverage    # 覆盖率
npm run lint             # eslint src/**/*.ts
```

- 全局安装视角：`npm i -g @hunmer/memento-server` → `memento-server`（`bin/memento-server.js`），首次运行在当前目录创建 `data/`。

## 代码纪律

- 新插件域 API：`src/routes/pluginRoutes/handlers/<plugin>.ts` 实现 handler → 在 `handlers/index.ts` 注册 → 路由由 `factory.ts` 统一生成；不要手写路由样板。
- handler 只做参数解析与调用 `PluginDataService`；业务状态落 `services/`。
- TS 配置见 `tsconfig.json`；eslint 只覆盖 `src/`（admin-vue 有自己的工具链）。
- 日志统一 winston；不要直接 `console.log`（配置打印除外）。

## 运行目录纪律

- `data/`：运行时数据（用户、令牌、API Key、插件数据）——**不要提交**，删除即丢数据。
- `plugins/`：服务端插件源 + `plugin-store.json` 商店清单；构建时整体拷入 `dist/plugins`。
- `dist/`、`admin-vue/node_modules` 为生成物。

## 安全基线

- 生产必须覆盖：`JWT_SECRET`（否则固定开发密钥 + 告警）、`ADMIN_USERNAME` / `ADMIN_PASSWORD`（默认 admin/admin123）。
- 注册开关 `ALLOW_REGISTER` 默认开启，公开部署建议按需关闭。
- 上传限制 10MB（multer，`MAX_REQUEST_SIZE` 默认 10mb）。
