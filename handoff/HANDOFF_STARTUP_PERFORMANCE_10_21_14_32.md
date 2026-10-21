# Handoff: Flutter 启动性能优化与延迟加载

**创建时间：** 2026-10-21 14:40 +08:00  
**分支：** `main`  
**HEAD：** `e27d1372 fix`  
**工作目录：** `D:/about-me`

---

## 摘要

本轮针对 Flutter Windows 启动慢，完成启动性能埋点、启动壳优先显示、非首屏数据延迟加载，以及启动目标插件优先初始化。最终观测到启动壳首帧约 253ms、目标页面首帧约 1711ms；优化代码已在当前 HEAD 中，`flutter run -d windows` 仍由 procm 运行。尚未手动验收所有延迟加载入口，也未在 release/profile 或移动设备上测量。

## 已完成工作

### 改动

- [x] 添加启动阶段计时，记录首帧、应用壳、关键插件、目标页面、全部插件和延迟服务启动时间。
- [x] `runApp` 先显示独立启动壳；首帧后再初始化核心服务，应用导航树绘制后再启动插件初始化。
- [x] 启动闸门仅等待当前目标插件：恢复上次插件时等待对应插件，正常主页启动时等待 Live2D。其他插件仍并行注册，全部完成后发布 `plugins_ready`。
- [x] 首页、脚本中心、WebView 页签在首次访问时构建，并保留已访问页状态；隐藏页通过 `TickerMode` 暂停动画。
- [x] Agent Chat 工具服务、工具模板和聊天 AI 线程改为按需初始化/加载。
- [x] 延后通知权限、语音设置、小组件、移动端 Firebase/FCM 等低优先级服务。
- [x] 记录基线、优化结果和验证口径于 `docs/startup-performance.md`。

### 关键决策

| 决策 | 原因 |
| --- | --- |
| 插件继续后台并行注册，只让启动目标插件成为导航屏障 | 全量等待会让用户等待不相关插件；完全按首次使用注册则有现存单例和路由依赖风险。 |
| 仅对非首屏数据做按需加载 | 工具索引、工具模板和 AI 线程在对应功能使用时才需要。 |
| 启动日志使用同步终端输出 | 避免 `debugPrint` 限流令日志时间戳失真；release 默认关闭，可用 `--dart-define=STARTUP_TRACE=true` 启用。 |
| 保持小组件加载期间的 Navigator 树 | 避免加载遮罩导致导航上下文被卸载。 |

## 文件影响

主要优化文件：

- `lib/core/services/startup_trace.dart`：启动计时工具。
- `lib/core/widgets/app_bootstrap.dart`、`lib/core/widgets/lazy_indexed_stack.dart`：启动壳和延迟构建页栈。
- `lib/main.dart`、`lib/core/app_initializer.dart`、`lib/screens/startup/startup_gate.dart`：启动阶段编排及关键插件闸门。
- `lib/screens/jelly_home/jelly_home_screen.dart`、`lib/plugins/scripts_center/scripts_center_plugin.dart`、`lib/plugins/webview/screens/webview_main_screen.dart`：页签按需构建及页面加载时机。
- `lib/core/js_bridge/platform/mobile_js_engine.dart`、`lib/core/services/fcm_service.dart`、`lib/core/services/window_geometry_service.dart`：初始化/预热延迟优化。
- `lib/plugins/agent_chat/agent_chat_plugin.dart`、`lib/plugins/agent_chat/controllers/chat_controller.dart`、`lib/plugins/agent_chat/services/tool_template_service.dart`、`lib/plugins/agent_chat/screens/tool_template_screen/tool_template_screen.dart`：Agent Chat 工具懒加载。
- `lib/plugins/chat/services/chat_data_service.dart`、`lib/plugins/chat/services/ai_thread_service.dart`、`lib/plugins/chat/screens/chat_screen/chat_screen.dart`：按频道加载 AI 线程。
- `test/lazy_startup_widgets_test.dart`、`test/widget_uri_handler_test.dart` 及相关既有测试：启动壳、懒构建页栈和导航行为验证。
- `docs/startup-performance.md`：三轮测量和限制说明。

当前工作区还有未提交的 design-system 改动，与启动优化无关，属于用户已有工作，请保留：

- 修改：`lib/design_system/components/jelly_box.dart`、`lib/design_system/tokens/colors.dart`、`lib/design_system/tokens/shadows.dart`、`lib/design_system/tokens/sketch.dart`
- 新增：`lib/design_system/components/focus_ring.dart`、`lib/design_system/components/ink_splash.dart`、`lib/design_system/tokens/motion.dart`

procm 运行状态文件 `.procm-mcp/processes.json`、`.procm-mcp/rooms.json` 也会随进程状态变化；不要将它们误认为业务源代码。

