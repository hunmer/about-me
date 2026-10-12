# design_system 手绘风格改造（skribble 包装）

## 用户意图
安装 skribble，把 `lib/design_system/` 全部组件改造为手绘风格。**硬约束：对外 API（组件签名/`AppTheme.of`/令牌）一字不动**——lib/ 下 375 个业务文件 import 了它。

## 核心技术决策
- **不用 skribble 的 Wired\* 高层组件**（它们内嵌 Material 组件，与本项目"无 Material 祖先"的设计系统冲突，且 API 协议不一致），改用 skribble 公开导出的**零 Material 底层手绘原语**：`RoughBoxDecoration`（BoxDecoration 的直接替代）、`WiredCanvas` + painter 基类、rough 引擎（Generator/Filler）、`lookupMaterialRoughIcon`（手绘图标）。这就是"用 skribble 包装实现"。
- 填充（用户已确认）：大容器（卡片/对话框/面板）淡 hachure 排线，小控件（按钮/输入框/勾选框）纯色实底 + 墨色抖动描边。
- 图标（用户已确认）：DsIcon 映射 skribble 手绘图标字体，缺的回退 Material Icons。
- 字体：skribble_font_recursive（零配置自动注册），`DsTypography` 全量注入 `SkribblePlayful`（package 参数必填）+ `fontFamilyFallback`（中文无手绘字形，回退 AlibabaPuHuiTi）。
- 固定 seed：RoughBoxDecoration 传 seed，避免 rebuild 时墨迹随机抖变。
- 果冻 API（jellyGradient/jellyShadow/JellyGlossDecoration 等）保留签名防外部引用编译破坏，内部改为手绘中性值、组件不再调用。

## 步骤

### 0. 环境前置（用户已确认升级）
1. `flutter upgrade`（stable >=3.47，满足 skribble Dart ^3.13）
2. `flutter analyze` 记录升级后基线，修掉因升级产生的 **error**（不追 info/warning）
3. `flutter pub add skribble skribble_font_recursive`
4. 读 pub cache 中 skribble 源码，核实 RoughBoxDecoration/WiredCanvas/lookupMaterialRoughIcon 的确切签名（调研结论以实测为准）

### 1. 主题与令牌（自改，先做——其余全部依赖它）
- `tokens/typography.dart`：所有 TextStyle 加手绘 fontFamily + fallback
- `theme/app_theme.dart`：
  - 新增手绘令牌派生：`ink`（墨线色，isDark→nightText/text）、`paper`、`markerColor`、drawConfig 缓存
  - jelly\* 系列方法签名保留，返回值改中性（如 jellyGradient→[base,base]、jellyShadow→偏移硬阴影）
  - `AppTheme.build` 内包 `WiredThemeScope`（skribble 零 Material 主题边界，WiredCanvas 等组件可取到主题），WiredThemeData 从 AppThemeData 映射
- 新增 `tokens/sketch.dart`：统一手绘装饰构造 helper（RoughBoxDecoration 封装：描边宽度/seed 策略/大容器排线 vs 小控件纯色分档/手绘偏移阴影），全部组件共用

### 2. 质感基底（自改）
- `components/jelly_box.dart`：BoxDecoration→RoughBoxDecoration（18/34 组件经它自动手绘化）；JellyGlossDecoration 保留类名但 paint() 置空

### 3. 组件批量改造（34 个文件，4 组 subagent 并行 + 统一约定）
统一约定：所有自绘 BoxDecoration/渐变/彩色 blur 阴影 → sketch helper；移除高光罩层；API 逐字段不变。
- A 容器类：button、card、checkbox、radio、badge、chips、accordion、stepper、top_bar、empty_state
- B 输入类：input、select、combobox、slider、switch、segmented_control、date_picker
- C 浮层类：dialog、bottom_sheet、toast、tooltip、popover、tabs、progress、loading、skeleton、page_indicator
- D 图形/列表：avatar、rating、list_item、list_item_card、navigation_bar（第三方 radial_disc_bottom_bar 不动，仅注入墨/纸色样式）
- `icons.dart` 自改：DsIconKind(~70)→手绘图标映射表 + 回退

### 4. 验证
- `flutter analyze` 零 error
- 已知坑告知：web release 构建需 `--no-tree-shake-icons`（skribble #198）；skribble 0.x API 未稳

## 验收（给用户）
1. `flutter run -d windows` 任一使用 DS 组件的页面 → 边框/容器/按钮呈手绘墨线 + 排线填充，英文数字为手写字体
2. 任意含 Select/Dialog/Toast 的页面操作正常（浮层链路未破坏）
3. `flutter analyze` 无新增 error

## 后续优化（不在本次）
- navigation_bar 整体手绘化（需动第三方包）
- 手绘转场动画（skribble 的 WiredMotion/RoughDrawing progress）
- 中文手绘字体方案