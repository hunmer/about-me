# 标准页面结构规范

参考实现：`lib/plugins/checkin/screens/checkin_list_screen/checkin_list_screen.dart`

## 总览

一个标准页面自上而下由三部分组成：

```
┌─────────────────────────────────────┐
│  SuperCupertinoNavigationWrapper    │  ← 页面导航栏（大标题/搜索/过滤/操作按钮）
│  （内部含 PersistentNavigationBar） │
├─────────────────────────────────────┤
│                                     │
│              body                   │  ← 页面内容（Expanded 包裹，可滚动）
│                                     │
├─────────────────────────────────────┤
│  DSBottomNavigation                 │  ← 根级弧形圆盘底部导航（仅宿主页）
└─────────────────────────────────────┘
```

交互约定：

| 操作 | 方式 |
| --- | --- |
| 新建/快捷操作 | 底部 sheet：`SmoothBottomSheet` |
| 打开子页面 | `NavigationHelper.push*` 平台路由，导航栏走 hero 过渡 |
| 弹窗 | `showDSDialog` |

## 1. SuperCupertinoNavigationWrapper — 页面导航栏

定义：`lib/widgets/super_cupertino_navigation_wrapper.dart`

所有普通页面的统一导航入口，封装大标题、搜索栏、多条件过滤栏、底部栏与主题样式。**新页面优先用它，不要手写 Scaffold AppBar。**

最小结构（摘自 checkin_list_screen）：

```dart
return SuperCupertinoNavigationWrapper(
  title: Text('checkin_name'.tr),          // 导航栏折叠态标题
  largeTitle: 'checkin_checkinListTitle'.tr, // 大标题（enableLargeTitle 控制显隐）
  body: Column(
    children: [
      // 固定不随列表滚动的表头（可选）
      const CheckinWeekdayHeader(),
      Expanded(
        child: SingleChildScrollView( /* 列表内容 */ ),
      ),
    ],
  ),
  // ===== 搜索（可选）=====
  enableSearchBar: true,
  searchPlaceholder: 'checkin_searchPlaceholder'.tr,
  onSearchChanged: (query) => controller.onSearchChanged(query),
  searchBody: _buildSearchResults(searchResults), // 聚焦/有内容时替换 body
  // ===== 多条件过滤栏（可选）=====
  enableMultiFilter: true,
  multiFilterItems: _buildFilterItems(), // List<FilterItem>
  onMultiFilterChanged: _handleFilterChanged,
  enableLargeTitle: false,
);
```

常用参数：

- `actions` / `largeTitleActions`：导航栏操作按钮
- `enableLargeTitle`：大标题模式；列表页可设 false 直接显示小标题
- `previousPageTitle`：返回按钮旁的前页标题文字
- `transitionBetweenRoutes`：导航栏是否参与路由 hero 转场，默认 true

注意：

- **`title` 一律传纯文本 `Text`**（折叠态标题/hero 渐变依赖文本提取），不要传图标 Widget；图标只用于 `largeTitleActions`/`actions` 等按钮位
- **同一路由下嵌套第二个 wrapper（如 tab 内嵌页）必须传 `transitionBetweenRoutes: false`**，否则两个导航栏的默认 Hero tag 冲突。

## 2. PersistentNavigationBar — 嵌入式导航栏

定义：`packages/super_cupertino_navigation_bar/lib/utils/persistent_nav_bar.dart`

`SuperCupertinoNavigationWrapper` 内部使用的固定高度（56）导航栏，走 `SafeArea(top)` + `NavigationToolbar`（leading / middle / trailing）布局。只有当 wrapper 无法满足需求时才直接使用它，例如编辑页要在自定义布局中嵌入一行固定导航（见 `lib/plugins/scripts_center/screens/script_edit_screen.dart:731`）：

