# 索引变更记录

> 所属：packages/ · [返回索引](../CLAUDE.md)
> 仅保留最近 5 条。

- **2026-09-02**：第二轮增量：新增 `memento_widgets` 文档集（Dart API、pluginId→Provider 映射、双平台架构）；server-nodejs 补 `admin-vue` 文档集并修正插件 API 描述（19 域 = 12 专用 handler + 7 默认 CRUD，前缀 `/api/v1`）。
- **2026-09-01**：新建 `packages/CLAUDE.md` 聚合索引与 `claude/` 详情（overview / module-responsibilities / dependencies-and-config）；确认 9 个子包清单与 path 依赖接线；为 server-nodejs、mcp-memento-server、api_forwarding_server 生成独立文档集。
- **（更早记录未留档）**：server-nodejs 曾为根目录 Dart 版 `server/`（Shelf 框架），后迁移为 Node.js + TypeScript 实现并移入 packages/；Dart 版目录已删除。
