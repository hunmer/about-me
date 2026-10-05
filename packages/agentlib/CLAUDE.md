# agentlib（AI 传输门面包）

[根目录](../../CLAUDE.md) > [packages](../) > **agentlib**

纯 Dart 本地包（4 个 lib 文件 + 1 测试，v1.1.0）：OpenAI 兼容传输的薄门面——`AgentLibClient` 提供一次性补全与 SSE 流式（`stream()`），`chat_models.dart` 定义四角色多模态消息模型，`agent_slots.dart` 提供 agent 市场/资源商店的 skills/MCP 槽位模型。Agent 编排逻辑不在此包。

## 约定的规则

- path 依赖无版本缓冲：改公开 API 需同步修复 openai 与 agent_chat 两处消费方（共 20 个导入点）。
- 保持零 Flutter 依赖、仅依赖 http；不要在此包引入 UI 或存储。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构与 API 面](claude/overview.md) | 传输协议、公开 API 清单、消费方分布 | 扩展传输能力 / 升级 |
| [索引变更记录](claude/changelog.md) | 本文档更新历史 | 重复运行 /init-project 时 |

## 扫描状态

- 更新时间：2026-10-05（第五轮：首次生成）。
- 已扫描：全部源码（agentlib/chat_models/agent_slots/openai_compat）、全部使用点。
- 未深扫：无（包体 374 行已全读）。