```dart
PersistentNavigationBar(
  components: NavigationBarStaticComponents(
    keys: _navBarKeys,
    route: null,
    userLeading: Align(   // NavigationToolbar 紧约束会拉变形按钮，用 Align 转宽松
      alignment: AlignmentDirectional.centerStart,
      child: DSIconButton(icon: DsIconKind.chevronLeft, ...),
    ),
    userMiddle: ..., userTrailing: ...,
  ),
);
```

约束：直接放进 Column 等宽松父级时必须依赖其内部 `SizedBox(height: 56)`，勿在外层再去掉高度约束。

## 2.1 DSLightHeader — 轻量手绘顶栏

定义：`lib/design_system/components/light_header.dart`

不需要 wrapper 完整能力（大标题/搜索/过滤栏）的简单子页面——表单页、详情页等自定义布局页——用 `DSLightHeader` 自绘顶行（返回圆钮 + 居中标题 + 尾部动作），不要手写重复的 Row，也不要退回 Material AppBar：

```dart
Column(
  children: [
    DSLightHeader(
      title: 'contact_editContact'.tr,
      trailing: DSIconButton(   // 尾部动作（可选）：38px 圆形按钮位
        icon: DsIconKind.trash,
        size: 38,
        color: theme.surface,
        iconColor: theme.danger,
        onPressed: _showDeleteConfirm,
      ),
    ),
    Expanded(child: /* 页面内容 */),
  ],
)
```

要点：

- 返回圆钮默认 `Navigator.maybePop`，可用 `onBack` 覆盖；iOS 侧滑返回由 `NavigationHelper.push` 的路由提供，与顶栏无关
- `trailing` 为 null 时保留与返回钮等宽（38）的占位，标题恒居中；尾部动作区固定 38 宽，只放圆形按钮
- 需要 AppTheme 祖先：页面外层包 `DSThemeBridge`，颜色走 `theme.surface/text`，勿在组件内硬编码
- 顶栏自带 `horizontal:16, vertical:10` 内边距，外层勿再叠加水平 padding（参考实现：`lib/plugins/contact/widgets/contact_form.dart`、`lib/plugins/contact/screens/contact_detail_screen.dart`）

## 3. DSBottomNavigation — 弧形圆盘底部导航

实现：`lib/design_system/components/navigation_bar.dart`，底层包 `packages/radial_disc_bottom_bar`

同心圆弧 dock + 沿切线滑动的选中药丸，可选磨砂玻璃扇环。**只用于根级宿主页（tab 容器），子页面不放底部导航。**

```dart
DSBottomNavigation(
  items: [DSNavItem(icon: DsIconKind.home, label: '首页'), ...],
  currentIndex: currentIndex,
  onTap: (i) => ...,
  floatingAction: addBtn,      // 子栏右圆钮位置的常驻浮动钮（如"添加"）
  subLabels: ('日', '周'),      // 上层子栏双选项（与 subActions 互斥）
  frosted: true,               // 磨砂玻璃
);
```

要点：

- 子栏元素（`subLabels` / `subActions` / `leadingAction` / `trailingAction`）随 tab 动态出现的宿主应恒传 `subBarBehavior: RadialSubBarBehavior.auto`，避免占位高度跳变
- `subBarVisible` 手动控制子栏显隐时，子栏元素需常驻（不随 tab 增删）才有弹簧折叠动画

## 4. 新建/快捷操作用 sheet

定义：`lib/widgets/smooth_bottom_sheet.dart`（基于 smooth_sheets 包，全 app 底部弹层统一入口）

新建入口（如列表页"+"）不跳页面，弹出底部 sheet：

```dart
SmoothBottomSheet.showWithTitle(
  context: context,
  title: '新建打卡',
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SmoothSheetAction(icon: DsIconKind.add, label: '手动创建', onTap: ...),
      SmoothSheetAction(icon: DsIconKind.close, label: '删除', destructive: true, onTap: ...),
    ],
  ),
);
```

