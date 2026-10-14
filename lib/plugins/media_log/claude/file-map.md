# media_log 插件 · 文件地图

> 所属：lib/plugins/media_log · [返回索引](../CLAUDE.md)

```text
lib/plugins/media_log/
├── media_log_plugin.dart            # 主类 MediaLogPlugin：内存 items/items.json 读写/listener 通知/首次示例数据
├── media_log_js_api.dart            # part 文件：7 个 JS 方法实现（get/create/update/delete 条目与点评）
├── media_log_route_handler.dart     # /media_log 与 /media_log/detail?itemId= 两个路由
├── sample_data.dart                 # MediaSampleData.build()：首次使用写入的 9 条示例（5 书 + 4 影片）
├── models/
│   └── media_item.dart              # MediaItem / MediaReview / MediaKind / CoverStyle(16 款)
├── screens/
│   ├── media_list_screen.dart       # 列表页：瀑布流网格 ↔ 单列列表切换 + 过滤/搜索/排序 + FAB 新建
│   └── media_detail_screen.dart     # 详情页：Hero 封面 + 统计行 + 简介/标签 + 点评卡（滑动编辑/删除）
├── widgets/
│   ├── media_cover.dart             # MediaCoverView（图片优先）/ MediaCover（16 款 CustomPaint 墨线封面，约 480 行）
│   ├── media_item_card.dart         # 瀑布流卡片：封面（错落旋转）+ 标题/类型行
│   ├── media_item_form.dart         # 新建/编辑条目表单（底部 sheet；编辑模式可带删除入口，返回 'delete' 哨兵值）
│   ├── media_item_list_tile.dart    # 单列列表行（纯展示；滑动操作由调用方 SwipeActionWrapper 注入）
│   └── media_review_form.dart       # 新建/编辑点评表单（author/avatar 不展示、原值透传）
└── l10n/
    ├── media_log_translations_zh.dart  # zh_CN（'media_*' 键，约 69 行）
    └── media_log_translations_en.dart  # en_US
```

## 相关外部文件

- 注册：`lib/core/builtin_plugins.dart:61`（`MediaLogPlugin()`）
- 路由注册：`lib/screens/route.dart:80`（`_pluginRouteHandlers` 内的 `MediaLogRouteHandler()`）
- 数据服务：`lib/core/data/aboutme_data_service.dart`（readPath/writePath，基于 packages/aboutme_data_sdk）
- 复用的全局组件：`lib/design_system/`（DS 组件 + DSThemeBridge）、`lib/widgets/super_cupertino_navigation_wrapper/`（导航栏 Wrapper）、`lib/widgets/swipe_action/swipe_action_wrapper.dart`（滑动操作）、`lib/widgets/adaptive_image.dart`、`lib/widgets/picker/image_picker_dialog.dart`（封面选图）、skribble 包（WiredDraw 手绘动效）、flutter_staggered_grid_view 包（瀑布流）
