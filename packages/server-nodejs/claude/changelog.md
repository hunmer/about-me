# 索引变更记录

> 所属：packages/server-nodejs · [返回索引](../CLAUDE.md)
> 仅保留最近 5 条。

- **2026-09-02**：第二轮增量：补扫 admin-vue（生成独立文档集与 `/api/v1` 端点对照）；修正插件数据 API 描述——routeConfig 配置 19 个插件域，其中 12 个专用 handler、7 个默认 CRUD，REST 前缀 `/api/v1`。
- **2026-09-01**：新建本包文档集（CLAUDE.md 索引 + claude/ 9 个详情文件）；梳理 19 个插件 handler、9 个 service、环境变量全集与 jest 测试设置；确认默认端口 8874。
- **（历史，未留档）**：由根目录 Dart（Shelf）版同步服务器迁移为 Node.js + TypeScript 实现并移入 `packages/`，Dart 版目录删除。
