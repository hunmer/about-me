# Handoff: Material → 设计系统(DS)组件渐进式迁移

- 日期: 2026-09-04(第 3 轮会话末更新)
- 仓库: `D:\about-me`(Flutter, branch: `main`, 工作区有未提交改动,~82 文件)
- 验证基线:`flutter analyze` **0 error,123 条 warning/info 与迁移前完全一致**;`flutter test test/design_system_bridge_smoke_test.dart` **10/10 通过**(含 60 个自绘图标回归)。
- 会话脉络:第 1-2 轮完成 home_grid → /chat 主屏 → /diary → 表单对话框;第 3 轮完成 home_screen 其余 widget、chat 全部深层组件、CustomBottomBar 内部令牌化,并把**全部应用代码的 `AppTheme.of` 换成 `DSThemeBridge.resolve`**。

## 一、项目背景与关键架构

设计系统 `lib/design_system` 是自绘"软糖果冻风"组件库,**仅依赖 flutter/widgets.dart,零 Material 组件**。组件通过 `AppTheme.of(context)` 读取 `AppThemeData` 令牌(亮/暗两套)。展示页 `/design_system` 可看全部组件用法。

### 核心设施

| 文件 | 作用 |
|---|---|
| `lib/core/widgets/ds_theme_bridge.dart` | `DSThemeBridge` widget:读 Material 亮暗,向下提供对应 AppThemeData(幂等)。静态 `DSThemeBridge.resolve(context)`:**任何 context 上永不抛错**(有 AppTheme 用之,否则按 Material 亮暗派生) |
| `showDSDialog`(dialog.dart) | 对话框路由,内部已用 AppTheme 包裹 builder 内容;`theme:` 参数用于调用点显式传入 |
| `showDSDatePickerDialog`(date_picker.dart) | DSDatePicker + 确认按钮的便捷对话框(按钮文案为硬编码中文,DS 无 i18n) |

### 调用规约(本会话已全量落地)

**应用代码一律用 `DSThemeBridge.resolve(context)` 取令牌,禁止 `AppTheme.of(context)`**(53 文件 116 处已全换,git grep 零残留;仅 `lib/design_system/**` 内部保留 of)。由此历史上的"三个运行时陷阱"中:

1. ~~桥之上的 context 崩溃~~ —— 已免疫(resolve 永不抛错)。曾崩溃实例:diary_calendar_screen 的 SfCalendar `monthCellBuilder` 回调用 State context 取 `AppTheme.of`。
2. ~~Overlay/Hero 重挂载(SuperCupertinoNavigationWrapper 的 actions、DSPopover/DSSelect 经根 Overlay 展示)~~ —— 已免疫。但**在这些回调里构建的 DS 组件仍需包一层 DSThemeBridge**(resolve 取色只救取令牌,DS 组件内部仍调 `AppTheme.of`,必须在 AppTheme 子树内)。
3. flutter_test 怪癖:同一 testWidgets 内连续 pumpWidget 替换根 MaterialApp,新 themeMode 不生效——明暗断言要拆独立用例。

## 二、DS 组件 API 速查(本会话新增/增强)

- **新增 13 个 DsIconKind**:image、palette、info、copy、send、mic、bot、camera、pin、reply、stop、play、pause(总计 60 个;画布惯例 24x24、stroke 2.3 圆头,const 坐标写 `16.0` 防 num 推断)
- **DSPopover**:`contentBuilder: (context, close)` —— close 供菜单项主动关闭气泡
- **DSChip**:新增可选 `icon` 前缀
- **DSInput**:新增 `maxLength`(经 LengthLimitingTextInputFormatter)
- **DSSlider**:新增 `onChangeEnd`(拖动/点击结束回调,保存类滑杆必需)
- **DSDialog**:`confirmVariant`(删除类传 destructive);**DSFab**:`color`/`iconColor`;**DSSkeleton**:`radius`

颜色语义:primary/secondary/success/warning/danger + on* 前景、text/textSub、surface/surfaceAlt、stroke、disabled、background/backgroundAlt、barrier;排版 DsTypography.display/title/heading/body/caption/button/label;Color 扩展 mixWhite/mixBlack。浅色果冻底惯用 `theme.primary.mixWhite(0.85~0.9)`。

## 三、已完成(未提交)

- **home_screen 全部**:home_grid/home_card、folder_dialog、widget_settings_dialog、add_widget_dialog、layout_manager_dialog、background_settings_page、common_widget_selector_page、date_view_grid、home_date_bar/sort_bar、day_card_header、home_widget、generic_plugin/selector_widget
- **chat 全部深层组件**:message_bubble 目录(气泡配色/附件/操作条)、message_input 目录(输入框/发送/元数据 chips/动作面板)、全部对话框(消息选项、编辑×2、清空、录音、日期×2、高级过滤器)、附件(audio_player/image/file 令牌化)、ChatAppBar 自绘头部、ui_service、message_operations、create_channel_sheet、channel_group_selector、tag_messages_screen、home_widgets/builders
- **diary**:主屏、编辑器(第 1-2 轮)+ 本轮修复 SfCalendar 单元格崩溃
- **CustomBottomBar**:内部令牌化(surface/未选中色走 DS 令牌);**DSBottomNavigation 骨架替换未做**,见剩余清单
- **jelly_home**:已令牌化(resolve)

### 刻意保留的 Material(勿"顺手替换")