自带：流畅拖拽动画、下拉滑动关闭、遮罩点击关闭、拖拽把手、标题行。布局规范：**标题靠左显示，操作按钮列表在右侧**（`showWithTitle` 的 `actions` 底部右对齐；`showForm` 的删除/保存按钮在标题行右侧）。`SmoothSheetAction` 操作行（`destructive: true` 为红色危险操作）。无标题场景用 `SmoothBottomSheet.show`，表单场景用 `showForm`。

## 5. 打开子页面用 hero 过渡

子页面跳转统一走 `NavigationHelper`（`lib/core/navigation/navigation_helper.dart`）：

```dart
NavigationHelper.push(context, DetailScreen(...), routeName: '/detail');
// 或命名路由
NavigationHelper.pushNamed(context, '/checkin_detail', arguments: {'id': itemId});
```

- iOS 用 `CupertinoPageRoute`（支持左滑返回），其他平台 `MaterialPageRoute`
- 路由转场时导航栏做 hero 渐变过渡（上一页标题渐隐、本页标题渐显），由 wrapper 的 `transitionBetweenRoutes`（默认 true）驱动，**页面无需手写 Hero**
- 嵌套 wrapper 的内层必须 `transitionBetweenRoutes: false`（见第 1 节）

## 6. 颜色：禁止硬编码，一律走主题

**不要在页面/组件里写死 `Color(0xFF...)`、`Colors.white` 等背景颜色**，否则深色模式下必然出错。统一通过主题取色：

```dart
// 页面/插件侧：经桥接获取 design_system 主题
final theme = DSThemeBridge.resolve(context);

Container(
  color: theme.surface,      // 页面/卡片背景
  // theme.surfaceAlt        次级背景、按压态
  // theme.primary/onPrimary 主题色及其上前景
  // theme.text / textSub    主/次文字
  // theme.danger            危险操作
  // theme.barrier           遮罩
);
```

要点：

- 需要 `Theme`/暗色联动的小片段可用 `DSThemeBridge(child: Builder(...))` 局部注入（见 checkin_list_screen 过滤栏 trailing 的用法）
- design_system 包内部组件用 `AppTheme.of(context)` 取色
- 仅允许在主题定义处（`design_system` 的 theme token）出现具体色值；透明度衍生用 `theme.xxx.withValues(alpha: ...)`

## 7. 文案：一律 I18N，禁止硬编码中文/英文字符串

**不要在代码里写死用户可见文案**，统一用 GetX 翻译键：

```dart
Text('checkin_name'.tr)
Text('app_cancel'.tr)
Text('screens_errorHabitNotFound'.trParams({'id': itemId}))  // 带参数
```

翻译键定义位置与命名：

| 范围 | 文件 | 键前缀 |
| --- | --- | --- |
| 应用级 | `lib/l10n/app_translations_{zh,en}.dart` | `app_` |
| 插件级 | `lib/plugins/<plugin>/l10n/<plugin>_translations_{zh,en}.dart` | `<plugin>_`（如 `checkin_`） |

要点：

- 参数化文案用 `@paramName` 占位，调用侧 `.trParams({...})`
- **新增键必须同时补 zh 和 en 两个文件**，缺一个会直接显示键名
- 键名用 `<前缀>_<页面/模块>_<语义>` 层级命名（如 `checkin_searchPlaceholder`）

## 8. 列表筛选与排序：统一走多条件过滤栏

列表页的筛选/排序**不放 header actions 图标弹层，也不放 body 内通栏按钮**，统一收敛到 wrapper 的多条件过滤栏（参考实现：`lib/plugins/goods/screens/goods_list_screen.dart`、`lib/plugins/store/widgets/store_view/product_list.dart`）：

```dart
SuperCupertinoNavigationWrapper(
  // ...
  enableMultiFilter: true,
  multiFilterItems: _buildFilterItems(),       // List<FilterItem>（filter_models.dart）
  onMultiFilterChanged: _applyMultiFilters,    // postFrameCallback + setState 存入 _multiFilters
  multiFilterBarTrailing: _buildSortButton(),  // 排序入口（可选）：过滤栏尾部圆形按钮
);
```

