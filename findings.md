# 研究发现：home_grid 卡片体系与插件条目 UI

## 10. Live2D 在线模型与语音任务（2026-09-05）
- Live2D 使用路径依赖 `/Users/Zhuanz/Documents/flutter_live2d-main`；macOS 链路为 Flutter AppKitView → Swift WKWebView → 本地 HTTP 服务 → Cubism Web runtime。
- 当前原生反向事件已有 `onContextMenu`、`onTap`；点击由 Web runtime 命中 HitAreas 后回传 Dart。
- 在线模型参考 `/Users/Zhuanz/Documents/galgenai/utils/repoUtils.ts`：解析 Eikanya JSON 树，只接受 `.model.json` / `.model3.json`，URL 基址为 `https://cdn.jsdelivr.net/gh/Eikanya/Live2d-model@master/`。
- 当前模型差异很大：HitArea 名称可能为空、甚至完全没有 HitAreas；区域绑定需优先使用稳定的 Id，并允许模型级随机兜底。
- macOS 用户正在运行自己的调试实例，验证时不得操作该实例；只启动/终止我方单独的 Debug 二进制。
- `asset_cache.dart` 已把带 scheme 的 `modelDir` 原样传给平台；阻断远程模型的是 macOS Swift `loadModel`：它一律构造 `fileURLWithPath` 并校验本地文件存在。最小修复是在 Swift 识别 http/https，直接把远程目录 URL 传入 JS runtime。
- Web runtime `LAppModel.startMotion()` 已通过 `getMotionSoundFileName(group, no)` 读到模型动作的 voice 文件名，并调用 `_wavFileHandler.start(modelDir + voice)` 播放；底层语音能力已有，缺的是 app 可发现的动作/语音元数据与点击区域绑定策略。
- about-me 当前本地模型动作列表是手写 `_Live2DMotion`；在线模型需请求其 model JSON 并解析 `FileReferences.Motions`，生成动作组/索引及 `Sound` 标记，才能避免试探不存在动作造成错误状态。
- 点击策略可统一为：优先 `Tap<规范化区域>`；未找到时，本地模型沿用默认动作，在线模型优先随机选择带 `Sound` 的动作，从而做到“如果模型提供语音则随机播放”。
- Eikanya 目录 JSON 地址确认是 `https://guansss.github.io/live2d-viewer-web/eikanyalive2d-model.json`；目录可直接请求且结构与参考 `parseRepoData` 一致。
- 目录统计：1061 个 `.model3.json`、256 个 Cubism 2 `.model.json`。当前 `CubismModelSettingJson`/moc3 runtime 仅支持 Cubism 3/4，因此在线页只列 `.model3.json`，避免可预见的加载失败。
- `LAppWavFileHandler` 名义上处理 WAV，但实现仅 fetch/decode PCM 并提供 RMS 做口型，没有 `Audio`/`AudioContext` 输出，所以用户听不到声音。需要同时启动 HTML audio 播放，并在切换语音/释放模型时停止旧音频。
- app 的 macOS entitlements 已有 `com.apple.security.network.client=true`，无需新增网络权限。
- 真实仓库验证：`三色绘恋S/chiguo_A` 的 `Act[0]` 含 `Sound: voice/cg_01066-01067.wav`；对应 jsDelivr 资源返回 HTTP 200、`audio/wav`、`access-control-allow-origin: *`，与解析和播放路径一致。
- 用户实测远程模型在 Dart 层失败：`_resolveModelDir` 只有 `kIsWeb` 分支会接受 URI scheme，macOS 的 HTTP(S) URL 落入 `_extractAssetDirToCache`，因此尚未到达已实现的 Swift 远程分支。
- 目录解析失败时 `Live2DViewController.loadModel` 仅关闭 `isLoadingModel`，旧 `loadedModel` 和原生模型仍保留；about-me 又继续处理 `onTap`，导致向旧 `/model/` 根目录发送在线模型动作索引。
- 修复策略：HTTP(S) 在 `_resolveModelDir` 的平台判断之前直接返回；about-me 模型切换先 `unloadModel`，平台视图保持挂载但用不透明加载占位覆盖，并在切换期间忽略 tap。
- `Live2DViewState.loadedModel` 文档声明失败加载会清空，但 controller 的异常 catch 只更新 `isLoadingModel`；需同步清空状态，避免调用方继续把旧模型视为可交互。
- `mori_miko` 已进入远程 runtime，但其约百个预加载动作中有部分 motion3 元数据不兼容、部分 fetch rejection。`preLoadMotionGroup` 没有 catch，且通过减少 `_allMotionCount` 结算失败，异步并发下既会遗漏 rejection，也可能提前完成；实测因此停在 `WaitLoadMotion` 直到 75 秒超时。
- 在线模型应允许“主体可加载、坏动作跳过”：固定总数，每个动作请求在 finally 中只结算一次，只有所有动作尝试结束后进入纹理阶段。
- `mori_miko` 动作结算修复后已进入纹理/shader 阶段，但近百个动作请求占满远程加载队列，75 秒时才开始渲染并被 native timeout 清理；纹理本身为可访问的 4096x4096 PNG（约 5.9 MB，CORS 正常）。
- 远程模型不应在首屏预加载全部动作：上限 24，优先带 Sound、Idle、Tap，再按模型顺序补足；app 动作清单使用同一筛选，保证不会随机选择未预加载动作。本地模型维持全部预加载。
- 用户追加要求加载百分比、错误占位和点击重试。现有链路只有整体 loadModel Future，需新增资源阶段进度事件；单个 motion HTTP 403 应继续作为非致命资源错误跳过，只有模型配置、moc/纹理等主体失败才进入错误占位。
- macOS 已用 `window.webkit.messageHandlers.flutterLive2D` 上报 tap，Swift 再通过 `flutter_live2d` MethodChannel 调 Dart；加载进度可复用同一链路新增 `loadProgress`，无需引入 EventChannel。
- `LAppModel` 现有 `LoadStep` 状态机可映射为近似百分比；这代表加载阶段完成度，不是网络字节下载进度。致命资源 fetch 当前部分只写日志并可能等到超时，需要同步暴露失败状态供 runtime 立即抛错。
- Aboutme 当前底部状态标签已读取 `Live2DViewState.lastError`，但主体占位只在 `_isSwitchingModel` 时出现，错误后不可交互；应统一为 loading/error 两态覆盖层并在 error 态绑定 retry。
- `Live2DViewState` 当前仅有 `isLoadingModel/loadedModel/lastError`，需增加 `modelLoadProgress` 与 `modelLoadStage`，在 attach/load/unload/detach 的生命周期中清理或更新。
- 进度采用阶段完成度：配置 2%-10%、MOC/组件 10%-55%、动作 55%-80%（按 settled/total）、纹理 82%-98%（按 loaded/total）、完成 100%。该数值稳定可解释，但不是 HTTP 字节进度。
- macOS 平台视图可能吞掉 Flutter 覆盖层点击；错误重试除 Flutter `GestureDetector` 外，还要复用 runtime 原生 `onTap` 回调：未加载且存在 `lastError` 时调用当前模型重试。
- 用户日志中的 motion HTTP 403 是非致命动作资源错误，应结算该动作后继续；不进入整体错误占位。配置/MOC/纹理/超时才作为致命错误。
- 用户实测 `l2d00055（凍京Nerco/l2d）` 主体加载成功，但每个动作均报 `The number of segment/point does not match the metadata`、`Inconsistent motion3.json`、`Failed to create motion from buffer`；点击随后报 `Can't start motion motions/tap3.motion3.json`。根因已收敛到旧 motion3 元数据与 Cubism SDK 6 严格校验不兼容，而非 URL、索引或渲染循环。
- 同份日志还出现 `DSLoadingDots` 内部 Row 在 22px 宽约束下溢出 6.1px，需要确认调用位置是否为本轮 Live2D 占位并做局部适配。
- `l2d00055.model3.json` 为 Cubism 3，14 个动作全部位于空名称动作组；示例 `tap3.motion3.json` 也是 `Version: 3`，曲线 Segments 编码可读，但声明 `TotalSegmentCount=210/TotalPointCount=294` 被 SDK 6 判定与实际不一致。
- 正常 Mao 动作同样为 Version 3，但元数据与曲线吻合。兼容方向应优先使用 Cubism loader 已有的 consistency 开关，仅对远程旧动作放宽元数据一致性校验，不修改正常动作文件或全局关闭校验。
- `DSLoadingDots(size: 6)` 在在线模型页的 22px 尾部区域理论宽度约 27.4px，正好对应日志中溢出 6.1px；应把该处 size 调到 4.5 左右，而非修改全局加载组件。
- 对 14 个动作逐一计算：`TotalSegmentCount` 全部比真实 segment 数多 1，`TotalPointCount` 全部比真实 point 数少 36（37 条曲线，等价于旧导出器几乎未计每曲线起点），属于稳定的旧导出器元数据错误。
- 最稳妥兼容方式是在调用 Cubism `loadMotion` 前解析 JSON，仅当统计不一致时重算 `CurveCount/TotalSegmentCount/TotalPointCount` 并重新编码；正常 motion3 原字节直接透传，继续保留 SDK 一致性校验。
- SDK `CubismMotion.parse` 会按 Meta 声明的 segment/point 数预分配数组，说明仅关闭一致性检查并不安全；重算 Meta 是必要修复。
- `l2d00055` 不声明 `Idle` 组，所有动作在空组，循环动作通过文件名 `*_loop.motion3.json` 表示。runtime 自动待机固定调用 `Idle`，因此还需在 Idle 组缺失时优先从空组中选择文件名含 `loop` 的动作。

