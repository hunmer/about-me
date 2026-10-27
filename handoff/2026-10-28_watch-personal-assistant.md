# Apple Watch 个人助手语音链路交接

日期：2026-10-28  
工作区：`/Users/Zhuanz/Documents/Aboutme`  
分支：`main`，交接时 HEAD 为 `c1623b59 fix`。本任务未提交、未推送。

## 用户目标与当前状态

原始需求：修改 `ios/aboutme Watch App/ChatGPTTestView.swift` 的演示效果和占位内容，实现手表录音、转发给 iPhone 的 `personal_assistant` 请求 AI，再将结果返回手表。

实现已完成并向用户交付。最后一条用户要求是将当前会话交接文档保存到工作区现有 `handoff` 目录，因此本文件保存于此。没有收到进一步修复、扩展、提交或发布要求。

使用方法、链路参数、消息协议和真机验收步骤已集中记录在 **`docs/WATCH_PERSONAL_ASSISTANT.md`**，下一会话应先读该文件，不在本文件重复完整说明。

## 本会话实际修改范围

只将以下文件视为本任务改动；不要把共享工作区的其他修改归入本任务。

| 文件 | 用途 |
| --- | --- |
| `ios/aboutme Watch App/ChatGPTTestView.swift` | 将自动循环动画改为真实录音和对话界面，保留云球视觉，加入音量反馈、错误提示、未完成请求恢复。 |
| `ios/aboutme Watch App/WCSessionManager.swift` | 音频文件传输、结果轮询、一次性 continuation 回复、传输失败持久化和文件清理。 |
| `ios/aboutme Watch App/ContentView.swift` | 演示入口改名为「个人助手」。 |
| `ios/aboutme Watch App/Info.plist` | 手表麦克风用途说明。 |
| `ios/Runner/WCSessionManager.swift` | 文件接收和同步复制、Speech 转写、Flutter 桥接、状态缓存和去重。 |
| `ios/Runner/Info.plist` | iPhone 语音识别用途说明。 |
| `lib/plugins/agent_chat/services/watch_connectivity_service.dart` | 注册 `onAssistantAudio` handler，并发送就绪通知。 |
| `lib/plugins/personal_assistant/services/watch_assistant_service.dart` | 新增 Dart 助手处理服务，串行请求内置助手并回写最终状态。 |
| `test/watch_assistant_service_test.dart` | 新增输入校验、去重和失败后队列继续处理的测试。 |
| `docs/WATCH_PERSONAL_ASSISTANT.md` | 新增使用和技术说明。 |
| 本文件 | 当前交接摘要。 |

关键原有代码参考：

- `lib/plugins/personal_assistant/screens/personal_assistant_screen.dart` 的 `_initialize()`：个人助手原有会话和控制器准备方式。
- `lib/plugins/openai/services/chat_assistant_service.dart`：内置助手配置及 `builtinAgentId`。
- `lib/plugins/agent_chat/controllers/chat_controller.dart`：`initialize()`、`sendMessage(bypassAliveness: true)`、`cancelSending()`。
- `lib/plugins/agent_chat/services/conversation_service.dart`：临时会话创建和路由复用。
- `ios/aboutme Watch App/aboutmeApp.swift`：原有启动入口直接导航到 `ChatGPTTestView`，本会话未改。

## 需要延续的实现决策

- 音频使用 `transferFile`，避免通过即时消息承载录音文件；结果使用短请求轮询，不持有跨 ASR/AI 请求的 WatchConnectivity replyHandler。
- iPhone 现有腾讯 ASR 仅支持实时 PCM 流，未提供 m4a 文件转写入口，因此本次使用系统 Speech framework 的中文文件识别。
- 手表与手机复用同一个内置个人助手 Agent，但手表按 `sessionId` 使用独立临时会话，防止手机页面与后台控制器互相覆盖消息。
- Dart 使用 `sendMessage(bypassAliveness: true)` 等待完整工具循环，检查新消息的 `metadata['requestError']`，再回传本轮最后一条已完成的顶层回复。
- 查询重试只使用原 `requestId`，不重新提交 AI 操作。手表将未完成编号保存到 UserDefaults；已完成/明确失败后清除。
- iPhone 重启后不会自动重跑处理中请求，而是返回中断失败；对于可能已经产生的记录操作，错误提示要求先检查结果，避免重复创建。
- Dart 新控制器初始化会改动 `MomentsService` 全局上下文；服务结束时，仅在全局仍指向本次 MessageService 时恢复先前上下文，再释放资源。

最终原生审阅已修复的关键边界：

1. `didReceive file` 返回前同步复制系统临时文件。
2. 等待 iPhone App 前台和 Flutter ready 后开始授权/识别，并监听 App 激活通知继续待处理录音。
3. 串行进行录音识别，避免授权或识别重入。
4. 严格要求 Dart 返回 `{accepted: true}`。
5. Speech 取消后的迟到回调不会继续覆盖状态。
6. 完成/失败终态不会被后来的状态回调覆盖。
7. 手表监听系统音频中断，退出卡住的录音状态；传输失败信息可跨手表进程恢复。

