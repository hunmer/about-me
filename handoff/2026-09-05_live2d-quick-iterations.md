# Handoff: Live2D 插件与 Jelly Home 快速迭代

- 日期：2026-09-05
- 仓库：`D:/about-me`
- 目标：让 Live2D 成为可配置插件，并在 Jelly Home 复用 Agent Chat 完整输入链路，通过角色气泡展示 AI 流式回复。
- 当前状态：核心功能已实现；最新气泡布局、桌面滚轮与全局文字速度改动尚未提交。
- 相关过程记录：`task_plan.md`、`findings.md`、`progress.md`。

## 1. 当前功能

### Live2D 插件

- `Live2DPlugin` 继承 `BasePlugin`，已注册到 `lib/core/builtin_plugins.dart`。
- 路由为 `/live2d`，注册于 `lib/screens/routing/routes/plugin_common_routes.dart`，常量在 `lib/screens/route.dart`。
- 存档模型：`lib/plugins/live2d/models/live2d_archive.dart`。
- 存档持久化：插件目录下 `archives.json`，字段包括名称、模型路径、模型文件、绑定 Agent ID 和兼容保留的人格 prompts。
- 会话固定分组：`live2d`。
- 插件设置新增 `typingIntervalMs`，默认 `70ms/字`。

### 设置页

文件：`lib/plugins/live2d/screens/live2d_settings_screen.dart`

- 存档通过横向 `ChoiceChip` 切换，不使用 select；支持新建、删除和保存。
- 本地模型通过列表弹层选择；在线模型复用 `Live2DOnlineModelPage`。
- Agent 选择复用 `AgentListDrawer`，不在设置页内嵌 prompt/conversation 编辑器。
- Live2D 预览默认不加载；通过“显示 Live2D / 卸载 Live2D”按钮控制原生视图生命周期。
- 打开 Agent 抽屉、切换存档或打开模型选择前会主动卸载预览，避免平台视图与导航生命周期冲突导致 `Lost connection to device`。
- 新增全局文字展示速度滑块：`20–200ms/字`，通过插件 settings 持久化。

### AgentListDrawer

文件：`lib/plugins/openai/widgets/agent_list_drawer.dart`

- 顶部有搜索框，按 Agent 名称和描述过滤。
- 右上角始终显示新建 Agent 按钮。
- 每个 Agent 项目右侧有编辑图标，直接打开 `AgentEditScreen`。
- 新建成功后通过创建前后 ID 差集识别新 Agent，自动选择、回填调用方并关闭抽屉。
- Live2D 调用方使用 `SmoothBottomSheet`，在弹层关闭后再更新父页面状态。

### Jelly Home 聊天

文件：`lib/screens/jelly_home/jelly_home_screen.dart`

- Live2D 下方直接挂载 Agent Chat 的完整 `MessageInput`，支持文本、语音、附件、工具模板和取消发送。
- `Live2DChatInput` 为当前存档创建/复用隐藏临时会话：route key 为 `live2d:<archiveId>`。
- 使用 Agent Chat 的 `ChatController`、`MessageService`、`MessageDetailService`、`ToolTemplateService` 和 `ConversationService`。
- 监听当前用户消息之后的 AI 消息：
  - AI 占位内容为空时显示 `...`；
  - 生成中持续推送清理后的流式内容；
  - 完成后触发 Live2D reaction 动作。
- 回复更新不直接在 `MessageService.notifyListeners()` 中调用父组件 `setState`；`_scheduleLive2dReply` 在帧末合并高频更新，避免 `SafeArea` descendant assertion。
- 诊断日志：`[Live2DChat] deferred reply update during <phase>`。

## 2. 气泡实现

主要文件：

- `lib/screens/jelly_home/widgets/jelly_live2d.dart`
- `lib/screens/jelly_home/widgets/jelly_speech_bubble.dart`
- `lib/plugins/live2d/live2d_plugin.dart`

当前行为：

- 宽度为 Live2D 区域的 80%。
- 气泡与尾巴由单个 `CustomPaint` 路径绘制，固定圆角 `18px`。
- 内容高度自适应：最小一行，最大约三行；约束当前为 `minHeight: 24`、`maxHeight: 72`，内部内容保留至少 `44px`。
- 超过三行后使用 `SingleChildScrollView` + 同控制器 `Scrollbar`。
- 桌面滚轮通过 `GestureBinding.instance.pointerSignalResolver` 显式消费 `PointerScrollEvent`，避免外层主页抢滚动。
- 鼠标悬停或手动滚动时暂停自动跟随和气泡隐藏；离开后滚动到底部。
- 流式和最终回复都使用逐字显示；每次文本追加保留 `_shown` 进度，不从头开始。
- 当前可见字符子串用 `MarkdownBody` 渲染，因此 Markdown 随逐字内容增量解析。
- `<think>...</think>` 在气泡边界清理，不修改 Agent Chat 原始消息。
- 非法 UTF-16 surrogate 会替换为 `U+FFFD`，避免 `TextSpan` 绘制异常。
- 短消息最少展示 6 秒；按长度动态延长，最多 30 秒。
- 气泡位于人物视口上方：显示时 `JellyLive2D` 顶部预留 `120px`，人物视口保持原尺寸并固定在底部。这样气泡既不覆盖人物中间，也处于真实 hit-test 区域。

