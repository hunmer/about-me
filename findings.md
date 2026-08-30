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
