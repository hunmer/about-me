# 研究发现：home_grid 卡片体系与插件条目 UI

## 1. 主页卡片双体系
- **旧体系**: `BasePlugin.buildCardView()` (~28 插件实现) → `PluginGrid`/`PluginCard`，
  现仅悬浮球选择器 (core/floating_ball/widgets/plugin_overlay_selector.dart) 和
  plugin_list_dialog 在用。**本次不动**
- **新体系 (现行)**: `home_screen_view.dart` → `HomeGrid` → `HomeWidgetItem` →
  `HomeWidgetRegistry.getWidget(widgetId)` → `HomeWidget.builder(context, config)`
  - 注册：各插件 `home_widgets/` 目录，main.dart `_initializeHomeWidgets()` 调 register()
  - 尺寸：HomeWidgetSize (SmallSize 1x1 / MediumSize 2x1 / LargeSize 2x2 / Large3Size 2x3 /
    WideSize 4x1 / Wide2Size 4x2 / Wide3Size 4x3 / CustomSize)
  - config 自动注入 'widgetSize'；CustomSize 注入 customWidth/customHeight
  - WidgetGridScope (InheritedWidget) 向卡片下发网格像素信息 → 日期 scope 照此模式

## 2. 条目 UI 现状（本次迁移对象）
### 待办「一项」
- 内联在 `TodoWeekView._buildDayCard` (todo/views/todo_week_view.dart:101-308)
- 单日卡片 = 日头部(周几+日期+计数badge+＋按钮) + ListView(Checkbox+标题+优先级点)
- 分组逻辑：task.startDate ?? dueDate 与该日同天；过滤 status == done
- 回调：onTaskTap → TodoItemDetail(SmoothBottomSheet)；onTaskStatusChanged →
  taskController.updateTaskStatus；onAddTask(date) → TaskForm(initialStartDate: date)
  (NavigationHelper.openContainerWithHero)
- 四象限视图 (todo_four_quadrant_view.dart) 有类似条目 UI

### 日记「一篇」
- `diary_calendar_screen._buildSearchResultCard` (222-310)
- Card: 日期(yyyy年MM月dd日) + mood emoji + 标题 + QuillViewer(content, 只读, 高80) + 字数
- 点击 → NavigationHelper.push(DiaryEditorScreen(date, storage, initialTitle, initialContent))
- DiaryEntry 模型: models/diary_entry.dart (date/title/content/mood)

## 3. 数据访问
- Todo: `TodoPlugin.instance.taskController.tasks` / `updateTaskStatus(id, status)`；
  AnimatedBuilder(animation: taskController) 可监听
- Diary: diary_calendar_screen 用 widget.storage (构造注入)；需查 diary_plugin 暴露方式
- 事件: task_added / task_deleted / task_completed；diary_entry_created / _updated / _deleted
  (EventListenerContainer(events:, onEvent:) 监听)

## 4. 现有 home_widgets (todo/diary，均保留并存)
- todo: todo_icon(1x1 导航) / todo_overview(2x2 统计) / todo_quick_add(1x1 跳转新建) /
  todo_list(2x2 只读 taskListCard 预览)
- diary: diary_icon / diary_overview / 周报组件 / 月度列表

## 5. 选择器/公共小组件体系（了解即可，本次不走此路）
- HomeWidget 可带 selectorId + dataRenderer + commonWidgetsProvider；
  9 插件 (webview/chat/timer/tracker/goods/agent_chat/bill/scripts_center) 已用 dataRenderer
  渲染选中条目
- CommonWidgetsRegistry: 93+ 静态展示卡 (taskListCard 等)，props 驱动、无交互

## 6. 快速新建
- ActionManager (core/action/) 是重型可配置动作框架(表单/序列化/执行器/确认/快捷键)——不适合
- 方案：新建轻量 QuickCreateRegistry，插件注册 {id, name, icon, color, onCreate(ctx, date)}
- 打开方式参考 todo_bottombar_view.dart:492-501 (TaskForm) 与 diary_calendar_screen:314 (编辑器)

## 7. l10n
- 插件级: lib/plugins/{todo,diary}/l10n/；屏级: lib/screens/l10n/screens_translations_{zh,en,jp}.dart
- 主页级 key（home_*）: lib/l10n/app_translations_{zh,en,jp}.dart

## 8. 其余插件迁移摸底（2026-08-30，为 Phase 9-11 计划）