- 持久化/动态 `IconData`:folder.icon、Channel.icon、HomeWidget 注册表图标、fileInfo 按扩展名映射的文件类型图标(file_message.dart / file_message_widget.dart / chat_data_selectors.dart)及其配色
- 结构性组件:Scaffold、AppBar(未重写的屏幕)、TabBar/TabBarView/TabController、ReorderableListView、RefreshIndicator、TextField(嵌入自绘容器的编辑原语)、InkWell(需要涟漪处)
- 第三方:flutter_floating_bottom_bar(CustomBottomBar)、super_cupertino_navigation_bar、SfCalendar、smooth_sheets、extended_tabs、flutter_colorpicker 的 ColorPicker、InfiniteCarousel
- 基建:ImagePickerDialog 选择器、toastService(独立服务,非组件)

## 四、剩余工作:插件迁移清单(按 Material 引用量排序)

> 计数口径:`Theme.of/showDialog/AlertDialog/TextField/各按钮/IconButton/ListTile/Card/CircularProgress/Switch(Checkbox)ListTile/PopupMenuButton/SegmentedButton/Slider/Dropdown/各 Chip/InkWell` 的匹配行数,含刻意保留项,做前先精查。

### 第一优先:共享组件(影响所有插件)

| 区域 | 量 | 说明 |
|---|---|---|
| `lib/widgets/` | 695 处 / 180 文件 | 全局共享组件(event_listener、file_preview、enhanced_calendar、data_selector_sheet、tags_dialog、statistics 组件等)。多数插件都依赖,先迁这里能减少插件侧工作量;也可按"哪个插件先迁就顺手迁其依赖的共享件" |

### 插件(按量降序)

| 插件 | 量 | 备注 |
|---|---|---|
| `plugins/agent_chat/` | 430 | 量大,含 tool_template_screen 等 |
| `plugins/webview/` | 208 | |
| `plugins/openai/` | 167 | |
| `plugins/goods/` | 159 | goods_item_form 目录较大 |
| `plugins/bill/` | 154 | bill_list_screen + supercupertino 版本两套 |
| `plugins/habits/` | 149 | 含 habit_monthly_list 的 SfCalendar 单元格(注意陷阱 2,用 resolve) |
| `plugins/checkin/` | 126 | |
| `plugins/notes/` | 123 | folder_operations 等对话框 |
| `plugins/store/` | 116 | |
| `plugins/todo/` | 115 | todo_bottombar_view 用 CustomBottomBar |
| `plugins/tracker/` | 111 | |
| `plugins/activity/` | 104 | activity_calendar_screen 用 SfCalendar |
| `plugins/nodes/` | 78 | |
| `plugins/nfc/` | 76 | |
| `plugins/scripts_center/` | 75 | |
| `plugins/calendar_album/` | 72 | calendar_album_bottom_bar 用 CustomBottomBar |
| `plugins/contact/` | 63 | |
| `plugins/database/` | 54 | |
| `plugins/day/` | 41 | |
| `plugins/timer/` | 34 | |
| `plugins/tts/` | 33 | |
| `plugins/calendar/` | 33 | calendar_plugin 内嵌 SfCalendar |
| `plugins/reminder/` | 16 | |

### 收尾项(已迁移区域的残留)

- **chat ~85 处**:chat_screen.dart 搜索栏/统计条/下拉样式(82、865-892 行)、audio_message_bubble、message_bubble/components/{avatar,favorite_icon,reply_widget}、timeline_utils、chat_screen.dart(根目录 6 处)
- **diary ~18 处**:home_widgets/ 注册器(day_card、weekly、icon、quick_create、monthly、overview、providers)、diary_entry_card、diary_plugin、diary_data_selectors
- **home_screen ~5 文件**:plugin_card、base/live_selector_widget、home_screen_view(选项表/批量条仍 Material)、create_folder_dialog/folder_dialog(仅持久化 IconData,属保留)
- **CustomBottomBar → DSBottomNavigation 骨架替换**:10+ 插件共用(flutter_floating_bottom_bar + TabController 驱动 TabBarView + FAB 定位 + 滚动隐藏),需把各插件的 Tab children 换成 DSNavItem,**动静最大,务必单独一轮并逐插件回归**
- `lib/screens/widgets_gallery/`(728 处):组件示例/演示页,属内部展示,可最后做或永久保留

## 五、给下一个 agent 的操作建议

- 改动前先读目标文件的 Material 引用:`grep -n "Theme\.of\|Icons\.\|showDialog\|AlertDialog\|TextField\|Card(\|IconButton\|CircularProgressIndicator" <file>`
- **取令牌一律 `final theme = DSThemeBridge.resolve(context);`**;在第三方回调(Overlay/单元格构建器)里用 DS 组件时,外面包 `DSThemeBridge(child: Builder(...))`
- 对话框套路:`showDSDialog(context: context, theme: DSThemeBridge.resolve(context), builder: (_) => DSThemeBridge(child: Builder(builder: (ctx) { final theme = AppTheme.of(ctx); return JellyBox(...); })))`
- 每轮收尾:`dart format` 改动文件 → `flutter analyze`(0 error 且总数 ≤123)→ `flutter test test/design_system_bridge_smoke_test.dart`
- 新图标先看 `icons.dart` 的画布惯例,并同步补 `test/design_system_bridge_smoke_test.dart` 的图标回归列表
- 若运行期再现 `Null check operator`:先查是否在第三方回调里放了未包桥的 DS 组件(陷阱 2 的组件侧)

## 参考物(不重复其内容)

- 组件 API 全集: `lib/design_system/design_system.dart`(barrel)与 `lib/design_system/components/`
- 用法示范: `lib/screens/design_system_gallery/sections/*`
- 回归测试: `test/design_system_bridge_smoke_test.dart`
- 本轮未提交 diff: `git diff`(基线 22fada5)