要点：

- 筛选项用 `FilterItem` + `FilterType`（tagsSingle / tagsMultiple / input / dateRange / checkbox / custom），常用 UI 直接调 `FilterBuilders`（`filter_builders.dart`），选中态 badge 走 `getBadge`；两者由 `super_cupertino_navigation_wrapper/index.dart` 导出
- **排序入口是过滤栏第一层尾部的圆形图标按钮**（`JellyBox` 36×36 circle + `DsIconKind.sort`，点击 `DSPopover` 弹菜单），不放 header actions
- 过滤判断集中一个 `_passesMultiFilters(item)`，数据链路：原始列表 → 多条件过滤 → 排序 → 搜索
- 经根 Overlay 展示的 DS 组件（`DSPopover`、过滤栏内的 `DSChip` 等）需包 `DSThemeBridge` 提供主题
- 启用 `enableMultiFilter` 后搜索栏默认收起，由 header 右上切换按钮同时展开过滤栏与搜索框（`multiFilterToggleable` 默认 true）

## 9. 手绘风格（skribble 纸墨风）：新 UI 一律走 design_system 统一工具

全 app 视觉为手绘纸墨风（skribble rough 引擎绘制墨线）。新建 UI **不要**自己写 BoxDecoration 圆角描边、渐变、柔影，也不要混搭 Material 风格卡片——统一从 `package:aboutme/design_system/design_system.dart` 取工具，风格（墨色/笔刷/粗糙度/seed）自动与全局一致。

### 9.1 容器分档（最重要）

| 场景 | 用法 | 视觉 |
|---|---|---|
| 小控件（按钮/输入框/勾选框/徽章） | `dsSketchDecoration(theme, fillColor: 主题色, radius: ...)` | 纯色实底 + 墨线抖动描边 |
| 大容器（卡片/对话框/面板/浮层） | `DsSketchPanel(theme, radius, padding, child)` | 纸底 + 淡主色排线 + 墨线框 |
| 通用容器基底 | `JellyBox(color: ...)`（已手绘化） | 实底 + 墨线描边，pill(999) 自动胶囊 |

要点：

- `dsSketchDecoration` 返回 `RoughBoxDecoration`（`Decoration` 子类），直接给 `Container.decoration`；描边贴容器真实边界，padding 只作用于内容（勿在外层再包 padding 压描边层）
- **数据/深色实底卡陷阱**：`DsSketchPanel(fillColor: 数据色)` 若同时 `hachure: false`，装饰层走 solid 实底且色值取 `hachureColor ?? theme.hatch`——必须把同一数据色同时传 `hachureColor`，否则所有卡被统一刷成主题排线色
- 优先直接用现成 DS 组件（`DSButton`/`DSCard`/`DSInput`/`DSSelect`/`showDSDialog`/`showDSToast`…），API 与旧版完全一致，视觉已全局手绘化；底部 sheet 统一用 `SmoothBottomSheet`（`lib/widgets/smooth_bottom_sheet.dart`，见第 4 节）

### 9.2 颜色 / 字体 / 图标

- 颜色：`theme.ink`（墨线）、`theme.paper`（纸底）、`theme.hatch`（排线淡彩）、`theme.primary` 等——一律 `AppTheme.of(context)` / `DSThemeBridge.resolve(context)` 取，禁止硬编码
- 派生墨色给 Wired* 组件局部变色：`DsInkScope(border: theme.danger, child: WiredButton(...))`
- 字体：全局 `TegakiZatsu`（851 手写杂书体，中/英/日）；`DsTypography.*` 已内置，勿另设 fontFamily
- 图标：一律 `DsIcon(DsIconKind.xxx)`（内部 `WiredIcon` 自动套手绘几何，未收录自动回退）；新增图标先补 `DsIconKind` 枚举映射，不要在页面直接用 `Icon(Icons.x)`