### 有日期字段的模型（日期卡候选）
| 插件 | 模型/字段 | 编辑表单 | 备注 |
|------|----------|---------|------|
| calendar | Event.startTime/endTime | pages/event_edit_page.dart | 最高价值 |
| bill | Bill.date | screens/bill_edit_screen.dart | 已有 register_create_shortcut 可复用 |
| activity | ActivityRecord.startTime/endTime | widgets/activity_form.dart + AppRoutes.activityEdit | |
| tracker | Record.recordedAt | goal_edit_page.dart（记录表单需勘察） | 已有 dataRenderer 模式参考 |
| checkin | CheckinItem.getDateRecords(date) | checkin_form_screen.dart | 按日取记录 API 现成；"新建"语义特殊 |
| habits | CompletionRecord.date | widgets/habit_form.dart | 新建=习惯本身，与日期无关 |
| day | MemorialDay.targetDate | widgets/edit_memorial_day_dialog.dart | hasDateData 语义可选当天/临近 |
| notes | Note.createdAt（弱） | screens/note_edit_screen.dart | 当天创建的笔记 |
| calendar_album | CalendarEntry | - | 可选，照片按日期 |
| contact | interaction_record.date | - | 低价值可选 |
| timer | startTime/createdAt（弱） | 无表单文件 | 可选 |
| reminder | nextTriggerAt | - | 未接入 home_widgets 注册体系，需先补链路 |

### 不适用日期卡
chat、agent_chat、openai、nfc、tts、webview、scripts_center、store、nodes、database、goods

### 迁移模式（todo/diary 已验证）
6 步：抽条目UI → register_day_card(isDateDriven+hasDateData) → register_quick_create →
挂 register() → l10n×3 → analyze + 把插件数据事件加进 date_view_grid.dart 监听列表

## 9. Phase 9-11 批量迁移实测补充（2026-08-30，9 插件完成）

### 数据归属口径（易踩坑）
| 插件 | 正确口径 | 陷阱 |
|------|---------|------|
| calendar | getAllEvents() 按 startTime 年月日 | controller.events 只有本地事件 |
| bill | account.bills 按 bill.date | getBills/getTodayFinance 按 createdAt |
| activity | getActivitiesForDate(date) 异步按日分片 | 周缓存只有过去7天，未来日期查不到 |
| tracker | controller.records 按 recordedAt | 无按日期 API；记录删除不发事件(仅 notifyListeners) |
| checkin | frequency[weekday-1] 排班 + getDateRecords | CheckinListController.toggleCheckin 只认今天 |
| habits | 每习惯 getHabitCompletionRecords 再过滤 | 无 ChangeNotifier，全靠事件刷新 |
| day | targetDate 严格同日 | DayController 每实例独立加载，需 reloadData 保新鲜 |
| notes | updatedAt 或 createdAt 同天 | NotesController 非 ChangeNotifier |
| calendar_album | getEntriesForDate(date) 同步 | 缩略图需 ImageUtils.getAbsolutePath 异步解析 |

### 事件刷新机制选型
- controller 是 ChangeNotifier（calendar/bill/tracker）→ AnimatedBuilder(controller+HomeDateController)
- 异步按日分片（activity/habits）→ stateful 加载+防过期守卫+EventListenerContainer
- 非 Notizer 同步数据（checkin/notes/album）→ EventListenerContainer(setState)+日期监听
- **循环广播陷阱**：day 的 hasDateData 会 reloadData→广播 memorial_day_cache_updated；
  卡片和 date_view_grid 都不能监听该事件，否则无限刷新

### 其他实测结论
- QuickCreateDialog：先 pop 自身，再用主页 context 调 onCreate；
  需自 pop 的表单（HabitForm 不自 pop）要用表单页 Builder context
- 自 pop 的编辑器：EventEditPage/BillEditScreen/ActivityEditScreen/RecordDialog/
  EditMemorialDayPage/NoteEditScreen/EntryEditorScreen；不自 pop：HabitForm
- Goal.icon/Habit.icon 是 codePoint 字符串：IconData(int.parse(s), fontFamily:'MaterialIcons')
  （会触发 non_const warning，与既有代码一致）
- day 插件快速新建预填：EditMemorialDayPage 只收整对象 → 传 MemorialDay(title:'', targetDate:date)，
  保存时 page 内重新生成 id

