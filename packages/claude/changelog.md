# 索引变更记录

> 所属：packages/ · [返回索引](../CLAUDE.md)
> 仅保留最近 5 条。

- **2026-10-25**：后续优化轮：**aboutme_data_sdk 与 aboutme_server 首次独立建档**（各 CLAUDE.md 索引 + claude/ 10 详情，见各包 claude/changelog.md）；packages/CLAUDE.md 模块索引两包链接从 README 改指 CLAUDE.md，修正过时数字（"12 插件处理器"→33 handler 文件/28 封闭域；"19 插件 API"→各域业务 API；"68 工具"→tools.dart 为事实源）；扫描状态移除"两包源码未深扫"。
- **2026-10-14**：第六轮增量（对齐 server-nodejs 移除事实）：overview/module-responsibilities/dependencies 三件套重写——现行服务器链路改为 `aboutme_data_sdk`（数据核心）+ `aboutme_server`（薄壳，MCP 68 工具，托管 admin-vue 面板）；**server-nodejs 已于同日彻底删除**（2026-10-11 平移 → 2026-10-14 目录移除），全部表述从"已废弃"改为"已删除"并清除死链；子包结构 10→13（补 radial_disc_bottom_bar/material_emoji_picker/data_sdk/server，减 server-nodejs）；path 依赖接线与配置章节同步（现行配置 `aboutme_server/lib/src/config.dart`）。同日上层 [packages/CLAUDE.md](../CLAUDE.md) 已更新。
- **2026-09-14**：第四轮增量：`api_forwarding_server/` 与 `mcp-aboutme-server/` 已从仓库删除（MCP 并入 server-nodejs 内置端点，工具数更新为 12 域 75 个）；新增 `agentlib/`（AI 传输门面，替代 openai_dart 依赖）与 `super_cupertino_navigation_bar/` 两个 Dart 库条目；overview 改为"1 Node 服务 + 2 Dart 库 + 6 原生插件"三类结构。
- **2026-09-02**：第二轮增量：新增 `aboutme_widgets` 文档集（Dart API、pluginId→Provider 映射、双平台架构）；server-nodejs 补 `admin-vue` 文档集并修正插件 API 描述（19 域 = 12 专用 handler + 7 默认 CRUD，前缀 `/api/v1`）。
- **2026-09-01**：新建 `packages/CLAUDE.md` 聚合索引与 `claude/` 详情（overview / module-responsibilities / dependencies-and-config）；确认 9 个子包清单与 path 依赖接线；为 server-nodejs、mcp-aboutme-server、api_forwarding_server 生成独立文档集。
- **（更早记录未留档）**：server-nodejs 曾为根目录 Dart 版 `server/`（Shelf 框架），后迁移为 Node.js + TypeScript 实现并移入 packages/；Dart 版目录已删除。
