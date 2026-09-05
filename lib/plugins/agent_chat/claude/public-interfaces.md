# agent_chat 对外接口

> 所属：`lib/plugins/agent_chat/` · [返回索引](../CLAUDE.md)

## 路由与入口

- 主页经 `/plugin/agent_chat` 打开 `AgentChatMainView({conversationId?})` → `ConversationListScreen`（带初始化等待，最多 5 秒轮询）。
- **无声明式路由、无 JS API**（未 mixin JSBridgePlugin）。

## 数据选择器

- `agent_chat.conversation` — 会话单选（注册到 PluginDataSelectorService）。

## 路由级 Agent 配置（供其他模块调用）

`saveRouteAgentConfig` / `getRouteAgentConfig` + `getOrCreateTemporaryConversation(routeName)`：为任意页面绑定"问 AI"会话。消费方：core 悬浮球动作 `core/action/built_in/ask_context_action/widgets/context_query_drawer.dart`（当前页面问 AI 的上下文查询）。临时会话带过期清理。

## 可被调用的能力（Dart 层）

- `AgentChatPlugin.instance` 单例（PluginManager.getPlugin）。
- 工具执行环境：`ToolExecutor` 经 `JSBridgeManager.initToolCallContext / setCurrentExecution` 执行 `run_js`——脚本/工具统一走 JSBridgeManager。
- Watch：`services/watch_connectivity_service.dart`（Apple Watch）。
- iOS Shortcuts：`shortcuts_handler_service.dart` + `conversation_sync_service.dart`。

## 工具配置生态

`ToolConfigManager` 扫描各插件 `*_js_api.dart` 注册的 API，自动生成 `agent_chat/tools/<pluginId>.json` 工具描述（含参数/返回值定义），供 AI 在工具调用时感知可用能力——**给插件加 JS API 后工具面板自动同步，无需手工登记**。
