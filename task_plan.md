# 任务计划：插件条目 UI 迁移为 home_grid 卡片 + 主页快速新建

## 追加任务：Live2D 在线模型与点击语音（2026-09-05）

### 目标
- Live2D 右键菜单增加“在线选择模型”，打开独立页面浏览并加载在线模型。
- Live2D 支持将模型点击区域绑定到语音，点击时播放。
- about-me 默认配置为：模型提供语音时，点击区域随机播放语音。

### Phase 12: 现状与协议勘察 [complete]
- [x] 12.1 核对 app、flutter_live2d 包、macOS Web runtime 的模型加载与事件通道
- [x] 12.2 核对在线模型仓库 JSON 来源、CORS/相对资源加载约束
- [x] 12.3 核对现有右键菜单和模型配置持久化位置

### Phase 13: 在线模型选择与加载 [complete]
- [x] 13.1 增加在线模型目录解析/请求模型
- [x] 13.2 增加独立选择页面（加载、错误、刷新、搜索/分类等必要状态）
- [x] 13.3 右键菜单入口与远程加载调用（本次不新增模型持久化，保持现有本地模型行为一致）

### Phase 14: 点击区域语音 [complete]
- [x] 14.1 Live2D 动作 `Sound` 增加真实音频播放，保留 WAV 口型分析
- [x] 14.2 about-me 设置区域动作匹配 + 模型自带语音随机播放策略
- [x] 14.3 处理无语音回退、连续点击停止旧音频、模型释放清理与异步 WAV 防过期

### Phase 15: 验证与收尾 [complete]
- [x] 15.1 Web runtime build；包 analyze 0 issues、test 3/3
- [x] 15.2 app 改动文件 analyze 0 issues、test 13/13、macOS debug build、独立进程冒烟通过
- [x] 15.3 更新 findings/progress，并提供手动验收步骤

### 本次错误记录
- `apply_patch` 第一次更新 Phase 12 时锚点少一个空格导致校验失败；已读取原文并改用准确锚点，无文件内容受损。
- 用 `dart -e` 探查 URI 时发现当前 Dart CLI 不支持 `-e`；产品代码未受影响，相关编码规则由新增单测覆盖。
- 一次跨仓库组合补丁因平台接口注释锚点不一致而整体校验失败；已确认无部分写入，改为按文件应用。
- 第二次 Web runtime 重建误在包根目录执行，因根目录无 npm build script 失败；包 analyze/test 仍通过，随后改回 `web_runtime/` 执行。
- 第一次 app 冒烟等待条件误写为 runtime/model 任一日志即结束，只验证到 runtime ready；已精确终止我方 PID，改为两条日志均出现后重跑。

### Phase 16: 远程解析与切换占位修复 [complete]
- [x] 16.1 原生平台 HTTP(S) 模型目录绕过 Flutter asset 解包
- [x] 16.2 切换时先卸载旧模型并阻断旧模型点击/动作
- [x] 16.3 保持平台视图挂载，覆盖模型区域显示加载占位和模型名称
- [x] 16.4 包 analyze/test、app analyze/test/build 与运行日志验证

### Phase 16 错误记录
- 首次远程冒烟只等待 30 秒并丢失后台 session 元数据；已精确终止我方 PID，改用可轮询 session 和 75 秒边界。
- `mori_miko` 远程请求已到 runtime，但动作预加载异常未结算导致 75 秒超时；改为失败动作不阻塞主体加载。
- 修复结算后 `mori_miko` 仍因近百个动作抢占请求队列而在纹理阶段超时；远程首载改为最多预加载 24 个优先动作。
- 在 `web_runtime/` 重建后顺带执行 `flutter test`，该目录无 test 因而失败；bundle build 与该目录 analyze 已通过，包测试改在根目录执行。
- 远程动作预算补丁保留了一行旧方法签名，检查时发现且尚未打包；删除重复签名后再验证。

### Phase 17: 加载进度、错误占位与点击重试 [complete]
- [x] 17.1 扩展 runtime → 原生 → Dart 的模型加载进度事件
- [x] 17.2 加载占位显示阶段与百分比，失败时显示可读错误
- [x] 17.3 点击错误占位重新加载当前选择模型
- [x] 17.4 确认单个 motion HTTP 403 仅跳过，不导致模型整体失败
- [x] 17.5 Web runtime build、包与 app analyze/test/build 验证

