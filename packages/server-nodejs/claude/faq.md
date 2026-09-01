# 常见问题（FAQ）

> 所属：packages/server-nodejs · [返回索引](../CLAUDE.md)

**Q：默认端口是多少？**
A：**8874**（`PORT` 可覆盖）。旧文档写 8080 的是已删除的 Dart 版服务器。

**Q：改了 TS 代码，管理面板没变化？**
A：面板是独立 Vue 工程。`npm run build` 会先 `build:admin`；只跑 `tsc` 不会重建面板。面板单独调试用 `cd admin-vue && npm run dev`。

**Q：启动后数据在哪？如何备份？**
A：`DATA_DIR`（默认 `./data`）纯文件存储。备份即拷目录；管理面板支持 ZIP 导出（adm-zip/archiver）。

**Q：如何给 AI 工具（MCP）开权限？**
A：管理面板生成 API Key（`mk_live_` 前缀），配置到 `packages/mcp-aboutme-server/.env` 的 `ABOUTME_API_KEY` 与 `ABOUTME_ENCRYPTION_KEY`。

**Q：如何新增一个插件域的 REST API？**
A：`src/routes/pluginRoutes/handlers/<name>.ts` 写 handler → `handlers/index.ts` 注册 → `factory.ts` 自动生成路由。详见 [开发约定](conventions.md)。

**Q：JWT 报无效 / 一直过期？**
A：检查 `JWT_SECRET` 是否在重启间保持一致；有效期默认 36500 天（`TOKEN_EXPIRY_DAYS`），一般不会过期。

**Q：注册接口 403？**
A：`ALLOW_REGISTER=false` 时关闭注册；默认开启。

**Q：上传大文件失败？**
A：multer 上限 10MB（`MAX_REQUEST_SIZE` 默认 10mb，upload 与 body 共用该配置）。

**Q：服务端插件从哪安装？**
A：管理面板或 `pluginSystemRoutes`：从商店（`plugins/plugin-store.json`）拉取，或上传 ZIP；插件用 hookable 挂 before/after 钩子，示例见 `plugins/data-sync-logger-v2`。