## 已执行的验证及可信边界

最终结果：

- 全部 Watch Swift 源文件集成类型检查通过；全量检查包含其他既有文件的废弃接口、重复 switch 值、未使用变量警告，未修改无关代码。
- 最终修改的两个 Watch Swift 文件定向类型检查通过。
- iPhone `WCSessionManager.swift` 定向类型检查通过。
- 修改的 Dart 服务和新增测试静态分析通过，`No issues found!`。
- `flutter test --no-pub test/watch_assistant_service_test.dart` 最终 **3 个测试全部通过**。
- 两端 Info.plist 的 `plutil -lint` 通过。
- 本任务跟踪文件的 `git diff --check` 最终通过。

可复现命令（在工作区执行 Dart/Flutter 命令）：

```sh
xcrun swiftc -typecheck -target arm64-apple-watchos26.0-simulator -sdk "/Applications/Xcode.app/Contents/Developer/Platforms/WatchSimulator.platform/Developer/SDKs/WatchSimulator26.4.sdk" -module-cache-path "/tmp/aboutme-watch-assistant-module-cache" "/Users/Zhuanz/Documents/Aboutme/ios/aboutme Watch App/ChatGPTTestView.swift" "/Users/Zhuanz/Documents/Aboutme/ios/aboutme Watch App/WCSessionManager.swift"

xcrun swiftc -typecheck -target arm64-apple-ios26.4-simulator -sdk "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.4.sdk" -F "/Users/Zhuanz/Documents/Aboutme/build/ios/Debug-iphonesimulator" -module-cache-path "/tmp/aboutme-iphone-assistant-module-cache" "/Users/Zhuanz/Documents/Aboutme/ios/Runner/WCSessionManager.swift"

dart analyze "lib/plugins/personal_assistant/services/watch_assistant_service.dart" "lib/plugins/agent_chat/services/watch_connectivity_service.dart" "test/watch_assistant_service_test.dart"
flutter test --no-pub "test/watch_assistant_service_test.dart"
plutil -lint "ios/Runner/Info.plist" "ios/aboutme Watch App/Info.plist"
```

测试最初遇到共享目录的 `agent_chain_executor.dart` 正在并行修改、返回类型尚未补齐的编译错误。该文件不是本会话修改；随后重新运行同一测试已通过，不能继续把首次失败报告为当前阻塞。

尚未执行 Xcode 完整构建、签名安装、配对真机录音或真实 AI 请求。自动测试仅模拟 MethodChannel，未覆盖真实 ASR、模型请求和工具产生的数据。已向用户明确这些边界，不能把静态检查当作端到端验收。

## 下一会话若收到继续验证的请求

先读取 `docs/WATCH_PERSONAL_ASSISTANT.md`，按其中步骤做配对设备验收，重点包括首次授权、60 秒自动发送、断连重查、系统音频中断，以及实际记录操作是否成功。当前已知产品限制：中文录音、文字回复；iPhone 需在前台开始处理，未实现持续后台执行和语音播报。

没有用户新要求时，不需要主动扩展这些能力，也不要未经要求提交、推送或重启服务。

## 共享工作区注意事项

交接时 `git status` 仍有大量其他会话的未提交改动，包括：导航与插件生命周期、activity、chat、calendar_album、webview、聊天后台执行、前台服务包及相关测试。应重新查看当前状态，并按本文件的明确文件清单定位本任务补丁，不要全量格式化、回滚、暂存或把无关修改一起提交。

特别注意：`chat_controller.dart`、`agent_chain_executor.dart`、`message_service.dart`、`request_service.dart` 等原有依赖在本任务期间由其他会话修改；需要继续开发时应基于磁盘现状阅读，不能将早期读取的签名或行为当成固定事实。

## 工作规范与建议技能（suggested skills）

遵循工作区 `AGENTS.md`：简体中文；开头输出【用户意图】【假设】【验收标准】；最终简要输出【总结】【验收步骤】【后续优化】；优先最小改动，代码探索先 CodeGraph，查不到再 fff/rg；路径加双引号；未要求真实浏览器时不用浏览器；不要为微小改动反复全量构建。

- `handoff`：用户再次要求交接摘要时使用。技能默认建议临时目录，但本次用户明确指定了工作区 `handoff`，以用户指定为准。
- `aboutme-http`：仅在后续需要读取/核验真实 aboutme 插件数据且 MCP 工具不可用时使用；本次没有调用真实数据 HTTP API。路径：`.agents/skills/aboutme-http/SKILL.md`。
- 本任务普通 Swift/Dart 调试不需要额外技能。用户未要求 workflow，本会话没有创建工作流。