### Phase 17 错误记录
- 首次勘察误读不存在的 `lib/live2d_view.dart`；实际公开入口为 `lib/flutter_live2d.dart`，控制器与状态文件已从 `lib/src/` 读取，未产生文件修改。
- 首次读取测试误用了不存在的 `test/live2d_flutter_test.dart`；实际测试文件为 `test/flutter_live2d_test.dart`，已按真实路径读取，未产生文件修改。

### Phase 18: 旧版 motion3 兼容修复 [complete]
- [x] 18.1 对比 `l2d00055` 动作 JSON 与当前 Cubism motion3 结构
- [x] 18.2 在 runtime 加入最小兼容转换，保持正常 motion3 不受影响
- [x] 18.3 验证预加载和点击触发均能创建动作
- [x] 18.4 确认并处理日志中的加载动画布局溢出
- [x] 18.5 Web runtime build、包/app analyze/test/build 与目标模型冒烟

### Phase 18 错误记录
- 首次搜索 Cubism framework 源码误用了不存在的 `web_runtime/framework/src`，且一次从 Aboutme 工作目录读取包内 `web_runtime/src/lappmodel.ts`；均为只读命令，后续改用 `rg --files` 定位真实路径。
- 首次更新 Phase 18 记录时把 `progress.md` 的会话锚点写进 `task_plan.md` 补丁，整次补丁校验失败且无部分写入；已拆分为正确文件锚点。

## 目标
把待办、日记插件的条目 UI（一项待办、一篇日记）迁移为 home_grid 可加载的功能卡片，
并在主页底部中央新增快速新建按钮。为第二阶段「主页日期横条」铺好日期管道。
（todo/diary 已完成 Phase 1-8；Phase 9-11 其余插件批量迁移已于 2026-08-30 完成）

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

## Phase 6: 主页日期横条（原第二阶段，提前实施）[x] complete (2026-08-30)
- [x] 6.1 新建 widgets/home_date_bar.dart：
      左侧「今天」快捷块 + 横向日期列表(今天-7 ~ 今天+21，itemExtent 56)；
      选中=primary 填充，今天=描边标识；点击 → HomeDateController().setDate() 并居中滚动
- [x] 6.2 接入 home_screen_view 两个内容分支：
      多布局分支(Positioned.fill Column 顶部) + 单布局分支(_buildHomeContent Column 顶部)
- [x] 6.3 l10n: home_today (zh/en/jp)
- [x] 6.4 dart analyze 0 error
- 效果链路：横条点击 → setDate → 待办日卡(AnimatedBuilder) / 日记日卡(listener) 自动刷新；
  快速新建的预填日期同步跟随

## Phase 7: 固定布局 / 日期视图 模式开关 (2026-08-30)
用户反馈：切日期无效果——主页显示的是固定摆放的 grid。需要模式开关区分两种展示。
- [x] 7.1 HomeWidget 增加 isDateDriven 标记(默认 false)；todo/diary 日卡设为 true
- [x] 7.2 HomeScreenController: _isDateViewMode + toggleDateViewMode()；
      持久化到 configs home_date_view {enabled}；切日期视图时自动退出编辑/批量模式
- [x] 7.3 新建 widgets/date_view_grid.dart：按注册顺序自动排列所有 isDateDriven 卡片
      (默认尺寸，4 列 StaggeredGrid，纵向滚动)；空注册时提示
- [x] 7.4 home_screen_view: body 增加 isDateViewMode 分支(日期条+DateViewGrid)；
      AppBar 增加模式切换按钮(calendar_view_day ↔ grid_view)；
      **移除固定模式两分支里的 HomeDateBar**(固定模式恢复原样，日期条只属于日期视图)
- [x] 7.5 l10n: home_modeDateView / home_modeFixedLayout / home_dateViewEmpty
- [x] 7.6 dart analyze lib 全量 0 error

## Phase 8: 日期视图只展示已有数据 + 排序选项 (2026-08-30)
用户反馈：日期视图不要固定占位卡片，只展示已有数据；日期条下方加排序选项。
- [x] 8.1 HomeWidget 新增 hasDateData 检查器(Future<bool> Function(date))；
      todo 卡=该日有未完成任务；diary 卡=DiaryUtils.loadDiaryEntry != null
