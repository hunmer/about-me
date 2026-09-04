# Handoff: Material → 设计系统(DS)组件渐进式迁移

- 日期: 2026-09-04(第 5 轮会话末更新)
- 仓库: `D:\about-me`(Flutter, branch: `main`;前 4 轮均已提交,最新 83a316d;本轮 ~44 文件未提交)
- 验证基线:`flutter analyze` **0 error,123 条 warning/info 与迁移前完全一致**;`flutter test test/design_system_bridge_smoke_test.dart` **10/10 通过**(含 60 个自绘图标回归)。
- 会话脉络:第 1-2 轮完成 home_grid → /chat 主屏 → /diary → 表单对话框;第 3 轮完成 home_screen 其余 widget、chat 全部深层组件、CustomBottomBar 内部令牌化,并把**全部应用代码的 `AppTheme.of` 换成 `DSThemeBridge.resolve`**;第 4 轮用 3+3 个并行 agent(按插件目录分区,互不重叠)完成 **10 个插件**:agent_chat/webview/openai/goods/bill(主体 + 残留收尾)与 habits/checkin/notes/store;第 5 轮 3 个并行 agent 完成 **todo/tracker/activity**(13/14 个量大插件全部收尾)。

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

### 第 4 轮迁移中发现的 DS 缺口(下轮补齐可解锁对应保留项)

- **组件 API**:无时间选择器(等价 showTimePicker,checkin 保留 Material);无日期**范围**选择器(等价 showDateRangePicker,notes/activity 保留);DSButton 无自定义基色(身份色按钮目前用 `Pressable+JellyBox` 组合顶替,timer_dialog/habit_card_widget/todo list_selector);DSSelect 不支持带图标/自定义行选项(bill_shortcuts 分类下拉、activity TTS 服务下拉保留);无"选项列表对话框"(等价 SimpleDialog,AgentModeSelectionDialog 保留);DSChip 无自定义选中色/禁用态;DSListItem 的 subtitle 无 maxLines;DSInput 无 autofocus(用 FocusNode+postFrame 变通);**DSFab 无带文字的 extended 形态**(activity 日/周配置屏保存按钮保留 Material);**`showDSBottomSheet` 无 `theme:` 参数且内部裸调 `AppTheme.of(context)`**——在无 AppTheme 祖树的调用点会抛空检查异常,与 showDSDialog 契约不一致,建议优先补(tracker 轮被迫改用 showDSDialog 顶替)
- **图标缺口**(已用近似图标顶替的:钱包→piggy、订阅→refresh、筛选→sort、源→layers、分类→tag、计时器→clock、保存→check、旗帜空态→pin、错误→block、周视图→calendar、四象限→grid、清空→trash、语音→mic;无替代保留 Material 的:globe/lock/open_in_browser/folder 系(webview)、local_fire_department 火焰(checkin)、radio_button_unchecked/check_box_outline_blank 等空心圆未完成态(tracker/todo 保持图标对一致)、check_circle 实心圆对、inventory/archive/trophy/calculate/history/note 系、flag 旗帜(track_changes 靶心)、title 文本、音量/震动、timeline、delete_sweep)。新增图标时按画布惯例补 `test/design_system_bridge_smoke_test.dart` 回归,再回头替换顶替处

## 三、已完成(未提交)

