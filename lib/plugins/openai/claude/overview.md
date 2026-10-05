# openai 插件 · 架构总览

> 所属：lib/plugins/openai · [返回索引](../CLAUDE.md)

## 定位

openai 插件是 Aboutme 的 **AI 中枢**：管理多服务商（OpenAI/Anthropic/Google/本地模型等 OpenAI 兼容端点）、AI 助手（Agent）、Prompt 预设，并承载两个"AI 伙伴拟人化"子系统：

- **aliveness（活人感，2026-10-04 新增，23 文件）**：让 AI 聊得像真人——延迟回复、分条气泡、记忆、日程、主动消息、语音。
- **moments（朋友圈，2026-10-05 新增，10 文件）**：让 AI 留下生活痕迹——动态流、角色资产图、自主生图发圈。

## 分层

```text
openai_plugin.dart（主类：默认数据 → ChatEventHandler → ProactiveService → UseCase → 选择器 → 剪贴板导入 → JS API）
├── controllers/   GetX 数据控制器（agent/服务商/模型/工具应用/执行历史）
├── repositories/  ClientOpenAIRepository → OpenAIUseCase（Clean Architecture，接口在 shared_models）
├── services/      RequestService（经 agentlib 传输）、市场/资源、soul_forge、prompt 预设
├── models/        AIAgent（含 alivenessConfig）、ServiceProvider、PromptPreset、ToolApp 等
├── handlers/      ChatEventHandler：chat 插件 @AI 消息分流（活人感开关决定走向）
├── aliveness/     活人感子系统（编排器 + services + channels + models + screens）
├── moments/       朋友圈子系统（帖子/资产/生图服务 + UI）
├── screens/       Agent 编辑/列表/市场、服务商与模型、预设、插件设置
├── widgets/       复用 UI（agent 卡片/抽屉/市场组件等）
├── home_widgets/  主屏小组件（图标 + 统计概览）
└── l10n/          中/英/日翻译
```

## 关键设计取舍

- **传输层收敛到 agentlib**：所有 LLM HTTP/SSE 请求经 `packages/agentlib` 的 `AgentLibClient`（RequestService 内组装）；Jev 决策层与生图例外（分别走独立 Dio 与 scripts_center 脚本）。
- **编排核心在 openai，接入薄壳在宿主**：aliveness 的编排器/服务全在本插件；chat 与 agent_chat 只各提供一个 `AlivenessSessionChannel` 适配器（`channels/`），宿主差异（占位消息、消息形态）全部收敛在通道接口后。
- **moments 与 aliveness 无直接依赖**：互补关系——aliveness 管"聊得像"，moments 管"活得可见"；唯一交点是 moments 工具的 agentId 回退链含 `MemoryService.currentAgentId`（aliveness 编排器在 flush 前设置）。
- **决策与生成分离**：Jev（typesafe.ai System One）只决定"是否回/延迟/策略档位/是否语音"，不生成文本；文本仍由 Agent 配置的模型生成，决策失败回退本地保守规则。

## 风险提示

- `aliveness/services/aliveness_store.dart:11-12` 硬编码默认 Jev API Key，`test/aliveness_e2e_test.dart:15-17` 硬编码真实 Jev 与 DeepSeek Key——修改/开源前必须处理。
