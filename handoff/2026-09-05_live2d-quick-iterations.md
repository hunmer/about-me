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
