# 新插件「手账 (scrapbook)」实施计划

## 概览
- 插件 id：`scrapbook`，中文名「手账」，出现在插件列表（走 `PluginManager.openPlugin` 主入口，无需路由注册）
- 数据流：列表页（手账卡片墙）→ 点击打开全屏画布编辑页 → 编辑内容自动保存（debounce）
- 存储：`AboutmeDataService.instance.call('scrapbook', action, params)`。插件 id 未在 `handler_factory.dart` 注册时自动落到通用 CRUD（`getList/getById/create/update/delete`，数据存 `plugins/scrapbook/data.json` 的 `items`）——**零 SDK 改动**
- UI 遵循 design.md：`SuperCupertinoNavigationWrapper` + `HandDrawnListView` 便签化列表、`SmoothBottomSheet` 新建、`showDSDialog` 删除确认、颜色走 `DSThemeBridge`、文案走 l10n（zh/en 同步）

## 一、组件最小扩展（向后兼容，所有新参数可选，widgets_gallery 示例行为不变）

### 1. `scrapbook_item_models.dart`（补序列化）
- `ScrapItemData.toMap()`：全字段序列化（颜色 → `#RRGGBB` 字符串，与现有 `_parseColor` 对称）
- `ScrapStroke`：补 `toMap()` / `fromMap()`（`{color, points: [[x,y],...]}`），构造改为可 const 保留

### 2. `scrapbook_canvas_card.dart`（持久化挂点）
- 新增可选参数：`initialStrokes`（恢复涂鸦）、`onChanged(void Function(List<ScrapItemData>, List<ScrapStroke>)?)`（内容变更通知）、`onClose(VoidCallback?)`（Back pill 接管退出，未注册保持现状"重置视图+toast"）
- `_nextId()` 改用 `DateTime.now().microsecondsSinceEpoch` 生成，避免重开画布后新元素 id 与已存 id 冲突
- `initState` 用 `initialStrokes` 初始化 `_strokes`
- 变更通知点（调用 `onChanged`）：添加条目、删除条目、旋转、条目拖动结束（`onPanEnd`，新增）、涂鸦结束（`onPanEnd`，新增）；平移缩放视图不通知
- Save pill 保持现有 toast（演示反馈），真实保存由插件侧根据 `onChanged` debounce 完成

### 3. `spatial_list_card.dart`（列表卡片打开入口）
- 新增可选参数 `onOpen`：非空时 header 右侧（itemCount 旁）显示小编辑图标按钮，点击回调打开手账；未注册时完全现状
- 已知取舍：卡片展开后的物品暂用组件默认装饰（食品 SVG，纯装饰不影响数据），手账条目 → 缩略图映射列为后续优化

## 二、新插件文件（`lib/plugins/scrapbook/`，7 个文件）

### 4. `models/scrapbook_page.dart`
- `ScrapbookPage`：`id/title/subtitle/items(List<ScrapItemData>)/strokes(List<ScrapStroke>)/createdAt/updatedAt`，`toMap()/fromMap()`（items/strokes 复用上面补的序列化）
- 摘要辅助：提取首个 text 条目内容、条目计数（供列表卡片）

### 5. `services/scrapbook_repository.dart`
- 封装 `AboutmeDataService.instance.call('scrapbook', ...)` 的 getList/create/update/delete
- `onPluginChanged('scrapbook', cb)` 订阅远端变更刷新

### 6. `screens/scrapbook_list_screen.dart`（列表页，design.md 规范）
- `SuperCupertinoNavigationWrapper`：title `'scrapbook_name'.tr`，大标题，`largeTitleActions` 放"+"按钮
- body：`HandDrawnListView` + `HandDrawnStickyItem(tiltKey: page.id)`，每项为 `SpatialListCardWidget(inline: true, title: 手账标题, subtitle: 副标题, updatedLabel: 相对时间, itemCount: 条目数, noteContent: 摘要, onOpen: 打开画布页)`，间距 ≥16
- 滑动删除（`Dismissible` 放 StickyItem 内、卡片外）+ `showDSDialog` 确认
- 空态：手绘提示文案
- 新建：`SmoothBottomSheet.showForm`（标题输入 `DSInput`）→ 创建（预置一个 header 条目：日期 + 标题，画布不空）→ 直接打开画布页

### 7. `screens/scrapbook_canvas_screen.dart`（画布编辑页）
- 全屏 `ScrapbookCanvasCardWidget(inline: true, items, initialStrokes, onChanged, onClose)`——组件自带 Back/Save/导出/FAB 工具层，不再叠加 header
- `onChanged` → debounce ~800ms 调 `update` 自动保存；`onClose` → 保存后 `Navigator.pop`
- 外层 `PopScope` 处理系统返回时 flush 保存

### 8. `scrapbook_plugin.dart`（主类，参考 personal_assistant）
- `extends BasePlugin`：`id='scrapbook'`、icon、color、`getPluginName => 'scrapbook_name'.tr`、`buildMainView => ScrapbookListScreen()`

### 9-10. `l10n/scrapbook_translations_zh.dart` / `_en.dart`
- 约 15 键：`scrapbook_name`(手账/Scrapbook)、新建表单标题/占位/按钮、空态、删除确认标题/正文、相对时间（刚刚/n分钟前/n小时前/昨天/n天前，参数化）、保存成功/失败 toast 等

## 三、注册（2 处小改）

### 11. `lib/core/builtin_plugins.dart`
- import 主类 + `_builders` 加 `() => ScrapbookPlugin()`

### 12. `lib/l10n/unified_translations.dart`
- import zh/en 两个翻译文件 + `zhDict.addAll(scrapbookTranslationsZh); enDict.addAll(...)`

## 不做（后续优化）
- 深链路由 / JS API / 桌面小组件（媒体日志式完整接入）
- 相册选照片入画布（现保留 Unsplash 示例图 + 贴纸/文字/涂鸦）
- 手账条目 → 列表卡片缩略图映射
- 涂鸦撤销、多人 companions/gift 条目编辑

## 验收步骤
1. `flutter analyze`（或 `dart analyze lib/plugins/scrapbook lib/core/builtin_plugins.dart lib/l10n/unified_translations.dart`）无新告警
2. 运行 app → 插件列表出现「手账」→ 打开为空列表
3. "+"新建"测试手账" → 自动进入画布 → 拖动/添加贴纸文字/涂鸦 → Back 退出
4. 列表出现新卡片（标题/条目数/时间正确）→ 点编辑按钮重进画布，内容还原
5. 重启 app，数据仍在；滑删手账 → 确认弹窗 → 列表移除