## 11. Live2D 显示裁剪区域（2026-09-05）

- 用户要求右键菜单新增裁剪设置：对话框展示完整模型图片，使用 `crop_your_image` 选择区域，并应用到主页显示。
- 项目已依赖 `crop_your_image ^2.0.0`，pub.dev 最新版本同为 2.0.0，无需改依赖。
- Windows Live2D 是 Flutter `Texture`，可用独立 `RepaintBoundary.toImage()` 捕获；macOS/iOS 为原生平台视图，Flutter 图层截图可能为空，必须检测并显示错误。
- `crop_your_image` 2.0.0 支持 `InitialRectBuilder.withArea(ImageBasedRect)`、`onMoved(ViewportBasedRect)`、自由比例选区和外部 `CropController`。
- 本功能不需要保存裁后 PNG；应保存选区在完整预览图中的归一化坐标，再映射为实时 Live2D 的平移/缩放。
- 本地 2.0.0 源码确认 `onMoved` 签名为 `(viewportRect, imageRect)`，第二个参数就是实际原图坐标 `rectToCrop`；可直接除以原图宽高得到归一化 Rect。
- 裁剪框固定为完整 Live2D 视口的 1:2 比例，避免应用到实时画面时拉伸；完整区域为 `(0,0,1,1)`，重置删除该模型的自定义值。
- 实时映射使用固定 180x360 源视口：先把归一化选区平移到原点并按 `1 / rect.width` 放大，再裁到源视口；外层继续复用人物尺寸缩放与 Windows 水平/底线补偿。
- 截图会抽样检查 RGBA alpha；平台视图未被 Flutter 截入时拒绝打开空白编辑器并展示可读错误。
- 持久化键为模型目录+文件名的 base64url，避免本地/在线同名模型互相覆盖；完整区域通过删除键恢复默认。
- Windows Debug 构建在最终复制 WebView2Loader.dll 时被用户正在运行的 app PID 20568 锁定；Dart analyze 与测试已通过，实际 Texture 截图仍需用户热重启后验收。

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
# Windows 编译依赖冲突（2026-09-05）

