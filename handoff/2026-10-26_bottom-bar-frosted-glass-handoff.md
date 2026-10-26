# 底部导航栏磨砂玻璃（全局开关 + 参数调节）交接文档

> 日期：2026-10-26 ｜ 状态：顶部渐进模糊已通过像素回归，待应用实机确认（未 commit）

## 一、功能概述

为弧形圆盘底栏（`packages/radial_disc_bottom_bar`，应用侧封装为 `DSBottomNavigation`）新增**全局磨砂玻璃面板**：

- 设置 → 主题背景设置 → 「底部导航栏」组：磨砂玻璃开关（默认开）+ 三个参数滑条
- 开启后：一块**占满屏幕宽度、顶部圆角、向下延伸贴屏幕底**的磨砂面板衬在 dock 之下，页面内容在面板区域被背景模糊 + 淡纸色 tint 覆盖
- 面板顶部用**分段递增 sigma**由清晰渐入磨砂；纸色从完全透明渐入，所有参数即时生效并持久化

## 二、需求演进（为什么是现在这个形态）

| 轮次 | 需求 | 结论 |
| --- | --- | --- |
| 1 | 设置页加开关，控制底栏磨砂（默认开） | 初版只关了包内扇环级 `frosted` |
| 2 | 磨砂要覆盖整个占位区域，不只扇环 | 改为外层整域 BackdropFilter |
| 3 | 出现整屏磨砂 bug | 见 §4.1，补 ClipRect 限定范围 |
| 4 | 面板占满屏宽 + 顶部左右圆角 | OverflowBox 突破宿主宽度，见 §4.3 |
| 5 | 边缘羽化 | dilate 配方起步，观感不足后加大参数 |
| 6 | 羽化后圆角轮廓仍清晰可见（渐变方式不对） | dilate / erode 都不能改变裁剪边缘的 alpha，旧 erode 结论已纠正，见 §4.2 |
| 7 | 参数暴露到设置页 | 模糊强度 / 边缘羽化 / 渐变长度三个滑条 |
| 8 | ShaderMask 后只剩白底、光晕后仍有清晰边界 | 移除遮罩和光晕，改为实际背景模糊强度渐入，增加像素回归 |

## 三、涉及文件

| 文件 | 改动 |
| --- | --- |
| `lib/core/services/bottom_bar_style_controller.dart` | **新增**。单例 ChangeNotifier，持久化磨砂参数（仿 `HandDrawnStyleController` 模式），配置键 `bottom_bar_style` |
| `lib/design_system/components/navigation_bar.dart` | `DSBottomNavigation` 接入：build 包 ListenableBuilder 监听控制器；磨砂开启时叠加全宽羽化面板；包内 `frosted` 恒传 `false`（避免双重 backdrop 采样），扇环纸色半透明填充保留 |
| `lib/design_system/components/bottom_bar_frost_panel.dart` | 实际磨砂层：不重叠条带渐入 sigma、共享原始 backdrop、透明起点纸色渐变；debug 模式输出实际参数和分段数 |
| `test/bottom_bar_frost_panel_test.dart` | 对比真实渲染像素：硬边/软边、24/48 羽化、关闭模糊、参数拉满；可选导出对照 PNG |
| `lib/core/app_initializer.dart` | 启动时 `StartupTrace.measure('bottom_bar_style', BottomBarStyleController().initialize)` |
| `lib/screens/settings_screen/screens/theme_background_settings_screen.dart` | 「底部导航栏」组：开关 SettingsTile + `_buildFrostSlider` 三个滑条（样式仿手绘动画时长滑条） |
| `lib/screens/settings_screen/l10n/settings_screen_translations_zh.dart` / `_en.dart` | 新增 key：`settings_screen_bottomBarGroupTitle` / `...FrostedTitle` / `...FrostedSubtitle` / `...BlurTitle` / `...FeatherTitle` / `...FadeTitle` |

## 四、关键技术决策（踩坑记录，重要）

### 4.1 BackdropFilter 的作用范围 = 最近祖先裁剪，不是自身 bounds

裸 `BackdropFilter` 不裁剪时，模糊会沿渲染树向上扩散到最近的裁剪边界（无裁剪则到 viewport）——曾导致**整屏磨砂**。结论：

- 任何 BackdropFilter 必须用 `ClipRect`/`ClipRRect` 等祖先裁剪限定范围；
- 本实现中外层 `ClipRRect` 限定面板轮廓，每个条带内部的 `ClipRect` 再限定各自滤镜的作用范围。

### 4.2 羽化必须渐入实际背景模糊强度

