# 索引变更记录

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)
> 本文件只记录 AI 上下文索引的生成/更新，与产品 Changelog 无关。仅保留最近 5 条。

- **2026-09-02**：第二轮增量补扫：新增 `lib/plugins/reminder`、`packages/aboutme_widgets`、`packages/server-nodejs/admin-vue`、`online/` 四组文档（18 个文件）；修正 server-nodejs 插件 API 描述（19 域 = 12 专用 handler + 7 默认 CRUD，前缀 `/api/v1`）；根索引与各上层索引同步更新。
- **2026-09-01**：按"索引 + 详情拆分"策略重建根级文档：根 `CLAUDE.md` 改为轻量索引，长内容拆入 `claude/` 11 个详情文件；修正失效引用（`server/` 已删除 → `packages/server-nodejs`，端口 8080 → 8874）；新增 `packages/`、`lib/`、`shared_models/` 及三个 Node 子包的文档集；确认内置插件为 25 个（补记无文档的 `reminder`）。
- **2025-12-31**：为 Dart 版同步服务器（`server/`，现已移除）与 `lib/screens` 生成文档；根索引加入 25 插件链接。
- **2025-12-17**：完成 calendar 插件文档。
- **2025-12-12**：Database 插件迁移到 UseCase 架构。
