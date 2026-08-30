# 进度日志

## 会话: 2026-08-30 (任务启动 + Phase 1-5 实施)

### 背景对齐 (grilling 两轮)
- 用户澄清：迁移对象是**插件条目 UI**（一篇日记/一项待办），不是 buildCardView 统计卡
- 决策：按日期聚合卡片 / 迁移现有组件保持能力不变 / 卡片不可切日期(home 层统一) /
  先做 todo+diary / 旧卡保留并存 / 新增主页底部快速新建按钮

### 实施记录
**Phase 1 基础设施**
- 新建 `lib/screens/home_screen/managers/home_date_controller.dart`（单例 ChangeNotifier，默认今天）
  - 设计变更：原计划 InheritedWidget，改为单例——文件夹弹窗等任意上下文可用、自动刷新
- 新建 `lib/screens/home_screen/managers/quick_create_registry.dart`
- 新建 `plugins/todo/home_widgets/register_quick_create.dart`（TaskForm, initialStartDate）
- 新建 `plugins/diary/home_widgets/register_quick_create.dart`（DiaryEditorScreen）
- 挂进各自 home_widgets.dart 的 register()

**Phase 2 待办日卡**
- 抽取 `plugins/todo/widgets/todo_day_card.dart`（忠实迁移 _buildDayCard，dayIndex→date.weekday）
- `todo_week_view.dart` 改用 TodoDayCard（删 ~200 行重复 UI）
- 新建 `plugins/todo/home_widgets/register_day_card.dart`（id: todo_day_card）
  - 过滤：未完成 + startDate??dueDate 同天；刷新 merge(taskController, HomeDateController)

**Phase 3 日记日卡**
- 抽取 `plugins/diary/widgets/diary_entry_card.dart`（颜色缺省按原逻辑从主题推导）
- `diary_calendar_screen.dart` 搜索结果改用之
- 新建 `plugins/diary/home_widgets/register_day_card.dart`（id: diary_day_card，默认 Wide2）
  - 数据：DiaryUtils.loadDiaryEntry(date)（一天一篇）；监听 diary_* 事件 + 日期变化

**Phase 4 快速新建按钮**
- 新建 `screens/home_screen/widgets/quick_create_dialog.dart`
- home_screen_view.dart: Scaffold FAB centerFloat（编辑/批量/加载态隐藏）→ 对话框 → onCreate

**Phase 5 验证**
- dart analyze lib 全量 **0 error**（152 存量 warning/info）
- 修复过的错误：DiaryEditorScreen.initialContent 必填、quick_create_dialog 未定义 theme

### 文件清单
新增: home_date_controller / quick_create_registry / quick_create_dialog /
todo_day_card / register_day_card(todo) / register_quick_create(todo×diary) / diary_entry_card /
register_day_card(diary)
修改: todo_week_view / diary_calendar_screen / home_screen_view /
home_widgets.dart(todo×diary) / 6 个 l10n 文件 / app_translations×3

### 注意
- pubspec.yaml 的 flutter_quill 11.0.0→11.5.1 非本次改动（用户/IDE 并行修改），未动
- 手动验证清单见 task_plan.md Phase 5.2（待跑 app 验证）

### 追加: Phase 6 日期横条 (2026-08-30)
- 用户追问"切换日期没做？"后立即实施（原计划第二阶段提前）
- 新建 `screens/home_screen/widgets/home_date_bar.dart`
- 接入 home_screen_view 两个内容分支（多布局/单布局）
- 链路: 横条 → HomeDateController.setDate → 待办/日记日卡自动刷新

### 追加: Phase 7 模式开关 (2026-08-30)
- 用户反馈：切日期没效果，因为主页是固定 grid；要求加「固定模式/日期数据模式」开关
- HomeWidget.isDateDriven 标记；controller 模式状态+持久化(configs home_date_view)
- 新建 widgets/date_view_grid.dart(自动排列所有日期卡片)
- AppBar 切换按钮；日期条移到只属于日期视图；固定模式完全恢复原样
- analyze 全量 0 error

### 追加: Phase 8 只展示已有数据 + 排序 (2026-08-30)
- 用户反馈：日期视图不要空占位卡；日期条下方加排序选项
- HomeWidget.hasDateData 检查器；DateViewGrid 并行检查只渲染有数据的卡；
  监听数据事件自动重查(新建待办/写日记后卡片即时出现)
- HomeDateSortBar(默认/优先级/时间 chips)；待办卡应用排序
- analyze 全量 0 error

