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

后续优先在 release/profile 和目标移动设备复测，再根据日志评估首帧前的插件竞争及 agent_chat 初始化；本轮没有调整插件依赖顺序或提前开放未初始化插件。
