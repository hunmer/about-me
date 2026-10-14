# media_log 插件（媒体记录）

[根目录](../../../CLAUDE.md) > [lib](../../) > [plugins](../) > **media_log**

媒体记录插件（14 个 Dart 文件）：阅读记录 + 观影记录——双列错落瀑布流封面网格（手绘纸墨风），支持多条件过滤/搜索/排序、单列列表滑动操作、条目详情与多条带时间戳的点评。封面优先用用户上传图片，否则按 `CoverStyle`（16 款）程序化 CustomPaint 绘制墨线插画。UI 迁移自 ai_picks_demo。

## 约定的规则

- 数据持久化在 `media_log/items.json`（经 AboutmeDataService 读写）；首次使用（无数据）自动写入 `MediaSampleData.build()` 的 9 条示例（5 书 + 4 影片）并落盘。
- JS API 遵循全局命名约定 `get/create/update/delete{Entity}`，且每个方法都注册一个不带 `Media` 前缀的别名（如 `getMediaItems` 与 `getItems` 同函数）。
- 封面 Hero 动画 tag 用 `MediaItem.coverHeroTag`（`media_cover_$id`），列表卡片与详情页必须共用，保证两端一致。
- 点评（MediaReview）可多条、按 timestamp 倒序；`author/avatar` 字段预留给 AI 评论，人工表单不展示、编辑时原值透传。
- 变更通知走插件自带的轻量 listener（`addListener/removeListener/notifyListeners`），两个 screen 均以此驱动 setState。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 数据流、瀑布流/列表双视图、封面体系 | 第一次接触本插件 |
| [对外接口](claude/public-interfaces.md) | JS API（7 方法 + 7 别名）、路由 | 对接或扩展接口 |
| [数据模型](claude/data-model.md) | MediaItem/MediaReview 字段、CoverStyle、存储 | 改数据结构 |
| [文件地图](claude/file-map.md) | 14 文件速查 + 相关外部文件 | 找代码 |
| [索引变更记录](claude/changelog.md) | 本文档更新历史 | 重复运行 /init-project 时 |

## 扫描状态

- 更新时间：2026-10-14（第六轮：首次生成）。
- 已扫描：全部 14 文件（插件主类与 JS API、路由处理器、模型、两屏、5 组件、l10n）、注册点、存储路径、示例数据。
- 未深扫：media_cover.dart 16 款封面的具体绘制细节、l10n 文案内容。
