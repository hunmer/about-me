# openai 插件 · 入口与初始化

> 所属：lib/plugins/openai · [返回索引](../CLAUDE.md)

## 主类

`OpenAIPlugin extends BasePlugin with JSBridgePlugin`（openai_plugin.dart:44），id `'openai'`，单例经 `PluginManager.getPlugin('openai')`。

## initialize() 顺序（openai_plugin.dart:115-136）

1. `initializeDefaultData`：首次写入 agents.json 默认智能体 + prompt_presets.json（:257-288）
2. `ChatEventHandler.initialize()`：监听 chat 插件 @AI 消息
3. `ProactiveService.instance.start()`：活人感主动消息调度器启动
4. `_initializeUseCase`：AgentController/ServiceProviderController/ModelController → ClientOpenAIRepository → OpenAIUseCase（:139-154）
5. 注册数据选择器（openai.agent / openai.prompt）
6. 剪贴板 Agent 导入处理器（`openai_agent_import`，DSDialog 确认后换新 UUID 存盘，:157-254）
7. `registerJSAPI()`

卸载（:330-339）：停 ProactiveService、dispose ChatEventHandler。

## 主视图与后台链路

- 主视图两 Tab：AgentListScreen + PromptPresetScreen，FAB 分别新建 Agent / 预设（:548-566）。
- 后台常驻链路：ProactiveService（每分钟 tick）+ keepalive_service（Android 前台服务 258）。
- @AI 消息入口：chat 插件 → ChatEventHandler（handlers/chat_event_handler.dart:95-107）→ 按该 agent 活人感开关分流：开 → AlivenessOrchestrator.submit()；关 → 原直接生成路径。
- agent_chat 接入点：`lib/plugins/agent_chat/services/aliveness_hook.dart`（ChatController.sendMessage 调用，返回 false 走原路径）。
