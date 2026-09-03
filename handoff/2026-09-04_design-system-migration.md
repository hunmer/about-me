# Handoff: Material → 设计系统(DS)组件渐进式迁移

- 日期: 2026-09-04
- 仓库: `/Users/Zhuanz/Documents/Aboutme` (Flutter, branch: `main`, 工作区有未提交改动)
- 会话目标: 参考 `lib/screens/design_system_gallery/design_system_gallery_screen.dart`,逐步把现有 Material 组件替换为 `lib/design_system` 里的组件;基础组件缺失则补充;顺序: home_grid → /chat → /diary → 表单对话框 → 深层子组件。

## 一、项目背景与关键架构

设计系统 `lib/design_system` 是自绘"软糖果冻风"组件库,**仅依赖 flutter/widgets.dart,零 Material 组件**。组件通过 `AppTheme.of(context)` 读取 `AppThemeData` 令牌(亮/暗两套),**取不到时抛空指针**。展示页 `/design_system` 可看全部组件用法。

### 核心设施(本会话新增/扩展)

| 文件 | 作用 |
|---|---|
| `lib/core/widgets/ds_theme_bridge.dart` | `DSThemeBridge` widget:读 Material 亮暗,向下提供对应 AppThemeData(幂等,已存在同亮度 AppTheme 则透传)。**放在 core 而非 design_system,保持 DS 零 Material 依赖**。还有静态 `DSThemeBridge.resolve(context)`:任意 context 上永不抛错地解析主题(有 AppTheme 用之,否则按 Material 亮暗派生) |
| `showDSDialog`(dialog.dart) | 本会话新增可选 `theme` 参数:调用点不在 AppTheme 树内(独立路由)时显式传入,配合 `resolve` 使用 |
| `DSDialog` | 本会话新增 `confirmVariant` 参数(删除类操作传 `DSButtonVariant.destructive`) |
| `DSFab` | 新增 `color`/`iconColor` 覆盖参数 |
| `DSSkeleton` | 新增 `radius` 参数 |
| `DsIconKind` | 新增 14 种:drag/layers/block/edit/tag/clock/refresh/sort/hash/grid/list/video/columns/rows |

### 三个必须遵守的运行时陷阱(analyze 查不出)

1. **桥之上的 context**:屏幕在 build 里包 `DSThemeBridge` 后,State 自己的 context 仍在桥**之上**——用它调 `AppTheme.of`/`showDSDialog` 会崩。解法:桥内套 `Builder` 取 context 再用;或 `showDSDialog(theme: DSThemeBridge.resolve(context))`。已按此模式改好的示例:`home_grid.dart`、`channel_dialog.dart`、`diary_calendar_screen.dart`。
2. **Overlay/Hero 重挂载**:`SuperCupertinoNavigationWrapper`(第三方 super_cupertino_navigation_bar)把 `actions` 经 Overlay/Hero flight 重建到页面主题树之外——放进 actions 的 DS 组件必须**各自包一层 DSThemeBridge**(见 `timeline_screen.dart`/`tags_screen.dart` 的注释)。`flutter_floating_bottom_bar` 不用 Overlay,FAB 不用包。
3. **flutter_test 怪癖**:同一 testWidgets 内连续 pumpWidget 替换根 MaterialApp,新 themeMode 不生效——明暗断言要拆成独立用例。

## 二、已完成(未提交,全部通过验证)

验证基线:`flutter analyze` **0 error,123 条 warning/info 与迁移前完全一致**;`flutter test test/design_system_bridge_smoke_test.dart` **10/10 通过**(覆盖桥接、HomeGrid 空态/骨架/批量选中、Overlay 场景、showDSDialog 无桥调用点、resolve 明暗、全部 47 个自绘图标渲染)。

### 第 1 轮:home_grid → /chat → /diary 主屏
- `home_grid.dart`:图标/SnackBar/AlertDialog(三按钮→竖排 DSButton)/空态/骨架/拖拽装饰全部 DS 化,material 导入已移除
- `/chat` = `ChatBottomBar`(FAB→DSFab 保留插件色、Tab 图标→DsIcon);timeline(视图切换 DSIconButton、3 处 loading→DSLoadingDots、Card→DSCard);tags(排序 PopupMenuButton→hash/clock 两态切换按钮、空态→DSEmptyState)
- `/diary` = `diary_calendar_screen`(编辑按钮/FAB→DSButton/DSFab 保留 hero key、硬编码 Dusty Rose→令牌、日历单元格令牌化)

### 第 2 轮:表单对话框(用户强调的重点)
- `channel_dialog.dart`:完整表单→JellyBox+DSInput(手动校验经 errorText)+DSButton;加载圈→DSLoadingDots
- `profile_edit_dialog.dart`、`delete_channel_dialog.dart`(DSDialog destructive)、`diary_editor_screen.dart`(心情选择果冻表情格、删除确认、红色 DSIconButton)
- 调用点 6 处 showDialog→showDSDialog(chat_bottom_bar、channel_list_screen×2、chat_screen、ui_service、diary)