- [x] 8.2 DateViewGrid 改 stateful：Future.wait 并行检查 → 只渲染有数据卡片；
      监听 HomeDateController + task_*/diary_* 事件自动重查；防过期结果(日期快切守卫)；
      全空显示「这一天还没有记录」
- [x] 8.3 HomeDateController 新增 DateViewSortOption{def,priority,time} + setSortOption
- [x] 8.4 新建 widgets/home_date_sort_bar.dart(排序 chips 条，位于日期条下方)；
      home_screen_view 日期视图 Column 插入
- [x] 8.5 待办日卡应用排序：priority=index 升序；time=startTime??dueDate??startDate??createdAt
- [x] 8.6 l10n: home_dateViewNoData / home_sortDefault / home_sortPriority / home_sortTime
- [x] 8.7 dart analyze lib 全量 0 error
- 注：排序当前作用于待办卡的任务列表(日记一天一篇无需排序)；
  排序状态存内存(不持久化)，如需记忆后续可存 config

## 通用迁移模式（每个插件照此执行，已在 todo/diary 验证）

| 步骤 | 内容 | 产物 |
|------|------|------|
| 1. 抽条目 UI | 从插件页/列表中把单条数据的展示抽成独立组件（回调化：onTap/onStatus 等），插件原页面改为复用 | `plugins/X/widgets/x_item_card.dart` |
| 2. 注册日期卡 | `isDateDriven: true` + `hasDateData: (date)`（该日有无数据）+ builder：按 HomeDateController 日期过滤数据渲染条目 UI，交互能力与插件页一致 | `plugins/X/home_widgets/register_day_card.dart` |
| 3. 注册快速新建 | `QuickCreateItem` → onCreate 打开插件现有编辑表单，日期字段预填选中日期 | `plugins/X/home_widgets/register_quick_create.dart` |
| 4. 挂接注册 | 在该插件 `home_widgets/home_widgets.dart` 的 register() 里调用 2/3 | 修改 1 行 ×2 |
| 5. l10n | dayCardName/dayCardDesc(/dayCardEmpty) + quickCreate 三语 (zh/en/jp) | `plugins/X/l10n/*_translations_*.dart` |
| 6. 验证 | `dart analyze lib` 0 error；事件刷新接入（数据增删事件 → 卡片 rebuild；DateViewGrid 已监听 task_*/diary_*，新插件需把事件名加进 date_view_grid.dart 的监听列表） | — |

实现前勘察（每插件 10 分钟）：模型日期字段、条目 UI 所在文件、数据读取 API、编辑表单构造参数、事件名。
参考实现：`plugins/todo/home_widgets/register_day_card.dart`、`plugins/diary/home_widgets/register_quick_create.dart`。

---

## Phase 9: 高价值日历类（第一批，5 插件）[x] complete (2026-08-30)

### 9.1 calendar 日历（最高价值：日程即日期数据）[x] complete
- 条目卡：新建 `widgets/event_day_card.dart`（颜色条+标题+起止时间/全天+图标；头部计数+＋）
  数据 `controller.getAllEvents()`（本地+系统+todo 合并）按 startTime 同天过滤；
  点击 → `plugin.showEventDetails`（详情弹窗，能力与插件一致）；＋/快速新建 →
  EventEditPage(initialDate: 选中日期) 直接 push（不走 showEventEditPage，它用的是插件内 selectedDate）
- 注册 `home_widgets/register_day_card.dart`（id: calendar_day_card）+
  `register_quick_create.dart`（id: calendar_event）
- 刷新：AnimatedBuilder(controller + HomeDateController)；time 排序=startTime 升序
- l10n：dayCardName/Desc/Empty + calendar_allDay ×3

### 9.2 bill 账单 [x] complete
- 条目卡：新建 `widgets/bill_day_card.dart`（分类图标+标题/分类时间+收支金额红绿；头部计数+当日收支摘要）
  **按 bill.date（业务日期）过滤，不用 controller.getBills（它按 createdAt）**；
  点击 → BillEditScreen(bill: ...) 编辑；＋/快速新建 → BillEditScreen(initialDate:, accountId: 第一个账户)
- 注册 register_day_card（id: bill_day_card）+ register_quick_create（id: bill_bill, 名称复用 bill_newBill）
- 刷新：AnimatedBuilder(controller + HomeDateController)；事件 bill_added/deleted + account_*