### 追加: 其余插件批量迁移计划 (2026-08-30)
- 用户要求：对其余插件同样添加（日期卡 + 快速新建）
- 摸底 12 个候选插件的模型日期字段/编辑表单/条目UI，结论写入 findings.md §8
- task_plan.md 新增 Phase 9(高价值5个: calendar/bill/activity/tracker/checkin)、
  Phase 10(记录类4个: habits/day/notes/calendar_album)、Phase 11(排除项+特殊处理)
- 固化 6 步通用迁移模式（todo/diary 已验证）

### 下一步
- 用户确认批次后按 Phase 9 顺序实施（calendar 先行）

## 会话: 2026-08-30 (Phase 9-11 其余插件批量迁移)

### 实施记录（9 插件，全部走 6 步通用模式）
**公共**：新建 `screens/home_screen/widgets/day_card_header.dart`（日卡通用头部：
周几+日期+计数徽标+摘要+＋按钮），9 张新日卡共用，视觉与待办日卡一致。

**Phase 9 高价值 5 插件**
- calendar：`widgets/event_day_card.dart` + register_day_card/quick_create；
  getAllEvents 按 startTime 过滤；点击→showEventDetails；新建直接 push EventEditPage(initialDate:)
- bill：`widgets/bill_day_card.dart` + 两个 register；**按 bill.date 过滤（getBills 是 createdAt，不可用）**；
  编辑走 BillEditScreen(bill:)，新建走 initialDate:+首账户
- activity：`widgets/activity_day_card.dart` + 两个 register；getActivitiesForDate 异步按日分片；
  编辑=SmoothBottomSheet 85%（与时间线一致）；新建=ActivityEditScreen(selectedDate:)
- tracker：`widgets/record_day_card.dart`（含 openRecordCreateFlow 目标选择流程）+ 两个 register；
  **改 RecordDialog 加 initialRecordedAt 参数**（+未来日期防护）
- checkin：`widgets/checkin_day_card.dart` + register_day_card（**不注册快速新建**——签到是动作）；
  点击=日期感知的签到切换（toggleCheckin 只认今天，自实现并广播 checkin_* 事件）

**Phase 10 记录类 4 插件**
- habits：`widgets/habit_day_card.dart` + 两个 register；每习惯异步取记录过滤当日；
  快速新建 HabitForm+Scaffold（onSave 内 Builder context 自行 pop，修复了误用主页 context 的 bug）
- day：`widgets/memorial_day_edit_flow.dart`（共享 DayController + 编辑/新建流程）+ register_day_card
  （紧凑行内联实现）+ register_quick_create；**不监听 memorial_day_cache_updated 防无限循环**
  （reloadData 会广播它；date_view_grid 同样排除）
- notes：`widgets/note_day_card.dart` + 两个 register；按 updatedAt/createdAt 同天过滤；编辑复刻
  note_operations.editNote；新建落 root 文件夹
- calendar_album：`widgets/album_day_card.dart` + 两个 register；getEntriesForDate 同步；
  缩略图 thumbUrls??imageUrls??markdown提取，FutureBuilder+Image.file；新建 EntryEditorScreen(initialDate:)

**Phase 11 收尾**
- date_view_grid 事件列表 6→39 个（见 task_plan Phase 11；memorial_day_cache_updated 有意排除）
- dart analyze lib 全量 **0 error**（154 warning/info = 基线152 + 2 个 IconData non_const，
  与 bill/habits/tracker 既有代码同款）
- 快速新建名称全部复用既有 l10n key（已验证 8 个 key 在 zh/en/jp 三语齐全）；
  新增 key：各插件 dayCardName/Desc/Empty + calendar_allDay/tracker_noGoals/
  habits_dayCardNotDone/notes_dayCardUntitled ×3 语

### 文件清单
新增 21: day_card_header + 9 个 widgets/*_day_card(+memorial_day_edit_flow, activity/event、
bill/bill、tracker/record、checkin/checkin、habits/habit、notes/note、album/album) +
8 个 register_day_card + 8 个 register_quick_create
修改 20: 9 个 home_widgets.dart（挂注册）、date_view_grid（事件列表）、
tracker/record_dialog（initialRecordedAt）、9 插件 ×3 l10n 文件
（另修复 notes register_quick_create 一处 import 语法错误）

### 关键坑记录
- QuickCreateDialog 先 pop 自己再用主页 context 调 onCreate → 打开编辑器 OK，
  但表单自 pop 时必须用表单页自己的 context（Builder）
- DayController 每实例独立从存储加载 → 日卡持模块级共享实例 + reloadData 保新鲜
- checkin 的 frequency 索引 = weekday-1（0=周一）；getDateRecords 按签到时间降序，first=最新

### 下一步
- 用户跑 app 验证（清单见 task_plan.md「手动验证清单」）