### 第 3 轮:home 对话框 + chat 深层组件
- `create_folder_dialog.dart`(DSInput+FocusNode 实现 autofocus+图标/颜色选择果冻化)、`quick_create_dialog.dart`、`stack_direction_dialog.dart`(RadioListTile→选中态果冻卡,columns/rows 图标)
- `tag_card.dart`→DSCard;`timeline_message_card.dart`(Card→令牌 Container、25 处主题引用映射:primary→primary,onSurface→text,onSurfaceVariant→textSub,surface→surface,textTheme.*→DsTypography.*)

### 刻意保留的 Material 组件(有原因,勿"顺手替换")
- 持久化/动态 `IconData`(folder.icon、CircleIconPicker、QuickCreateItem.icon、fileInfo.getIcon())——DsIcon 只接受静态 DsIconKind
- 结构性组件:`Scaffold`、`TabBarView`、`ReorderableListView`、`RefreshIndicator`、`InkWell`(涟漪)、第三方(CustomBottomBar、SuperCupertinoNavigationWrapper、SfCalendar、InfiniteCarousel)——DS 无等价物
- `toastService.showToast`(独立服务,非 Material 组件)

## 三、剩余工作(按价值排序)

1. **`lib/screens/home_screen/widgets/folder_dialog.dart`**(597 行,53 处 Material)——主页文件夹详情,量最大
2. **`widget_settings_dialog.dart`**(522 行,31 处)——表单,DSInput/DSSelect/DSSwitch 适配
3. **`add_widget_dialog.dart`**(609 行)、**`layout_manager_dialog.dart`**(380 行)
4. `CustomBottomBar` → `DSBottomNavigation` 骨架替换——**需处理 TabController 驱动 TabBarView**,动静大,建议单独一轮
5. chat 其余:ChannelTile 的子组件、MessageBubble/message_input 目录、各 message 对话框(edit_message_dialog、clear_messages_dialog、date_picker 系列)、timeline_message_card 内的 AudioPlayerWidget 配色
6. `home_date_bar.dart`、`date_view_grid.dart`、`plugin_grid.dart` 等 home_screen 其余 widget
7. 收尾:`home_screen_view.dart`/`chat_screen.dart`/`ui_service.dart` 被整体 dart format 过(原本未格式化),提交时 diff 偏大属正常

## 四、给下一个 agent 的操作建议

- 改动前先读目标文件的 Material 引用:`grep -n "Theme\.of\|Icons\.\|showDialog\|AlertDialog\|TextField\|Card(\|IconButton\|CircularProgressIndicator" <file>`
- 对话框迁移套路(照抄 `channel_dialog.dart` 即可):`showDSDialog(context, theme: DSThemeBridge.resolve(context), builder: (_) => DSThemeBridge(child: Builder(builder: (ctx) { final theme = AppTheme.of(ctx); return JellyBox(...); })))`
- 独立路由(非 TabBarView 内)的调用点**必须**传 `theme: DSThemeBridge.resolve(context)`
- 每轮收尾:`dart format` 改动文件 → `flutter analyze`(0 error 且总数不超 123)→ `flutter test test/design_system_bridge_smoke_test.dart`
- 新图标先看 `icons.dart` 的 24x24 画布惯例(线条 stroke 2.3 圆头);const 数字列表要写 `16.0` 防 num 推断错误
- UI 名词对照:DS 颜色语义 primary/secondary/success/warning/danger/text/textSub/surface/surfaceAlt/stroke/disabled;排版 DsTypography.display/title/heading/body/caption/button/label

## 建议使用的 skills(suggested skills)

- `mattpocock-skills:implement` —— 按本文"剩余工作"清单逐项实现时的规范流程
- `mattpocock-skills:code-review` —— 每轮迁移后对照本 handoff 的"陷阱"清单自查
- `mattpocock-skills:diagnosing-bugs` —— 若运行期再现 `Null check operator`(AppTheme.of)问题,先用本文"三个陷阱"定位
- `planning-with-files` —— 第 4 项(CustomBottomBar 骨架替换)动静大,建议先做任务拆解

## 参考物(不重复其内容)

- 组件 API 全集: `lib/design_system/design_system.dart`(barrel)与 `lib/design_system/components/`
- 用法示范: `lib/screens/design_system_gallery/sections/*`(buttons/controls/inputs/pickers/data/feedback/navigation/extended)
- 回归测试: `test/design_system_bridge_smoke_test.dart`
- 未提交 diff: `git diff`(基线 e933d2e)
