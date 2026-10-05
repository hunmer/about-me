# openai 插件 · 数据模型与存储

> 所属：lib/plugins/openai · [返回索引](../CLAUDE.md)

全部为插件 storage 下的 JSON 文件（无数据库）。

## 核心模型

- **AIAgent**（models/ai_agent.dart）：人格/模型/服务商绑定，`:49` 起含 `alivenessConfig` 字段（活人感配置随 agents.json 持久化）。
- **AlivenessConfig**（aliveness/models/aliveness_config.dart）：总开关、缓冲窗口、maxBubbles、分条延迟、惰性、遗忘半衰期、主动消息组（开关/冷却/日限/免打扰）、语音开关与 ttsServiceId（哨兵 copyBy 支持显式清 null）。
- **AgentState**（aliveness/models/agent_state.dart）：五维 energy/mood/arousal/intimacy/trust + 惰性演化/互动演化/describe()。
- **MemoryFragment / OpenLoop**（aliveness/models/memory_fragment.dart）：记忆碎片（content/tags/isSelf/importance/userMarked/archived + 遗忘权重）；开环事件（followUpBy 到期触发主动跟进，7 天过期）。
- **MomentPost / AgentAsset**（moments/）：帖子（id/agentId/text/images/source: agent|manual）与资产图（name/prompt 占位模板/path 可空=未生成）。
- 其余：ServiceProvider、LLMModels、PromptPreset、ToolApp、ApiFormat、ExecutionHistory（models/）。

## 存储布局

```text
openai/
├── agents.json、prompt_presets.json 等          # 控制器持久化
├── aliveness/
│   ├── settings.json                            # Jev 决策层全局配置（含硬编码默认 Key，注意）
│   └── <agentId>/
│       ├── state.json / stats.json              # 五维状态与统计
│       ├── decisions.log                        # 决策日志（滚动 200 条）
│       ├── schedule.json                        # AI 日程（按天失效）
│       └── memory/fragments.json、open_loops.json
└── moments/
    ├── posts.json                               # 帖子（新帖插头，上限 500）
    ├── <agentId>/assets.json                    # 资产图清单
    ├── assets/<agentId>/                        # 资产图文件
    └── images/                                  # 生成图归档
```

## 状态机要点

状态读取时惰性演化（能量每天 +0.3 线性恢复、亲密度半衰期指数衰减），互动后落盘，内存缓存（state_service）。记忆遗忘：权重 < 0.05 归档（memory_service）。