### 9.3 禁止项（破坏风格统一）

- ❌ `boxShadow` 柔影 / blur 阴影（手绘风无柔影，层次靠排线与墨线）
- ❌ `LinearGradient`/玻璃高光类渐变装饰（实底或排线替代）
- ❌ 直接用 skribble 的 `Wired*` 高层组件做新 UI（内嵌 Material 控件、API 协议不同）；确需时必须包 `DsInkScope` 取色
- ❌ 手写 `BoxDecoration(border: Border.all(...))` 直角/圆角描边替代墨线

### 9.4 全局档位与 seed

- 墨线粗糙度三档全局可切（设置 → 界面 → Ink style）：Gentle / Playful（默认）/ Expressive；由 `DsInkStyle.level` 驱动，`theme.wired.drawConfig` 自动跟随，新 UI 无需关心
- `seed` 保持默认即可（rebuild 墨迹不抖变）；列表项可传 `seed: index` 让墨迹有变化

### 9.5 统计图表（小组件）：斜纹数据填充，清晰优先

小组件里的统计图表（仪表盘 / 进度条 / 柱图 / 分段占比等）在纸墨风下取"清晰"与"手绘感"的平衡点：**数据区不用 rough 抖动墨线**（太潦草，读数困难），**也不用纯色实底填充**（丢失手绘气质），统一用平直几何 + 数据色斜纹填充——当前这套风格是标准，勿再加粗抖动或退回纯色块。

| 元素 | 用法 |
|---|---|
| 数据区（进度弧 / 柱 / 分段） | 数据色浅底（alpha 0.28）+ 数据色斜纹（alpha 0.9）+ 数据色描边（alpha 0.85） |
| 轨道 / 未选中段 | `theme.surfaceAlt` 底 + 淡墨斜纹（ink alpha 0.28）+ 淡墨描边（ink alpha 0.45） |
| 卡片容器 | `WiredDraw` + `DsSketchPanel`（§9.1 大容器档），禁柔影 |
| 图例色块 | `dsSketchDecoration(fillColor: 数据色)`（§9.1 小控件档），禁彩色柔影 |
| 指针 / 刻度 / 文字 | 指针 `theme.ink` 实心小几何；刻度与文字 `theme.text / textSub` |

斜纹标准纹样（全局一致，勿各自发明参数）：

- 右上斜线：水平/垂直斜率 `0.85`；横向间距 `6.5 × scale`
- 浓纹（数据区）宽 `3 × scale`，淡纹（轨道）宽 `1.5 × scale`
- 一律调公共 `paintDiagonalStripes`（`lib/screens/widgets_gallery/common_widgets/utils/striped_fill.dart`），接受任意裁剪 Path（扇环 / 胶囊 / 矩形通用），勿在组件里手写条纹循环

要点：

- rough 墨线只上容器边框、徽章等装饰层；图表数据几何（弧段、柱形、扇环）保持平直干净，保证读数清晰
- 数据色走 props（如 `activeColor` / 分段 `color`，支持 hex 解析），属数据不属于主题；其余颜色一律走主题
- 参考实现：`lib/screens/widgets_gallery/common_widgets/widgets/half_gauge_card.dart`（斜纹半圆仪表盘）、`segmented_progress_card.dart`（斜纹分段进度条）、`striped_weekly_chart_card.dart`（斜纹柱状图）

## 10. 手绘入场动画（ink 描画，skribble motion）

新内容挂载时让墨线"画出来"：描边先描（0–65%），排线/图案填充随后浮现（30–100%），纸底、实底填充、文字、图标与布局全程稳定。默认 650ms `easeInOutCubic`。参考实现：`lib/plugins/nodes/widgets/node_item.dart`（节点展开）、`node_card.dart`（卡片墨线消费进度）。

### 10.1 两个入口组件

