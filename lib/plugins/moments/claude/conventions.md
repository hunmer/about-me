# 开发约定

> 所属：`lib/plugins/moments/` · [返回索引](../CLAUDE.md)

## UI 约定（手绘纸墨风）

- 组件优先用 `design_system`（`package:aboutme/design_system/design_system.dart`）的 skribble 装饰与主题 token。
- 软糖标签类装饰遵循 `design.md` §9.1：dsSketchDecoration 实底 + 墨线抖动描边（示例 `InterestPill`）。
- 底部弹层一律用 `lib/widgets/smooth_bottom_sheet.dart` 的 `SmoothBottomSheet`（提供标题/把手/关闭），内容体单独成 Widget（如 `MomentsComposeSheet`）。

## SVG 贴纸实现约束

- flutter_svg 的 vector_graphics 后端**不支持 feMorphology 滤镜**（参考稿白描边的实现方式）。
- 本插件的替代方案：主要轮廓路径先画一遍粗白描边、再叠彩色本体，等效烘焙白色 die-cut 边（见 `widgets/moment_stickers.dart` 头注）。新增贴纸沿用此法。

## 国际化

- 文案 key 放 `l10n/moments_translations_{zh,en}.dart`，经 `lib/l10n/unified_translations.dart` 聚合注册到 GetX，使用 `'moments_xxx'.tr`。
- 插件名同样走 l10n（`getPluginName` 返回 `'moments_name'.tr`）。

## 数据访问

- 只通过 `MomentsService.instance`（`ChangeNotifier`，`addListener` 驱动刷新）读写动态；不要在本插件内新增存储。
- 生图/发布等 AI 行为属 openai 插件的工具（`moments_js_api.dart`），本插件 UI 调用对应 Service。