- 旧文档关于 erode 能羽化裁剪边缘的结论错误：dilate / erode 处理背景像素的形态学极值，不能把面板的硬裁剪改成 alpha 渐隐；erode 还会令背景颜色发脏。
- `ShaderMask` 的离屏层会影响 `BackdropFilter` 的背景采样；仅模糊白色光晕也无法改变原滤镜硬切入的问题。
- 当前实现把顶部过渡带分成不超过 2 逻辑像素的条带，sigma 按 easeInOut 从接近零递增到设定值，主体只保留一个完整 sigma 滤镜。羽化 48 时最多 24 段 + 主体。
- 各段不重叠，并共享 `BackdropKey`，避免后续条带采样已经处理过的背景。
- 纸色从 alpha=0 渐入，渐变长度至少覆盖羽化带，避免另加一层固定透明白底重新制造硬边。
- `featherRadius=0` 恢复硬边；`blurSigma=0` 且 tint 透明时画面与原背景一致。

### 4.3 面板铺满屏宽：OverflowBox 突破宿主约束

宿主容器通常窄于屏宽（`CustomBottomBar` 外壳仅 0.85 屏宽），面板用 `Positioned.fill + OverflowBox(alignment: topCenter, minWidth/maxWidth: 屏宽, minHeight/maxHeight: _frostPanelHeight=500)` 突破限制。要点：

- 面板必须是 `Positioned`（非 Positioned 的 OverflowBox 尺寸会参与 Stack 尺寸计算，撑大占位）；
- 外层 `Stack(clipBehavior: Clip.none)` 允许溢出绘制；
- 面板高度 500 是「足够大」策略：顶部对齐 dock 顶、底部延伸出屏，超出 viewport 的部分被自然裁掉，无需精确测量 dock 到屏底的距离；
- dock 叠在面板之上（Stack children 顺序：面板在前、bar 在后），子栏展开/折叠时面板顶随 dock 顶同步移动。

### 4.4 包内 frosted 恒传 false

整域磨砂开启后，包内扇环级 `ClipPath + BackdropFilter` 属于同区域第二次 backdrop 采样，浪费且无视觉收益，故 `RadialDiscBottomBar.frosted` 固定传 `false`；扇环纸色半透明填充（`fillColor: paper alpha 0.7/0.8`）由 `DSBottomNavigation` 侧继续设置，保持扇环与外围玻璃的层次感。

### 4.5 生效逻辑

`实际磨砂 = 调用点 frosted 参数 && 全局开关`。`entry_list.dart` 等显式传 `frosted: false` 的调用点不受全局开关影响（开关只做全局关闭，不强制开启）。

## 五、参数与持久化

配置键 `bottom_bar_style`（`globalConfigManager.getPluginConfig/savePluginConfig`）：

| 字段 | 含义 | 范围 | 默认 | 对应设置项 |
| --- | --- | --- | --- | --- |
| `frosted` | 磨砂开关 | bool | `true` | 磨砂玻璃开关 |
| `blurSigma` | 背景模糊强度 sigma | 0–30 | 12 | 模糊强度 |
| `featherRadius` | 顶部实际模糊强度渐入宽度（逻辑像素） | 0–48 | 24 | 边缘羽化 |
| `tintFade` | 纸色渐入长度（占面板高比例） | 0–0.5 | 0.2 | 渐变长度 |

固定常量：顶部圆角 20、tint 浓度浅色 0.18 / 深色 0.22、`_frostPanelHeight` 500。

## 六、验收步骤

1. 设置 → 主题背景设置 → 底部导航栏：开关默认开，开启后显示三个滑条
2. 带底栏页面（如日记主页）：磨砂面板左右贴屏、顶部圆角、底部贴屏底不可见
3. 顶部边缘：由清晰渐入磨砂，圆角轮廓不可辨（对照：羽化滑条拖 0 出现硬边）
4. 拖动滑条即时生效；重启后开关与参数保持
5. 关闭开关后面板完全消失，扇环恢复非磨砂绘制

自动回归：`flutter test --no-pub test/bottom_bar_frost_panel_test.dart test/bottom_bar_position_test.dart`。
需要查看渲染对照时添加 `--dart-define=FROST_PREVIEW=true`，输出到 `outputs/bottom_bar_frost/`。
运行时日志前缀为 `[BottomBarFrost]`，包含实际 sigma、羽化像素、分段数、tintFade 和面板尺寸。

## 七、已知限制与后续优化

- **宿主依赖**：全宽面板依赖各宿主祖先链 `Clip.none`（`CustomBottomBar` 链路已验证）；若有调用点把 `DSBottomNavigation` 放进带裁剪的窄容器，面板两侧会被裁
- **`_frostPanelHeight=500`**：若某宿主把底栏抬离屏底超过 ~354px，面板底边会悬空露出直角边，届时调大该常量或改为动态测量
- **滑条写盘频率**：拖动过程每次 notify 都落盘配置，如感写放大可加防抖（松手才 `_save`）
- **性能**：顶部多段真实模糊比单滤镜成本高；已限制最多 24 段，仍需在低端设备上观察滚动帧耗
- 顶部圆角 20 / tint 浓度目前为固定常量，未暴露设置项
