# 快速新建通用组件指南（widgets gallery）

> 本文沉淀自 2026-10-14 会话：为 `lib/screens/widgets_gallery` 组件库新增两个通用组件（健康环 `HealthScoreRingCard`、花瓣径向图 `PetalRadialChartCard`）的完整流程与踩坑记录。新会话照此清单执行即可，无需重新探索代码库。

## 一、新增一个通用组件的完整步骤

组件名以下统称 `XxxCard`，示例用 `health_score_ring_card` / `petal_radial_chart_card`。

1. **组件文件**：`lib/screens/widgets_gallery/common_widgets/widgets/xxx_card.dart`
   - StatefulWidget（带入场动画，`SingleTickerProviderStateMixin`，参考 `donut_chart_stats_card.dart` 的骨架）
   - 必须提供 `factory XxxCardWidget.fromProps(Map<String, dynamic> props, HomeWidgetSize size)`（注册器统一入口）
   - 数据模型类与组件同文件（如 `HealthRingItemData`）
   - 尺寸适配：构造参数 `HomeWidgetSize size`（默认 `const Large3Size()`）+ `bool inline`（inline 用 `double.maxFinite`，否则固定宽 `384 * size.scale`）
2. **示例页**：`lib/screens/widgets_gallery/screens/xxx_card_example.dart`
   - 惯例：Scaffold + AppBar，灰底 `Color(0xFFF2F2F7)`（深色 black），`SingleChildScrollView` + `_buildSectionTitle` 分节展示各尺寸
   - **演示数据列表不要写 `static const`**（见坑 3），用 `static final`
3. **注册 registry**：`lib/screens/widgets_gallery/common_widgets/common_widgets.dart` 四处
   - import 组件文件
   - `CommonWidgetId` 枚举加值（放末尾）
   - `CommonWidgetsRegistry.metadata` 加元数据（name/description/icon/defaultSize/supportedSizes）
   - `CommonWidgetBuilder.build` 的 switch 加 case
4. **注册路由**：`lib/screens/routing/routes/widget_gallery_routes.dart`
   - import 示例页
   - `routes` 列表加 `RouteDefinition`（path `/widgets_gallery/xxx_card`）
   - 文件底部 `_defaultWidgetItems` 加 `WidgetPreviewItem`（决定「预览所有小组件」页内容）
5. **gallery 首页入口**：`lib/screens/widgets_gallery/screens/home_widgets_gallery_screen.dart` 对应分类 section 加 `_buildListItem`
6. 验证：`flutter analyze <改动文件>`（本仓库改动widget无需全量 build）

## 二、本次产出（可直接参考的样板）

| 内容 | 路径 |
|---|---|
| 环图+列表组件 | `lib/screens/widgets_gallery/common_widgets/widgets/health_score_ring_card.dart` |
| 花瓣径向图组件 | `lib/screens/widgets_gallery/common_widgets/widgets/petal_radial_chart_card.dart` |
| 两组件示例页 | `lib/screens/widgets_gallery/screens/health_score_ring_card_example.dart`、`petal_radial_chart_card_example.dart` |
| 尺寸模型 | `lib/screens/home_screen/models/home_widget_size.dart`（category 决定字号/间距/内边距档位） |
| 图标 codePoint 工具 | `lib/core/utils/icon_utils.dart` 的 `dynamicIconData`（fromProps 解析图标用） |

## 三、踩坑记录（重要）

1. **圆头线帽吃掉间隙**：粗圆环 `StrokeCap.round` 会从弧端点沿切线各延伸 `strokeWidth/2`。间隙弧度 < 线宽时段间仍被"焊死"。解法：画弧时两端各内缩 `capInset = (strokeWidth/2) / radius` 角度，让线帽末端正好落在段边界（见 `health_score_ring_card.dart` 的 `_RingChartPainter`）。
2. **径向图文字重叠**：文字沿分角线排布时必须按"文字块最内侧半径处的弦宽"收缩字号（`2r·sin(半角)·0.88`），只按中心半径算会导致内侧标签溢出到相邻扇形。数值在上/标签在下的**竖排文字块**优于沿半径方向排布（后者在左右两侧花瓣会变成横排"2Anger"）。见 `petal_radial_chart_card.dart` 的 `paint()`。
3. **`static const` 演示数据热重载不生效**：改了数值只 Hot Reload 会看到旧数据，必须 Hot Restart。示例页数据统一用 `static final`；引用非 const 列表的 widget 构造也不能带 `const`（否则 `invalid_constant`）。
4. **花瓣圆角要随尺寸缩放**：固定圆角会让小花瓣（径向长度 20~50px）被"吃"成叶子/团块。`outerRc = clamp(径向长×0.32, 3, 15)`、`innerRc` 小固定值。
5. **多扇形间隙**：每瓣角度内缩 `gap = min(sweep×0.12, 2π×0.02)`，track 底瓣和填充瓣用同一 gap，瓣间才有缝。
6. **动画同步 vs 依次**：环段"依次描边"（总进度扫到哪画到哪）和"全部段 `sweep×progress` 同步生长"视觉差异大，用户明确要求后者。
7. **段方向**：用户要求从正上方开始**逆时针**排列（画布角度递减），与默认顺时针相反。
8. **尺寸布局分支惯例**：`size is SmallSize` → 只画核心图；`size.width > size.height`（宽条）→ 图居左上/左、内容在下/右；其余 Column 图在上内容在下。参考 `donut_chart_stats_card.dart`。

## 四、常用参数速查

- 环段间隙：`_ringGapFraction`（健康环当前 0.025 ≈ 每段间 9°）
- 卡片圆角 `24×scale`、阴影 `black 5% blur 20`；浅色卡片底 `0xFFF7F3EB`（健康环）/ `white`（花瓣图），深色统一 `0xFF1E293B` / `0xFF191919`
- 参考配色（来自效果图）：黄 `#F2CE5F` 绿 `#A9BC69` 粉 `#EFA9D9` 蓝 `#9FB6E8` 橄榄 `#C0C96A`

## Suggested skills

- **diagnose**：组件已能跑但"效果不像参考图"时，用其 reproduce→定位→修复流程处理视觉回归（本会话的多轮修图正属此类）。
- **find-skills**：需要新能力（如截图比对、动画调优）时先查询可安装技能。
- **improve-animations**：对组件入场/生长动画做系统性打磨前，先做动画审计。
- **split-god-files**：若组件文件超 ~400 行（如 `common_widgets.dart` 注册表持续增长），评估拆分而非继续追加。
