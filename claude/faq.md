# 常见问题（FAQ）

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

**Q：同步服务器在哪里？旧文档说 `cd server && dart run bin/server.dart`？**
A：过时。Dart 版 `server/` 目录已删除，现行服务器是 `packages/server-nodejs`（Node.js + TypeScript，默认端口 **8874**）。启动：`cd packages/server-nodejs && npm run dev`。

**Q：`api_forwarding_server` / `mcp-aboutme-server` / WebDAV 同步去哪了？**
A：均已删除（2026-09-09 前后）。MCP 能力并入 server-nodejs 内置端点 `POST /mcp`；WebDAV 同步被自建服务器 HTTP 存储后端（`lib/core/storage/http_storage.dart`）取代，`webdav_client` 依赖已移除。旧文档提及这些内容的章节一律视为过时。

**Q：如何新增一个功能插件？**
A：① `lib/plugins/<name>/` 创建 `*_plugin.dart` 继承 `BasePlugin`（可 mixin `JSBridgePlugin`）；② 在 `lib/core/builtin_plugins.dart` 的 `_builders` 注册；③ 在 `lib/screens/routing/routes/<name>_routes.dart` 注册路由并在 `route.dart` 汇总；④ 需要同步/复用时在 `shared_models/` 定义 Repository 接口与 UseCase；⑤ 需要服务端 API 时在 `packages/server-nodejs/src/routes/pluginRoutes/handlers/` 添加 handler。

**Q：桌面小组件（Home Widget）相关代码在哪？**
A：原生实现在 `packages/aboutme_widgets`（Android/iOS）；客户端侧在 `lib/core/app_widgets/` 与 `lib/core/services/plugin_widget_sync_helper.dart`；文档见 `docs/WIDGET_ARCHITECTURE_UNIFIED.md`、`docs/WIDGET_IMPLEMENTATION_GUIDE.md` 等。

**Q：AI 集成有几条路径？**
A：① 应用内 `lib/plugins/openai`（多服务商）与 `lib/plugins/agent_chat`（工具调用，工具定义在 `lib/plugins/agent_chat/tools/`）；② 外部 AI 工具走 server-nodejs 内置 MCP 端点 `POST /mcp`（Streamable HTTP，`aboutme_{plugin}_{action}` 工具）；③ `online/agents.json` 为 Agent 配置示例。

**Q：AI 回复"变慢/分条/有时不回"是怎么回事？（aliveness 活人感）**
A：agent 开启 alivenessConfig 后消息进入 `lib/plugins/openai/aliveness/` 编排器：先缓冲（时长随亲密度/惰性变化）再决策（Jev 或本地规则，允许已读不回）→ 分条气泡或语音。排查入口：决策日志页（`aliveness/screens/decision_log_screen.dart`）与 `openai/aliveness/<agentId>/decisions.log`。详见 [openai 子系统职责](../lib/plugins/openai/claude/module-responsibilities.md)。

**Q：Live2D 相关代码在哪？**
A：数据与设置在 `lib/plugins/live2d/`，渲染核心（JellyLive2D，约 1180 行）与在线模型目录在 `lib/screens/jelly_home/`——两边互相引用，改渲染要同时验证插件预览。`/live2d` 路由指向**设置页**。

**Q：JS 脚本 / 小程序生态如何组织？**
A：JS 引擎与 API 桥在 `lib/core/js_bridge/`；用户脚本由 `lib/plugins/scripts_center` 管理；小程序仓库在 `online/apps/`（`apps.json` 清单，WebView 加载）；示例见 `docs/script_examples/`。

**Q：为什么构建不能开图标树摇？**
A：`flutter_config.yaml` 设 `tree-shake-icons: false`——项目使用动态 `IconData`（如桌面小组件图标映射），树摇会在运行时报错。

**Q：国际化支持哪些语言？在哪里加文案？**
A：`zh_CN` / `en_US`（`lib/main.dart` supportedLocales），翻译集中在 `lib/l10n/unified_translations.dart`，使用 GetX `.tr`。

**Q：如何构建发布？**
A：`./scripts/build.sh`（读 `scripts/release_config.json` 选平台）；`scripts/release.sh` 创建 GitHub Release；各平台 CI 在 `.github/workflows/`；Web 版由 `web-deploy.yml` + `vercel.json` 部署 Vercel。

**Q：MCP 服务器连不上 / 需要什么密钥？**
A：MCP 已内置于 server-nodejs，AI 客户端通过 HTTP 连接 `POST /mcp`，每个请求携带请求头 `X-API-Key`（管理面板生成，`mk_live_` 前缀）与 `X-Encryption-Key`。详见 `packages/server-nodejs/README.md` 的 MCP 章节。

**Q：`findings.md` / `progress.md` / `task_plan.md` 是什么？**
A：历史工作底稿，根目录下已清理；`packages/server-nodejs/` 下如仍有一份同样可忽略。`handoff/` 为 Agent 会话交接底稿。

**Q：改服务端后管理面板没更新？**
A：管理面板是独立的 Vue 工程（`packages/server-nodejs/admin-vue/`），`npm run build` 会先执行 `build:admin` 再拷贝到 `dist/admin`；单独改 TS 不会重建面板。