## 技术与测量上下文

- 环境：Windows、Flutter debug、本地存储，恢复上次使用的 Chat 插件；由 procm 启动 `flutter run -d windows`。
- `Startup` 计时从 Dart `main()` 开始，不包括 Flutter 编译、原生进程创建以及进入 `main()` 前的时间。
- `destination_frame` 是目标页面一帧完成，不代表转场动画结束或所有后台服务完成。
- 优化后最近一次冷启动日志：

```text
first_frame_rasterized=253ms
app_shell_frame=885ms
critical_plugins_ready=1372ms
plugins_ready=1398ms
destination_frame=1711ms
deferred_services_begin=1718ms
```

- 对照初始基线：启动壳首帧从约 1156ms 降至 253ms；目标页首帧从约 2727ms 降至 1711ms。测量次数少且受机器负载影响，见 `docs/startup-performance.md` 的完整表格。

## 当前运行进程

- 名称：`app-windows-startup`
- procm ID：`skD_RPlA`
- 状态：`running`，PID `16524`
- 命令：`flutter run -d windows`
- 工作目录：`D:/about-me`
- procm HTTP 后端：`http://127.0.0.1:7331`

查询当前进程和日志：

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:7331/api/processes/skD_RPlA"
Invoke-RestMethod -Uri "http://127.0.0.1:7331/api/processes/skD_RPlA/logs?grep=Startup&count=250"
Invoke-RestMethod -Uri "http://127.0.0.1:7331/api/processes/skD_RPlA/logs?grep=Exception%7CError%7C失败&count=50"
```

完整冷启动（会重置这一进程的日志）：

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:7331/api/processes/skD_RPlA/restart" -Method Post -ContentType "application/json" -Body "{}"
```

## 验证状态

- 静态分析：启动优化涉及的 Dart 文件通过 `flutter analyze`，无错误或警告。
- 测试：12 项通过，包括懒页栈、启动壳、Widget URI 导航、JS 引擎、启动导航栈和插件配置保存测试。
- 启动观测：Windows debug 多轮冷启动完成，最近一轮关键阶段见上方日志；未发现初始化异常。
- 未完成：未手动点击验收所有页面和延迟加载入口；未在 release/profile、移动端真机验证。

复跑测试时，Windows QuickJS 需要先把原生 DLL 加到 PATH：

```powershell
$env:PATH = "D:/about-me/build/windows/x64/runner/Debug;" + $env:PATH
flutter test "test/lazy_startup_widgets_test.dart" "test/widget_uri_handler_test.dart" "test/mobile_js_engine_test.dart" "test/startup_navigation_stack_test.dart" "test/plugin_manager_config_save_test.dart"
```

## 注意事项和已知风险

- Chat 恢复启动与 OpenAI 插件有潜在交叉依赖；当前日志两者几乎同时完成。应手动恢复 Chat 插件验证。如果出现未初始化单例访问，再考虑把 OpenAI 纳入关键依赖集合。
- 关键插件页面可能在其他依赖插件尚未完成时构建；如发现具体依赖问题，按页面实际依赖扩展屏障，不要直接恢复全插件等待。
- `TickerMode` 只暂停动画，不会自动暂停已经访问页面的网络订阅或业务计时器。
- Agent Chat 模板页第一次打开、首次发送消息、Chat 频道首次加载 AI 线程的行为尚缺少完整手动验收。
- 移动端 Firebase 延后初始化还没有真机验证。
- `.gitignore` 忽略常见构建产物（如 `build/`、`.dart_tool/`、`node_modules/`）和 `*.log`；当前用户未提交的 design-system 源码不被忽略。

## 下一步

### 立即开始

1. 使用当前运行实例手动验收：主页五个页签切换与状态保留、脚本中心/商店、WebView 商店、恢复 Chat 插件、Agent Chat 首次发送与模板页首次打开、Chat 频道 AI 线程入口。
2. 若 Chat 恢复启动有单例初始化异常，先读取 procm 错误日志，再将 `openai` 纳入关键插件依赖并补充对应测试。
3. 进行 release/profile 和目标移动设备启动测量，分别记录原生启动耗时和 Dart 启动阶段时间。

### 后续

- 有手动验收或设备证据后，再考虑缩小关键插件依赖等待范围。
- 更新 `docs/startup-performance.md`，记录新环境及相同口径的重复测量。
- 用户未提交的 design-system 改动需要独立保留和处理，不要混进启动优化的提交。

### 阻塞

当前没有阻塞项；手动 UI 验收和移动设备测量需要相应设备/操作环境。

---

交接文件由当前会话根据仓库状态、procm 运行信息和启动性能记录生成。
