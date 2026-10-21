# 启动性能观测（2026-10-21）

环境：Windows、Flutter debug、本地存储、恢复上次使用的 chat 插件。通过 procm 后端启动 `flutter run -d windows`，读取进程 stdout/stderr；没有使用浏览器。

## 测量口径与结果

`[Startup] +Nms` 从 Dart `main()` 开始计时，**不包含 Flutter 编译、原生进程创建和进入 main 之前的耗时**。`destination_frame` 表示启动目标页面的一帧构建完成，不代表转场动画结束或所有后台服务完成。

| 阶段 | 优化前冷启动 | 优化后冷启动 1 | 优化后冷启动 2 |
| --- | ---: | ---: | ---: |
| 首帧光栅化（加载页） | 1156ms | 1277ms | 1242ms |
| 全部插件就绪 | 2288ms | 1680ms | 1635ms |
| 目标页面首帧构建结束 | 2727ms | 2067ms | 2032ms |

目标页面减少约 24%～25%；首个加载页没有改善。基线只有一次，debug 下的 JIT、机器负载及网络会影响数据，这不是 release 或移动端性能结论。

## 已完成优化

1. 脚本商场、WebView 应用商场初始化只读取本地配置和安装信息；网络目录改到对应页面创建后的首帧回调加载。原来每次启动都等待网络目录（单请求超时上限 30 秒），导致整个启动页受网络状态影响。已有目录会复用，源切换与手动重试保持原入口。
2. QuickJS 执行器检测到结果就绪后立即结束预热轮询，并在普通轮询的等待间隔前检查结果。原来每次执行都等待 50 × 10ms，之后还额外等待 50ms。脚本中心引擎初始化的热重启观测从 1225ms 降至 117ms。
3. 添加核心阶段、每个插件、脚本中心子阶段、首帧和目标页面的计时。使用同步终端输出，避免 `debugPrint` 限流使日志时间戳失真。release 默认关闭，可通过 `--dart-define=STARTUP_TRACE=true` 启用。

## 验证与复查

- 7 项测试通过：QuickJS 快速结果（包含零和空字符串）、异步 Dart 回调、脚本异常、超时，以及现有启动导航栈、配置顺序写入测试。
- 修改文件的静态分析没有错误；保留 `ScriptStoreManager._storage` 原有的 unused_field 警告。
- 两次冷启动没有初始化失败日志。未手动操作商场 UI；页面加载触发点经过代码检查。
- 本次观测进程：`app-windows-startup`，ID `skD_RPlA`。进程重启会重置日志，以下命令读取当前这一轮。

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:7331/api/processes/skD_RPlA/logs?grep=Startup&count=250"

# 完整冷启动：通过 procm 重启，而不是使用 Flutter 热重启 R。
Invoke-RestMethod -Uri "http://127.0.0.1:7331/api/processes/skD_RPlA/restart" -Method Post -ContentType "application/json" -Body "{}"

# Windows QuickJS 测试需要已构建的原生 DLL。
$env:PATH = "D:/about-me/build/windows/x64/runner/Debug;" + $env:PATH
flutter test "test/mobile_js_engine_test.dart" "test/startup_navigation_stack_test.dart" "test/plugin_manager_config_save_test.dart"
```

## UI 优先与页签按需构建（第二轮）

按照“先显示 UI，其他延后加载”的要求：

- `runApp` 立即绘制不依赖配置、存储和插件的启动壳，等首帧光栅化后才初始化核心服务；核心服务失败时显示失败提示，避免构建依赖未就绪全局变量的页面。
- 真实应用导航树完成首帧后再启动插件初始化；目标页面完成一帧后再启动通知权限、语音配置、小组件、移动端 Firebase/FCM 等服务。
- 首页五个页签、脚本中心三个页签、WebView 两个页签改为首次访问时构建，访问后保留状态，隐藏页停止 Ticker 动画。商场网络目录因此在首次进入商场页签时才请求。
- 小组件初始 URI 等待插件实际就绪，加载遮罩保留导航树；启动期间恢复前台不再提前访问插件数据。

第二轮两次完整冷启动（同一 Windows debug 环境）：

| 阶段 | 第一轮优化后冷启动 2 | UI 优先冷启动 1 | UI 优先冷启动 2 |
| --- | ---: | ---: | ---: |
| 首帧光栅化（启动壳） | 1242ms | 254ms | 268ms |
| 真实应用导航树首帧结束 | 未记录 | 910ms | 910ms |
| 全部插件就绪 | 1635ms | 1498ms | 1437ms |
| 目标页面首帧构建结束 | 2032ms | 1831ms | 1757ms |
| 低优先级服务开始 | 未记录 | 1837ms | 1763ms |

首个可见 Flutter UI 提前约 78%～80%，目标页面提前约 10%～14%。另一次热重启首帧为 329ms、目标页面为 1660ms；热重启数据不作为冷启动对照。两次冷启动未发现初始化失败或异常日志，保留第三方原生插件的 CMake 构建警告。没有手动操作完整应用页签，状态保留和按需构建通过 widget 测试验证。

当前先显示的是启动界面，目标页面仍等待插件就绪；尚未把所有插件的数据初始化改成首次使用才执行。已访问页签的网络订阅或业务计时器不会被 TickerMode 自动暂停。移动端 Firebase 延后初始化的行为尚未在真机验证。

新增测试覆盖启动壳初始化屏障、失败提示、异步完成时已卸载、页签首次构建/状态保留/参数更新/隐藏 Ticker，以及小组件加载期间保留 Navigator。共 12 项不同测试通过（11 项基础测试，以及单独运行的小组件导航补充测试；现有启动导航测试也随补充测试重新通过）。修改文件静态分析无错误或警告。

复查命令在前述测试列表后添加 `"test/lazy_startup_widgets_test.dart" "test/widget_uri_handler_test.dart"`。后续优先在 release/profile 和目标移动设备复测，再评估插件初始化依赖，逐步缩小目标页面等待范围。
