# 索引变更记录

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)
> 本文件只记录 AI 上下文索引的生成/更新，与产品 Changelog 无关。仅保留最近 5 条。

- **2026-09-14**：第四轮增量（结构变更同步）：`packages/api_forwarding_server` 与 `packages/mcp-aboutme-server` 已删除（修复根索引失效链接；MCP 并入 server-nodejs `/mcp`，工具数核实为 12 域 75 个）；WebDAV 同步通道与 `webdav_client` 依赖移除（改 `http_storage` 后端）；新增插件 live2d（25→26）、默认首页 `screens/jelly_home`（initialRoute）、本地包 `agentlib`/`super_cupertino_navigation_bar`、`widgets/form_fields`（50 文件）；版本号重置为 0.0.1；根目录散稿（findings/progress/task_plan/Aboutme.ipa）已清理；测试增至 6 个；docs 71→67 篇；同步更新 packages 与 lib 两级索引及详情。
- **2026-09-05**：第三轮增量：新建 `lib/plugins/` 聚合文档（CLAUDE.md + claude/ 7 文件：插件体系架构/25 插件职责/约定/入口/路由全景/目录速查）；chat 与 agent_chat 旧版单文件 CLAUDE.md 重写为"索引+详情"格式（各 5 个详情文件）；全量 grep 验证 25 插件主类（发现 6 个直接继承 PluginBase、chat JS API 未挂接的迁移中间态）；修正根索引过时数字（1943→1823 Dart 文件、test/ 已有 3 个冒烟测试）。
- **2026-09-02**：第二轮增量补扫：新增 `lib/plugins/reminder`、`packages/aboutme_widgets`、`packages/server-nodejs/admin-vue`、`online/` 四组文档（18 个文件）；修正 server-nodejs 插件 API 描述（19 域 = 12 专用 handler + 7 默认 CRUD，前缀 `/api/v1`）；根索引与各上层索引同步更新。
- **2026-09-01**：按"索引 + 详情拆分"策略重建根级文档：根 `CLAUDE.md` 改为轻量索引，长内容拆入 `claude/` 11 个详情文件；修正失效引用（`server/` 已删除 → `packages/server-nodejs`，端口 8080 → 8874）；新增 `packages/`、`lib/`、`shared_models/` 及三个 Node 子包的文档集；确认内置插件为 25 个（补记无文档的 `reminder`）。
- **2025-12-31**：为 Dart 版同步服务器（`server/`，现已移除）与 `lib/screens` 生成文档；根索引加入 25 插件链接。