## 3. 关键问题与已采用方案

### `Lost connection to device`

根因表现为 Live2D 原生平台视图在设置页导航/抽屉切换期间仍挂载。设置页不再自动加载预览，并在导航前主动移除 `JellyLive2D`，触发 controller dispose。

### `SafeArea` inherited dependency assertion

Agent Chat 流式消息同步通知时直接重建 `_CottageTabState`，可能与 Flutter 正在更新 inherited dependency 树冲突。现在回复通过帧末 callback 合并后再 setState。

### `string is not well-formed UTF-16`

模型流式文本可能含孤立 surrogate。`Live2DPlugin.cleanReply()` 在气泡渲染前清理 think block 并修复 UTF-16；会话原始内容不变。

### 桌面气泡无法滚动

早期气泡用负向 `FractionalTranslation` 绘制到父节点 hit-test 范围之外。当前通过增加顶部真实布局空间解决，并额外显式处理桌面滚轮信号。

## 4. 当前未提交差异

执行 `git status --short` 时有以下修改：

- `lib/plugins/live2d/live2d_plugin.dart`
- `lib/plugins/live2d/screens/live2d_settings_screen.dart`
- `lib/screens/jelly_home/jelly_home_screen.dart`
- `lib/screens/jelly_home/widgets/jelly_live2d.dart`
- `lib/screens/jelly_home/widgets/jelly_speech_bubble.dart`

最新 diff 主要是：全局文字速度、SafeArea 帧末合并、气泡真实顶部布局、三行自适应高度和桌面滚轮处理。

## 5. 已知风险与下一步

1. 桌面滚轮和“三行高度”只完成静态分析与现有单测，尚未用真实桌面实例做人工视觉验收。
2. `MarkdownBody` 在未闭合 Markdown 流式片段上会不断重新解析；若仍有布局闪烁，可在流式阶段用纯文本逐字显示，完成后再切 Markdown。
3. 顶部渐变遮罩目前始终存在。更合理的行为是仅在 `scrollOffset > 0` 时显示顶部遮罩，避免第一行顶部被淡化。
4. `Live2DChatInput` 的 controller future 只初始化一次。Jelly Home 被 `IndexedStack` 保活时，在设置页更换 Agent/存档后可能不会立即重建，需要按 archive ID 给输入组件加 key 或监听插件配置变化。
5. `Live2DPlugin.sendMessage()` 是早期独立发送链路；Jelly Home 已改用完整 `ChatController + MessageInput`，该方法目前可能无调用，可确认后删除。
6. 在线模型存档目前只保存路径和文件名，重新打开时动作定义为空；若需要在线模型 reaction，应持久化 motions 或重新读取 model JSON。

## 6. 验证记录

最近每轮均运行：

```powershell
dart analyze lib/screens/jelly_home/widgets/jelly_live2d.dart lib/screens/jelly_home/widgets/jelly_speech_bubble.dart lib/screens/jelly_home/jelly_home_screen.dart
flutter test test/jelly_live2d_crop_region_test.dart test/live2d_online_models_test.dart
```

结果：

- 相关 Dart 静态分析：0 issues。
- Live2D/Jelly 测试：6/6 通过。
- 通过 `procm-mcp` 执行项目级 `flutter analyze`：退出码 0。

人工验收建议：

1. 发送单行、三行和超长 Markdown 回复，确认气泡从一行自适应到最多三行。
2. 桌面端将鼠标放在气泡内滚轮滚动，确认外层页面不移动。
3. 流式回复期间切换 Jelly Home 页签，确认无 `SafeArea` assertion。
4. 设置页显示预览后打开 Agent 抽屉，确认预览先卸载且不再断开设备。
5. 调整文字速度后返回 Jelly Home，确认逐字速度生效。

## 7. Suggested Skills

- `diagnose`：继续排查桌面滚轮、平台视图生命周期或 Flutter framework assertion。
- `code-architecture-research`：梳理 Live2D 原生平台视图、Agent Chat 与 Jelly Home 的完整调用链。
- `improve-codebase-architecture`：将 `Live2DChatInput` 从页面文件抽成独立组件，并统一插件状态通知。
- `handoff`：下一轮继续更新本文件。