### 9.3 activity 活动 [x] complete
- 条目卡：新建 `widgets/activity_day_card.dart`（开始时刻+时长+标题+标签chips+心情emoji）
  数据 `activityService.getActivitiesForDate(date)` 异步按日分片读取，startTime 升序；
  点击 → SmoothBottomSheet 85% 打开 ActivityEditScreen(activity:, showAsBottomSheet: true)（与时间线一致）；
  ＋/快速新建 → ActivityEditScreen(selectedDate:) 整页（表单自保存自 pop）
- 注册 register_day_card（id: activity_day_card）+ register_quick_create（id: activity_record）
- 刷新：stateful 异步加载（防过期守卫）+ activity_added/updated/deleted 事件 + 日期监听

### 9.4 tracker 追踪 [x] complete
- 条目卡：新建 `widgets/record_day_card.dart`（目标图标+名称+时刻+`+值单位`progressColor）
  数据 `controller.records` 按 recordedAt 同天过滤，goalById 关联目标；点击 → GoalDetailScreen
- ＋/快速新建共用 `openRecordCreateFlow(context, date)`：无目标→toast tracker_noGoals；
  单目标直接 / 多目标 SimpleDialog 选目标 → RecordDialog
- **修改 RecordDialog**：新增可选 initialRecordedAt 参数（日期预填），日期选择器
  initialDate 加了未来日期防护；记录归属日期未来时回退当前时刻（选择器 lastDate=now）
- 注册 register_day_card（id: tracker_day_card）+ register_quick_create（id: tracker_record）
- 刷新：AnimatedBuilder(controller + HomeDateController)（TrackerController 是 ChangeNotifier）

### 9.5 checkin 签到 [x] complete
- 条目卡：新建 `widgets/checkin_day_card.dart`（图标+名称+已签徽标(含次数)/未签圆圈）
  数据：`checkinItems` 按 frequency[weekday-1]（0=周一）排班过滤；
  **点击=切换该日签到**（自实现：已签→cancelCheckinRecord 最新一条+广播 checkin_cancelled；
  未签→addCheckinRecord(时间戳=选中日+当前时分秒)+广播 checkin_completed；不能用
  CheckinListController.toggleCheckin——它只认今天）
- **不注册快速新建**（签到是动作非表单，决策：日卡即入口）
- 注册 register_day_card（id: checkin_day_card）
- 刷新：EventListenerContainer(checkin_completed/cancelled/reset/deleted) + 日期监听
- hasDateData：该日有排班项 或 当天留有打卡记录

## Phase 10: 记录类（第二批，4 插件）[x] complete (2026-08-30)

### 10.1 habits 习惯 [x] complete
- 条目卡：新建 `widgets/habit_day_card.dart`（习惯图标+名称+`N次·共X分钟`/未完成+完成态图标；
  头部 已完成/总数）
  数据：getHabits() 同步 + 每习惯 getHabitCompletionRecords 异步按日过滤（Future.wait）；
  点击 → HabitMonthlyListScreen(habitId, habitTitle)
- 快速新建：HabitForm 包 Scaffold push（与插件页一致；**onSave 内需自行 pop——用 Builder
  context，不能用 onCreate 传入的主页 context**）；新建的是习惯本身，不预填日期
- 注册 register_day_card（id: habits_day_card）+ register_quick_create（id: habits_habit）
- 刷新：habit_completion_record_saved / habit_data_changed / habits_cache_updated + 日期监听
- hasDateData：任一习惯当天有完成记录

### 10.2 day 纪念日 [x] complete
- 新建 `widgets/memorial_day_edit_flow.dart`：模块级共享 DayController + openMemorialDayEditor
  （编辑走 update/删除走 delete/新建走 add，与 DayHomeScreen._showEditDialog 同构；
  预填=传 MemorialDay(title:'', targetDate:日期)，保存时 page 内重新生成 id）
- 日卡直接在 register_day_card 内实现（复用 DayCardHeader+自绘紧凑行：圆形图标/首字+
  标题+今天/还剩N天/已过N天，色随状态）；点击 → 编辑流程
- **不监听 memorial_day_cache_updated**：hasDateData 会 reloadData 并广播它，
  监听会形成无限刷新循环（date_view_grid 同样排除该事件）
- 注册 register_day_card（id: day_day_card）+ register_quick_create（id: day_memorial）
- hasDateData：当天有 targetDate 同日的纪念日（严格同日策略；"临近N天"未做，可后续扩展）

