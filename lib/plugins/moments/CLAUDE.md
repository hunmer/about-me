# moments/ 朋友圈插件

朋友圈插件（2026-10 从 openai 插件内独立为第 29 个内置插件）：UI 壳复刻 skygram 参考稿的两块界面——动态流与个人主页，整体走手绘纸墨风设计系统（skribble 装饰 + die-cut 贴纸）。数据与 agent 朋友圈完全复用 openai 侧的 `MomentsService`（活人感/MomentsService 同源），本插件不持有数据层。

- 主类：`MomentsPlugin`（id `moments`），`initialize()` 仅做 `MomentsService.instance.loadPosts()`。
- 宿主页三页签在一处容器内切换（动态流 / 回忆 / 我的主页），不跳路由；agent 个人主页是 push 的子页面。
- 路由：`/moments`、`/moments/profile?agentId={id}`（无 agentId 为「我」）。

## 约定的规则

- 数据/模型/JS API 不在本插件：改数据结构去 `lib/plugins/openai/moments/`，改 AI 工具去 `openai/moments_js_api.dart`。
- UI 组件用设计系统手绘装饰（如 `InterestPill` 遵循 design.md §9.1：dsSketchDecoration 实底 + 墨线抖动描边）。
- flutter_svg 不支持 SVG feMorphology 滤镜，白描边贴纸用"粗白描边先画再叠彩色本体"烘焙（见 `widgets/moment_stickers.dart` 头注）。
- 文案一律走 `l10n/moments_translations_{zh,en}.dart`，由 `lib/l10n/unified_translations.dart` 聚合。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [插件总览](claude/overview.md) | 页面结构、与 openai 数据层的分工 | 第一次接手本插件 |
| [开发约定](claude/conventions.md) | 手绘 UI 约定、贴纸实现方案、l10n | 改 UI 之前 |
| [入口与路由](claude/entrypoints.md) | 注册链、路由表、小组件注册 | 排查打不开/初始化问题 |
| [对外接口](claude/public-interfaces.md) | 路由、小组件、依赖的 openai 服务与 JS 工具 | 对接或扩展 |
| [索引变更记录](claude/changelog.md) | 本目录文档更新历史 | 重复运行 /init-project 时 |

## 扫描状态

- 更新时间：2026-10-20（第七轮：插件独立后首次建档，13 个源文件全量扫描）。
- 未深扫：无（本目录已全量）；相关联的 `openai/moments/` 数据层见 openai 插件文档。