- **home_screen 全部**:home_grid/home_card、folder_dialog、widget_settings_dialog、add_widget_dialog、layout_manager_dialog、background_settings_page、common_widget_selector_page、date_view_grid、home_date_bar/sort_bar、day_card_header、home_widget、generic_plugin/selector_widget
- **chat 全部深层组件**:message_bubble 目录(气泡配色/附件/操作条)、message_input 目录(输入框/发送/元数据 chips/动作面板)、全部对话框(消息选项、编辑×2、清空、录音、日期×2、高级过滤器)、附件(audio_player/image/file 令牌化)、ChatAppBar 自绘头部、ui_service、message_operations、create_channel_sheet、channel_group_selector、tag_messages_screen、home_widgets/builders
- **diary**:主屏、编辑器(第 1-2 轮)+ 本轮修复 SfCalendar 单元格崩溃
- **CustomBottomBar**:内部令牌化(surface/未选中色走 DS 令牌);**DSBottomNavigation 骨架替换未做**,见剩余清单
- **jelly_home**:已令牌化(resolve)
- **第 4 轮插件 ×10**:agent_chat、webview、openai、goods、bill(含 supercupertino actions、PopupMenuButton→DSPopover、AppBar leading/actions 等残留收尾)、habits(含 habit_monthly_list 的 SfCalendar `monthCellBuilder` 外包 DSThemeBridge——陷阱 2 实例)、checkin、notes、store;覆盖各插件 data_selectors 配置表单、全部对话框、加载/空态、FAB。剩余匹配行均为"刻意保留的 Material"或子串误匹配;行为修复 1 处:checkin 的 GroupSortDialog 单选原本缺 groupValue/onChanged 不可选中,重写时已接通
- **第 5 轮插件 ×3**:todo(CustomBottomBar 骨架/FAB/TabBarView 按规约保留,仅内部令牌化;actions/对话框/详情页/四象限/日卡迁移)、tracker(对话框/目标卡/详情屏/选择器屏全量;SuperCupertino actions 包桥)、activity(**SfCalendar 陷阱 2 处理**:取令牌走 resolve,appointmentBuilder 内只用 Container/Text+显式色避免未包桥 DS 组件;SuperAppBar actions 逐个包桥)。activity_timeline 的 `_getActivityIcon` 启发式 Material 图标映射属保留项(已补花括号修 lint)

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

> 已完成(第 4-5 轮,3+3+3 并行 agent 按目录分区):agent_chat 430、webview 208、openai 167、goods 159、bill 154、habits 149、checkin 126、notes 123、store 116、todo 115、tracker 111、activity 104。并行分区经验:每个 agent 只许改自己分配的插件目录、**一律不许动 `lib/design_system/**` 与 `lib/widgets/**`**(防冲突),图标/组件缺口记录后集中补,收尾各自 `dart format` + analyze,主会话最后统一跑 analyze + 冒烟。

| 插件 | 量 | 备注 |
|---|---|---|
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
- **已迁插件的刻意保留残留**(做共享组件/补缺口时顺手消化):CustomBottomBar+FAB 骨架(habits_bottom_bar、checkin、store_bottom_bar、goods_bottom_bar、openai/bill_plugin);共享表单/组件依赖(FormBuilderWrapper、MonthSelector、WidgetConfigEditor、StatisticsScreen、DayCardHeader、SwipeActionOption 等,属 `lib/widgets/**`);showTimePicker/showDateRangePicker(等 DS 补组件);持久化 IconData 全家(folder/Channel/Habit/Skill/CheckinItem/warehouse/bill 分类图标及注册表)
- **死代码树**(迁移时已确认无外部引用,建议评估删除):notes 的 `screens/note_screen/**`、`search_screen.dart`、`folder_list_screen.dart`、`widgets/{search_note_item,note_item,folder_item}.dart`;checkin 的 `checkin_card.dart`、`components/{checkin_item_list,group_card,group_list_view,stat_card,weekly_checkin_circles}.dart`;agent_chat 的 `AgentModeSelectionDialog`;todo 的 `widgets/{filter_dialog,add_task_button,task_action_sheet}.dart`;tracker 的 `widgets/{goal_detail_page,tracker_summary_card}.dart`(前者仅被插件 export);activity 的 `widgets/activity_form/activity_time_section.dart`、`services/activity_notification_test.dart`、`screens/activity_timeline_screen/components/{timeline_app_bar,date_selector}.dart`

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
- 本轮未提交 diff: `git diff`(基线 83a316d)