- 可重复信号：`flutter analyze lib/main.dart lib/utils/file_picker_helper.dart` 稳定产生 9 个 error。
- `adaptive_theme 3.8.0` 的入参类型来自 `material_ui-1.1.1/lib/src/theme_data.dart`，项目主题来自 Flutter SDK，两者不可赋值。
- `pubspec.yaml` 将 `file_picker ^6.1.1` 又用 Git `master` 覆盖；当前 master 已无 `FilePicker.platform`。
- CMake CMP0175/CMP0153 和 Firebase SDK 最低版本提示均是 warning，不是此次 build exit 1 的根因。
- pub.dev 版本元数据确认：`adaptive_theme 3.7.2` 仅依赖 Flutter + shared_preferences，`3.8.0` 新增 material_ui/cupertino_ui。
- 移除 Git 覆盖后 `file_picker ^6.1.1` 解析为 `6.2.1`，保留 `FilePicker.platform` API；Flutter 3.44 会输出旧联邦插件声明 warning，需用 Windows build 判定是否阻塞。
- 全量 analyze 发现 6.2.1 缺少项目所需 `saveFile(bytes:)`，不可用。官方 API 文档确认 10.3.0 同时具备 `.platform` 和 `bytes:`；10.3.11 已移除 `.platform`，因此精确固定 10.3.0。