### 10.3 notes 笔记 [x] complete
- 条目卡：新建 `widgets/note_day_card.dart`（笔记图标+标题(无标题兜底)+首标签+HH:mm）
  数据：getAllNotes() 展平，**按 updatedAt 或 createdAt 同天过滤**（创建或修改过都算），updatedAt 倒序；
  点击 → NoteEditScreen(note:, onSave: updateNote 构造新 Note 带 updatedAt=now)（与插件页同构）；
  ＋ → NoteEditScreen(onSave: createNote(..., 'root'))；编辑器自 pop
- 注册 register_day_card（id: notes_day_card）+ register_quick_create（id: notes_note，不预填日期）
- 刷新：note_added/updated/deleted + notes_refresh + 日期监听（NotesController 非 ChangeNotifier）

### 10.4 calendar_album 日记相册 [x] complete
- 条目卡：新建 `widgets/album_day_card.dart`（标题+mood+缩略图行：thumbUrls??imageUrls?
  extractImagesFromMarkdown，最多3张+溢出计数，FutureBuilder ImageUtils.getAbsolutePath→Image.file）
  数据：plugin.getEntriesForDate(date) 同步按日分片；点击 → EntryDetailScreen(entry)（直接 push）；
  ＋/快速新建 → EntryEditorScreen(initialDate:, isEditing: false)（长按日期新建同款）
- 注册 register_day_card（id: calendar_album_day_card，默认 Wide2）+
  register_quick_create（id: calendar_album_entry）
- 刷新：calendar_entry_added/updated/deleted + 日期监听

## Phase 11: 排除项与特殊处理 [x] complete (2026-08-30)
- **公共组件**：新建 `screens/home_screen/widgets/day_card_header.dart`（周几+日期+计数徽标+
  可选摘要+＋按钮，视觉同 TodoDayCard 头部），9 张新日卡共用
- **reminder / timer / contact**：维持排除（reminder 未接入注册体系；timer 无表单；contact 低价值）
- **不适用日期卡**：chat、agent_chat、openai、nfc、tts、webview、scripts_center、store、nodes、
  database、goods（未动；如需"快速新建"可后续单独加 QuickCreateItem）
- **date_view_grid 事件列表已扩充**：calendar_event_*×4 / bill+account_*×4 / activity_*×3 /
  onRecordAdded + tracker_cache_updated / checkin_*×4 / habit_*×3 / memorial_day_*×3(不含
  cache_updated，防循环) / note_*×3 / calendar_entry_*×3
- **dart analyze lib 全量 0 error**（154 warning/info：基线 152 + 2 个 IconData
  non_const warning，与 bill/habits/tracker 既有代码同款模式）
- 全部快速新建名称复用既有 l10n key（calendar_quickAddEvent / bill_newBill /
  activity_addActivity / tracker_addRecord / habits_newHabit / day_addMemorialDay /
  notes_newNote / calendar_album_new_entry），新 key 仅 dayCard 三件套（+少量辅助 key）×3 语

## 批次执行建议
- 每批 1 个会话完成（Phase 9 ≈ 5 插件 × 6 步；Phase 10 类推）
- 顺序：9.1 calendar → 9.2 bill → 9.3 activity → 9.4 tracker → 9.5 checkin（按价值排）
- 每个插件完成后在 progress.md 记录文件清单，Phase 内勾选
- ✅ 已按此顺序全部完成（Phase 9+10 同会话完成）

## 手动验证清单（Phase 9/10 新增部分，待用户跑 app 验证）
- 日期视图切到有数据的日期：出现对应日卡（日历/账单/活动/追踪/签到/习惯/纪念日/笔记/相册）
- 各日卡点击条目 → 打开对应详情/编辑页，行为与插件页一致
- 各日卡 ＋ 按钮 / 底部快速新建对话框：出现 8 个新条目，打开编辑器且日期预填选中日
  （checkin 无快速新建项属预期；habits/notes 不预填日期属预期）
- checkin 日卡点击签到项：签到/取消即时生效，插件页状态同步
- 无数据日期：对应日卡隐藏；全无数据显示「这一天还没有记录」
- 数据增删后（插件页内操作）：日期视图卡片即时出现/消失

## 后续可选增强（未做，与插件迁移独立）
- 日期视图卡片的自定义摆放（当前固定为注册顺序+默认尺寸）
- 日期条无限滚动 / 月份跳转
- 排序选项持久化

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