| 组件 | 用法 | 适用 |
|---|---|---|
| `WiredDraw(child: ...)` | 包住**新挂载**的子树，挂载即播一次（收起卸载、再展开自动重播） | 展开子树、新增列表项等内容入场 |
| `WiredDrawTransition(progress: 动画)` | 直接把墨线进度接到自有 AnimationController | 需要反向、stagger 错峰等显式控制时 |

### 10.2 墨线如何消费进度

- DS 装饰：`dsSketchDecoration(..., progress: WiredDrawTransition.progressOf(context))`
- 自定义 CustomPainter：`repaint` 挂动画、绘制时传进度：

```dart
_MyPainter({required this.progress}) : super(repaint: progress);
final Animation<double>? progress;
// paint 内：
RoughDrawing(d, paint, paint).paint(canvas, progress: progress?.value ?? 1, pressure: 0);
```

- `progressOf` 返回 null（外层无 WiredDraw / 动画被禁用）＝ 立即全画，天然向后兼容：同一组件在动画场景与非动画场景可复用
- `Wired*` 自带组件（checkbox、button 等）自动跟随环境进度，无需处理
- `DsSketchPanel` 尚未接进度；其场景可改用 `dsSketchDecoration` 直挂或后续扩展

### 10.3 约定

- 只做**入场**描画；收起/退出不播反向动画（直接卸载）
- 不要用内容淡入淡出替代——skribble 的形态就是"纸面已在，笔迹画上"
- 自动遵守 `WiredMotion(enabled: false)` 边界与系统"减弱动态效果"，无需额外处理
- 全局时长/开关由根节点 `WiredMotion(enabled / drawDuration)` 统一下发（`packages/skribble` 为本地 vendor 副本，补丁加了 drawDuration 级联）；设置页「入场动画时长」可调，0 = 关闭，调用点不传 `duration` 自动跟随
- 弹层（`showDSDialog`/`DSPopover`）如需描画，应在其**组件内部**统一包 `WiredDraw`，一处生效全 app 复用

## 11. 手绘便签列表/网格（随机倾斜 + 贴条）

页面主体的内容浏览列表/网格（数据条目列表、卡片墙、瀑布流）一律用便签组件：每个 item 以确定性随机角度轻微倾斜（±1.2°~2.6° + ±6px 水平偏移），顶部带 skribble 贴条，鼠标悬浮"拿起"（角度归零 + 放大 1.04 + 上移）。统一从 `package:aboutme/widgets/hand_drawn_list_view.dart` 取，禁止自行实现 Transform.rotate + 随机数。

### 11.1 组件选型

| 场景 | 用法 |
|---|---|
| 纵向内容列表 | `HandDrawnListView`（替代 ListView.builder/separated，参数同名） |
| 网格 / 瀑布流（GridView、MasonryGridView、SliverMasonryGrid、StaggeredGrid） | cell 的 itemBuilder 返回值外包 `HandDrawnStickyItem` |
| 自带贴条样式的卡片（如 notes） | `HandDrawnStickyItem(showTape: false)` 只保留倾斜与悬浮 |

```dart
// 列表：tiltKeyOf 必须传数据稳定 id（禁止传 index）
HandDrawnListView(
  itemCount: items.length,
  separatorBuilder: (c, i) => const SizedBox(height: 16),
  tiltKeyOf: (i) => items[i].id,
  itemBuilder: (c, i) => ItemCard(item: items[i]),
);

// 网格 cell：
HandDrawnStickyItem(tiltKey: item.id, child: ItemCard(item: item))
```

### 11.2 硬规则

