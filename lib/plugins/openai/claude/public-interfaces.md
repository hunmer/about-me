# openai 插件 · 对外接口

> 所属：lib/plugins/openai · [返回索引](../CLAUDE.md)

## JS API（defineJSAPI，openai_plugin.dart:87-106）

| API | 实现 | 功能 |
|-----|------|------|
| `getAgents` | openai_js_api.dart:23 | 分页获取全部 AI 助手 |
| `getAgent` | openai_js_api.dart:43 | 按 agentId 取助手详情 |
| `sendMessage` | openai_js_api.dart:69 | 流式向指定 agent 发消息并收集完整回复（10 次重试） |
| `search_memory` | openai_js_api.dart:7 | 活人感记忆查询（LLM 工具）：关键词激活检索，无命中回退核心记忆 |
| `generate_image` | moments_js_api.dart:15 | 文生图/图生图（可引用资产图保持形象一致），可选发回聊天 |
| `post_moment` | moments_js_api.dart:88 | 发朋友圈，可选 imagePrompt 自动配图 |
| `list_agent_assets` | moments_js_api.dart:150 | 查询当前 agent 资产图列表 |
| `getProviders` | openai_js_api.dart:143 | 分页获取服务商列表 |
| `testProvider` | openai_js_api.dart:163 | 用该服务商下 agent 发测试消息验证连通性 |

moments 工具 agentId 解析优先级：显式参数 > `MomentsService.currentAgentId`（agent_chat 会话维护）> `MemoryService.currentAgentId`（活人感编排器维护）（moments_js_api.dart:6-10）。

## LLM 工具面（描述给模型的虚拟插件）

agent_chat 的 tool_config_manager（tool_config_manager.dart:47、:77）把 `'memory'` / `'moments'` 两个虚拟插件 id 映射到上表 JS API 工具，工具描述文件在 `lib/plugins/agent_chat/tools/memory.json` 与 `tools/moments.json`。

## 数据选择器（openai_data_selectors.dart）

- `openai.agent`（:9-60）：网格选择 AI 助手（头像/描述/模型，带搜索）。
- `openai.prompt`（:63-112）：列表选择 Prompt 预设（含分类与摘要，带搜索）。

## 剪贴板导入

`openai_agent_import` 处理器：剪贴板粘入 Agent JSON → DSDialog 确认 → 换新 UUID 存盘。

## 对外行为输出

chat 频道消息（AiThread 分条/语音）、agent_chat 会话消息、系统通知（主动消息）、TTS 语音、Android 前台常驻通知（保活）。
