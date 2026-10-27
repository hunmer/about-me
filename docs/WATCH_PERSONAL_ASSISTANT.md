# Apple Watch 个人助手语音请求

手表入口：`ios/aboutme Watch App/ChatGPTTestView.swift`。

## 使用

1. 在配对 iPhone 打开 aboutme，先确认「个人助手」能正常请求 AI。
2. 在手表个人助手点击「说说你想做什么」，允许麦克风权限。
3. 说一句中文，例如「明天下午三点提醒我买牛奶」，点击「结束并发送」。录音最长 60 秒，到时自动发送。
4. 首次请求时，在 iPhone 允许 aboutme 使用语音识别；等待手表显示识别文字和助手回复。涉及记录操作时，在对应插件确认数据。
5. 等待中可以返回首页查看进度；查询超时后点击「重新查询结果」，不会重新提交 AI 操作。

录音进入后台或被系统音频中断时会取消并提示重录。iPhone 强制退出或处理进程中断后，未完成请求会返回明确失败；若请求含记录操作，先检查是否已完成再重录。

## 链路

- Watch 使用 AVAudioRecorder 生成单声道 16 kHz AAC/m4a，32 kbps，最长 60 秒。
- WatchConnectivity `transferFile` 发送录音，元数据包含 `request=sendAssistantAudio`、`requestId`、`sessionId`、`duration`、`createdAt`。
- iPhone 在接收回调返回前复制文件，等待 Flutter 就绪和 App 前台，再以 Speech framework 的 `zh-CN` 识别语音。识别超时 45 秒。
- 原生通过 `github.hunmer.aboutme/watch_connectivity` 调用 Dart `onAssistantAudio`。Dart 立即返回 `{accepted:true}`，异步串行处理请求。
- Dart 复用个人助手 `ChatAssistantService.builtinAgentId` 和 `ChatController`，按手表 `sessionId` 使用独立临时会话，同一会话保留上下文。等待完整工具循环完成后，通过 `updateAssistantResponse` 写入原生结果缓存。
- Watch 每 2 秒发送 `getAssistantResponse` 查询，单次查询超时 10 秒，总等待 180 秒；重试只查询同一 `requestId`。
- iPhone 按请求编号去重，持久保留最近 30 条状态；长回复限制为 12000 字符或 48 KiB。录音识别后清理。本版返回文字，不包含语音播报。

## 验证边界

已做两端 Swift 类型检查、Dart 静态分析，以及输入校验、去重、失败后继续处理的自动测试。自动测试使用模拟 MethodChannel，不访问真实 AI 或设备。

真机仍需检查：麦克风/语音识别授权、60 秒自动发送、断连后查询、工具调用产生的实际记录，以及系统音频中断提示。Swift 类型检查不替代 Xcode 完整构建和配对设备联调。