- **倾斜取样**：`tiltKey`/`tiltKeyOf` 传数据模型稳定字符串 id——角度由 `handDrawnUnitRandom`（字符串哈希）确定性生成，过滤/排序重排后同 id 角度不变；禁止用 index（重排即跳变）
- **间距 ≥ 16**：贴条顶部出血 12px，item 纵向间距（separator / mainAxisSpacing）不足 16 的必须补足，否则贴条压盖上一个卡片；横向间距无此要求
- **顶部出血**：`HandDrawnListView` 自动在 padding 顶部追加出血边距，勿手动加；自行包 `HandDrawnStickyItem` 的滚动容器需手动保证顶部 ≥ 12px
- **层级顺序**：`HandDrawnStickyItem` > `WiredDraw` > 卡片；滑删（Dismissible/SwipeActionWrapper）等手势组件放 StickyItem 内、卡片外
- **拖拽排序**（ReorderableListView/ReorderableGridView）：cell 的 `key` 必须上移到 `HandDrawnStickyItem` 上（列表要求 key 在直接子级）
- **窄卡片**（≤ 120px 宽，如 4 列主页小卡）：传小号贴条 `tapeWidth: 56, tapeHeight: 18`，或 `showTape: false` 只倾斜

### 11.3 贴条样式（`HandDrawnTapeStyle`，可扩展）

| 样式 | 视觉 | 参数 |
|---|---|---|
| `centerTape`（默认） | 顶部居中胶带：墨线 + 不透明纸底 + 三个圆孔 | `tapeColor`（默认米白；可按索引回调传数据色）、`holeColor` |
| `folderTab` | 左上角文件夹标签页：墨线纸底 + 标题文字，叠在卡体上沿 | `tapeTitle`（标题）、`tapeColor: theme.primary` + `tapeLabelColor: theme.onPrimary`（选中态） |

新增样式 = 加枚举值 + `_build` 分支，勿在页面里自绘贴条。

### 11.4 不适用（禁止套用便签化）

- ❌ 时间对齐型视图：日程格子（拖选时间段）、时间轴刻度列表——倾斜破坏时刻对齐
- ❌ 聊天消息流、下拉建议列表、横向滚动条
- ❌ 对话框/弹层内的列表、设置/表单页的滚动容器
- ❌ 卡片内部的紧凑小列表（属卡片内容，不是页面主体）

## 新建页面检查清单

1. 页面根组件用 `SuperCupertinoNavigationWrapper`（title + body 必填）
2. body 内容用 `Expanded` 包裹，可滚动区域底部留 `MediaQuery.paddingOf(context).bottom` 安全区
3. "新建"类入口用 `SmoothBottomSheet`，不放导航按钮跳转
4. 子页面用 `NavigationHelper.push*`，享受平台转场 + 导航栏 hero
5. 嵌套第二层 wrapper 时传 `transitionBetweenRoutes: false`
6. 根级宿主页才放 `DSBottomNavigation`，子页面不放
7. 颜色全部来自 `DSThemeBridge.resolve(context)`，无硬编码色值
8. 所有用户可见文案走 `.tr` / `.trParams`，zh/en 翻译文件同步补齐
9. 列表筛选/排序走多条件过滤栏（`enableMultiFilter`），排序入口用过滤栏尾部圆形按钮；导航栏 `title` 传纯文本 `Text`
10. 手绘风格统一：容器用 DS 组件或 `dsSketchDecoration`/`DsSketchPanel`（小控件纯色实底、大容器纸底排线）；无 boxShadow/渐变；图标走 `DsIcon`；颜色走 `theme.ink/paper/hatch`，不硬编码
11. 展开/折叠、新增列表项等**新内容挂载**场景用 `WiredDraw` 包裹子树做墨线描画入场（见第 10 节）；静态常驻内容不加动画
12. 页面主体的内容浏览列表/网格用 `HandDrawnListView` / `HandDrawnStickyItem` 便签化（倾斜 + 贴条 + 悬浮，见第 11 节）：`tiltKey` 传数据稳定 id、纵向间距 ≥ 16；时间对齐视图/聊天流/弹层列表/设置表单不套用
13. 统计图表类小组件：数据区用平直几何 + 数据色斜纹（`paintDiagonalStripes` 标准纹样），rough 墨线只上容器/徽章，禁纯色块填充数据区（见第 9.5 节）
