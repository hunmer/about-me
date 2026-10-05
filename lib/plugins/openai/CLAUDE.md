# openai 插件（AI 中枢）

[根目录](../../../CLAUDE.md) > [lib](../../) > [plugins](../) > **openai**

Aboutme 的 AI 核心（104 个 Dart 文件）：管理多服务商、AI 助手（Agent）、Prompt 预设、工具应用与数据分析，并承载两个拟人化子系统——**aliveness 活人感**（2026-10-04 新增：延迟回复/分条气泡/记忆/日程/主动消息/语音）与 **moments 朋友圈**（2026-10-05 新增：AI 动态流/资产图/自主生图发圈）。LLM 传输统一走 `packages/agentlib`（AgentLibClient），决策层走 Jev（typesafe.ai System One），失败回退本地规则。

## 约定的规则

- @AI 消息统一从 `handlers/chat_event_handler.dart` 分流；agent_chat 侧入口是 `aliveness_hook.dart`，勿在宿主插件内复制编排逻辑。
- 宿主差异只允许写在 `aliveness/channels/` 两个适配器里（AlivenessSessionChannel 接口）。
- LLM 请求一律经 RequestService（agentlib）；Jev 决策与生图是仅有的两个例外。
- ⚠️ `aliveness/services/aliveness_store.dart:11-12` 与 `test/aliveness_e2e_test.dart:15-17` 硬编码真实 API Key，开源/清理前必须移除。
- 新 JS API 需同步 `agent_chat/tools/*.json` 工具描述与 tool_config_manager 的虚拟插件映射。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 分层、aliveness/moments 定位、设计取舍 | 第一次接触本插件 |
| [子系统职责](claude/module-responsibilities.md) | aliveness 编排器/服务/通道、moments、跨插件关系 | 定位功能归属 |
| [入口与初始化](claude/entrypoints.md) | initialize() 七步链、@AI 分流、后台链路 | 排查初始化/消息不回 |
| [对外接口](claude/public-interfaces.md) | 9 个 JS API、LLM 工具面、数据选择器 | 对接或扩展工具 |
| [数据模型](claude/data-model.md) | agents.json、aliveness/moments 存储布局、状态机 | 改数据结构 |
| [文件地图](claude/file-map.md) | 104 文件目录速查 | 找代码 |
| [索引变更记录](claude/changelog.md) | 本文档更新历史 | 重复运行 /init-project 时 |

## 模块索引

| 子系统 | 说明 |
|--------|------|
| `aliveness/`（23 文件） | 活人感：编排器 + 11 服务 + 双宿主通道，详见 [子系统职责](claude/module-responsibilities.md) |
| `moments/`（10 文件） | 朋友圈：帖子/资产/生图，详见 [子系统职责](claude/module-responsibilities.md) |
| 顶层目录 | controllers/handlers/repositories/models/services/screens/widgets/home_widgets，见 [文件地图](claude/file-map.md) |

## 扫描状态

- 更新时间：2026-10-05（第五轮：重写为索引格式，补 aliveness/moments 全量文档）。
- 已扫描：主类初始化链、全部 JS API、aliveness 编排器与服务逐个、moments 全部、与 chat/agent_chat/tts/activity 的依赖方向、agentlib 使用点、两份测试。
- 未深扫：screens/widgets 通用 UI 内部、services/ 市场(soul_forge)细节、controllers 各文件实现。
