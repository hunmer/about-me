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

### 下一步
- 用户跑 app 验证：无数据日期只显示提示；切排序待办列表顺序变化

