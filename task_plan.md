# 任务计划：插件条目 UI 迁移为 home_grid 卡片 + 主页快速新建

## 目标
把待办、日记插件的条目 UI（一项待办、一篇日记）迁移为 home_grid 可加载的功能卡片，
并在主页底部中央新增快速新建按钮。为第二阶段「主页日期横条」铺好日期管道。

## 已确认的设计决策（grilling 两轮对齐）
| 决策点 | 结论 |
|--------|------|
| 绑定模式 | 按日期聚合卡片：一张卡展示某天全部条目；卡片不可自行切日期 |
| 日期机制 | home 层持有「当前选中日期」(默认今天)，InheritedWidget 下发；卡片只读。第二阶段横条只改这个状态 |
| 待办卡形态 | 整个「单日卡片」(TodoWeekView._buildDayCard 抽出)：日头部+计数+＋新建+任务列表 |
| 待办交互 | 迁移现有组件能力不变：勾选完成、点击进 TodoItemDetail、＋打开 TaskForm(预填该日) |
| 日记卡形态 | 日历页 _buildSearchResultCard 抽出：日期+心情+标题+Quill预览+字数；当天多篇全部列出 |
| 日记交互 | 能力不变：点击进 DiaryEditorScreen 查看/编辑；不新增写日记按钮 |
| 旧卡处置 | 旧只读预览卡(todo_list 等)保留并存，用户手动清理 |
| 范围 | 仅 todo + diary；沉淀「条目 UI → home grid 卡」模式供其余插件套用 |
| 新增按钮 | home 底部中央 ＋ → 弹对话框选支持的项目 → 打开对应编辑界面(预填选中日期) |

---

## Phase 1: 基础设施 [x] complete (2026-08-30)
- [x] 1.1 HomeDateController 单例(ChangeNotifier, 默认今天)——替代原定 InheritedWidget 方案，
      原因：文件夹弹窗/任意上下文均可用且自动刷新，符合代码库单例习惯
- [x] 1.2 QuickCreateRegistry + QuickCreateItem{id, pluginId, name, icon, color, onCreate(ctx, date)}
- [x] 1.3 todo/diary 各注册一个 QuickCreateItem（挂进各自 home_widgets.register()）
- [x] 1.4 l10n: todo_quickCreateTask / diary_quickCreateEntry (zh/en/jp)

## Phase 2: 待办日卡 [x] complete (2026-08-30)
- [x] 2.1 抽出 lib/plugins/todo/widgets/todo_day_card.dart；TodoWeekView 改用之
- [x] 2.2 注册 todo_day_card (Large/Large3/Wide2/Wide3)；
      过滤规则与周视图一致(未完成 + startDate??dueDate 同天)
- [x] 2.3 刷新：AnimatedBuilder(Listenable.merge([taskController, HomeDateController]))
- [x] 2.4 l10n: todo_dayCardName / todo_dayCardDesc (zh/en/jp)

## Phase 3: 日记日卡 [x] complete (2026-08-30)
- [x] 3.1 抽出 lib/plugins/diary/widgets/diary_entry_card.dart；日历页搜索结果改用之
- [x] 3.2 注册 diary_day_card (Large3/Wide2/Wide3，默认 Wide2)；DiaryUtils.loadDiaryEntry(date)
- [x] 3.3 刷新：diary_entry_created/updated/deleted + diary_refresh 事件 + 日期监听
- [x] 3.4 l10n: diary_dayCardName / diary_dayCardDesc / diary_dayCardEmpty

## Phase 4: 主页快速新建按钮 [x] complete (2026-08-30)
- [x] 4.1 Scaffold FAB centerFloat，编辑/批量/加载态隐藏
- [x] 4.2 QuickCreateDialog(注册项网格) → onCreate(context, HomeDateController().date)
- [x] 4.3 l10n: home_quickCreateTitle

## Phase 5: 验证 [x] complete (2026-08-30)
- [x] 5.1 dart analyze lib 全量 0 error（152 个存量 warning/info 与本次无关）
- [ ] 5.2 手动验证清单（待用户跑 app 验证）：
  - 添加组件对话框出现「待办日卡」「日记日卡」
  - 待办日卡：勾选/取消、点击任务出详情、＋出 TaskForm(预填日期)、当天任务过滤正确
  - 日记日卡：显示当天日记、点击进编辑器、无日记时空态
  - 底部 ＋ 按钮：弹选择框 → 待办/日记 → 编辑器打开且日期为今天
  - 编辑/批量模式下 ＋ 按钮隐藏
  - 周视图/搜索结果 UI 与迁移前一致
  - 旧卡片(todo_list 等)不受影响

---

## 关键事实 (来自代码勘察)
- 主页面用新 HomeGrid(home_screen_view.dart:205,337,406)；旧 PluginGrid/buildCardView 仅悬浮球在用，不动
- 条目 UI 现状：待办条目内联在 TodoWeekView._buildDayCard 的 itemBuilder；日记条目在
  diary_calendar_screen._buildSearchResultCard —— 均未抽组件
- 9 个插件(webview/chat/timer 等)已用 dataRenderer 模式渲染选中条目，机制可参考
- WidgetGridScope 是现成的 InheritedWidget 传网格信息模式，日期 scope 照此做
- HomeScreenController extends ChangeNotifier；事件：task_added/deleted/completed，
  diary_entry_created/updated/deleted
- TaskForm(taskController, reminderController, initialStartDate)；
  DiaryEditorScreen(date, storage, initialTitle, initialContent)
- ActionManager 过重(表单/序列化/执行器)，快速新建用轻量专用 registry

## 错误记录
| 错误 | 阶段 | 解决方案 |
|------|------|----------|
| (暂无) | - | - |
