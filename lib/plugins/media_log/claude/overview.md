# media_log 插件 · 架构总览

> 所属：lib/plugins/media_log · [返回索引](../CLAUDE.md)

## 定位

媒体记录插件（14 个 Dart 文件）：以 `MediaItem`（一本书 / 一部影片）为唯一实体，提供记录的增删改查、过滤搜索排序、瀑布流/列表双视图展示、详情页与多条点评。`MediaLogPlugin extends BasePlugin with JSBridgePlugin`，是"数据 + UI"一体的常规插件，无跨插件依赖（只依赖 core 的数据服务与设计系统组件）。

## 关键设计

- **数据流**：`AboutmeDataService.readPath/writePath('media_log/items.json')` ↔ 内存 `List<MediaItem>` ↔ 两个 screen 经 `addListener/notifyListeners` 订阅刷新。`refreshData` 重载即 `_loadItems + notifyListeners`。
- **首次示例**：items.json 不存在或无 `items` 键时写入 `MediaSampleData.build()`（9 条：5 阅读 + 4 观影，来自 ai_picks_demo 的演示内容）并立即 `_persist`。
- **双列错落瀑布流**：`flutter_staggered_grid_view` 的 `MasonryGridView.count(crossAxisCount: 2)`，偶数项左列、奇数项右列下移 18 并按 `rotation`（-0.025 / 0.02）轻微旋转——迁移自 demo 的手账感。
- **封面体系**：`MediaCoverView` 优先渲染 `coverImage`（AdaptiveImage，相对路径或 URL），否则 `MediaCover`（CustomPaint 按 `CoverStyle` 程序化绘制，墨线配色 `_ink 0xFF2B2B2B / _paper 0xFFF7F3EC` 固定不随主题）。前 12 款书籍风、后 4 款电影感。
- **主题桥接**：插件主视图与独立路由都包 `DSThemeBridge`；经根 Overlay 渲染的部件（导航 actions、DSPopover 排序菜单）需单独再包一层。
- **手绘动效**：详情页用 skribble 的 `WiredDraw` 做标题下划线/圈选的描画入场。

## 接入面

- 注册：`lib/core/builtin_plugins.dart:61`（`MediaLogPlugin()`）。
- 路由：`MediaLogRouteHandler`（`/media_log`、`/media_log/detail?itemId=`），在外部注册于 `lib/screens/route.dart:80`；主入口仍是 `PluginManager.openPlugin` → `/plugin/media_log`。
- JS API：7 个方法 + 7 个别名（见 [public-interfaces](public-interfaces.md)），会被 agent_chat 的 ToolConfigManager 自动扫描生成工具配置。
- 无 home_widgets。
