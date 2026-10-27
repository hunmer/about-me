1. 统一生成任务的生命周期和结果
   - 在 `lib/plugins/agent_chat/controllers/managers/agent_chain_executor.dart` 增加结构化的整轮生成结果，区分成功、失败、取消，并返回最终可见 AI 消息的 `messageId`、正文和 token 数。
   - 以整轮链执行结束为成功通知时点，优先选取最终总结消息，其次选取本轮最后一条已完成 AI 消息；不在单个 token 或单个链节点完成时发送通知。
   - 修复执行器当前吞掉错误、取消仍可能等待 `Completer` 的问题，确保所有路径都能落到成功/失败/取消三种终态。
   - 在 `AIRequestHandler.request()` 和工具模板续写路径补齐同样的终态输出，避免模板匹配、工具续写、重新生成与普通链路行为不一致。

2. 接通 Android 前台服务的开始、完成、失败和停止链路
   - 修改 `ChatController` 与 `ChatForegroundServiceManager`，为每次发送生成稳定的整轮任务 ID；开始和结束使用同一个任务 ID，避免当前“开始用合成 ID、完成用真实消息 UUID”导致后台任务无法移除。
   - 将实际生成结果接入 `notifyGenerationComplete` / `notifyGenerationError`，在消息已保存、状态已完成后再发送事件。
   - 在成功、失败、取消和异常路径统一调用 `stopServiceIfIdle`，确保完成后前台服务不会一直显示“生成中”。
   - 检查并透传 `ForegroundTaskManager` 的初始化和 `startService` 返回结果，避免初始化竞态及“启动失败仍打印成功”。
   - 处理前台服务所有权：聊天服务启动时不能把事件发给 `AlivenessKeepAliveHandler`。复用现有活人感服务状态，必要时暂时停止由活人感启动的服务，聊天结束后按原状态恢复；避免两个功能争用同一个 foreground task 实例。
   - 保留前台页面不弹独立通知、应用退后台弹完成通知的行为，但把判断改为明确的应用生命周期状态，避免把任意前台页面误判为聊天页。

3. 提高后台通知在独立 isolate 中的可靠性
   - 在 `AIChatTaskHandler.onStart` 中确保通知插件在该 isolate 完成初始化，复用现有 `NotificationController` 的 channel 配置。
   - 将完成、失败、超时通知改为可等待且带异常日志的调用，检查通知 API 失败情况；通知 ID 使用任务级稳定值或去重策略，避免重复完成事件产生重复通知。
   - 让任务处理器在收到完成/失败后移除正确任务，并通过主 isolate 回传结果刷新消息状态。

4. 增加 iOS 的“尽力运行”能力
   - 在 `packages/aboutme_foreground_service` 增加 iOS 原生 `beginBackgroundTask` / expiration 适配，通过现有插件或 method channel 由聊天生成开始和结束时管理有限后台执行时间。
   - 在 `Info.plist` 补齐现有后台任务实现需要的声明，并核对 AppDelegate 的插件注册与生命周期回调。
   - iOS 不复用 Android 前台服务语义：短请求在系统授予的后台时间内尽量继续；系统挂起后不能保证 SSE 继续，因此保存生成状态和部分结果。
   - 在 `main.dart` 或 agent_chat 生命周期管理处处理 `resumed`：重新加载当前会话，检查是否存在已完成/失败/仍生成的消息；若完成发生在后台但通知未能及时发出，回前台时补发一次本地通知并清理状态。
   - 明确不把 BGAppRefresh 当作连续网络生成机制，避免产生“iOS 长任务必定完成”的错误承诺。

5. 验证与回归
   - 运行 `dart analyze`/相关 Flutter 测试，覆盖结果聚合、取消/错误终态、任务 ID 配对、服务初始化失败和重复完成事件。
   - 在 Android 真机 Release/Profile 下测试：普通切后台、锁屏、慢响应、工具调用、多 Agent、重新生成、取消、活人感保活同时开启、通知权限关闭。
   - 在 iOS 真机 Release/Profile 下测试：首 token 前切后台、生成中切后台、短请求能否完成、超过后台时间后回前台恢复、通知权限关闭和系统低电量模式。
   - 最终文档和日志中明确平台边界：Android 普通切后台尽力持续；iOS 仅有限后台时间，进程被系统终止或长时间挂起时需要回前台恢复，不能在本地客户端保证长 SSE 完成。