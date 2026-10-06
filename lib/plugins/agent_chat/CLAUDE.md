# agent_chat AI 对话插件

一对一 AI 对话插件（90 个 Dart 文件，第二大插件）：多会话管理、Agent 绑定（单 Agent / Agent 链）、**标准 function calling 优先**（`dartantic_ai` SDK provider 负责协议与工具循环；DeepSeek 保留 thinking transport 适配；兼容 endpoint 或工具执行前失败时回退旧两阶段 `run_js`）、流式响应（thinking 单独渲染）、语音通话循环（录音→ASR→AI→TTS，含腾讯 ASR 实时 WebSocket）、Android 前台服务、iOS Shortcuts/Watch 同步。直接继承 `PluginBase`，**无 JS API**。

强依赖链：`agent_chat → openai`（AIAgent 模型、RequestService 流式请求、AgentController）+ `tts`（语音通话播报）。工具配置由 `ToolConfigManager` 扫描各插件 JS API 自动生成——插件新增 JS API 后工具面板自动同步。

## 约定的规则

- function calling 可用时以 schema 化标准工具调用为主；Anthropic 官方及兼容 endpoint 均通过本地定制的 `dartantic_ai` provider 接入；兼容回退仍使用 `MarkdownToolCallParser` 解析 `run_js`。工具调用的状态按执行轮次隔离。
- 会话消息每会话单文件，保存走串行链 `_conversationsSaveChain` 防并发写坏。
- 工具配置存 `app_data/agent_chat/tools/<pluginId>.json`（dart:io 直写），改动工具生成逻辑在 `tool_config_manager.dart:84-144`。
- "当前页面问 AI"用临时会话（`getOrCreateTemporaryConversation`），勿复用普通会话。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 三阶段工具调用、7 管理器、语音通话、依赖关系 | 理解插件全貌 |
| [数据模型](claude/data-model.md) | Conversation/ChatMessage/ToolCallStep 等与存储路径 | 改数据结构 |
| [对外接口](claude/public-interfaces.md) | 路由 Agent 配置、临时会话、工具配置生态 | 跨模块对接 |
| [目录速查](claude/file-map.md) | 90 文件的分区导航 | 找代码 |
| [索引变更记录](claude/changelog.md) | 文档更新历史 | 重复运行 /init-project 时 |

## 扫描状态

- 更新时间：2026-09-05（首轮"索引+详情"格式，替换 2025-12-17 旧版单文件文档）
- 已扫描：主类、7 管理器职责、12 模型、服务层清单（16+）、存储路径、openai/tts/core 依赖、语音通话状态机。
- 未深扫：chat_screen 15 个 UI 组件内部、token 计数与建议问题算法细节。
