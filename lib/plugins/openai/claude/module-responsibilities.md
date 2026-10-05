# openai 插件 · 子系统职责

> 所属：lib/plugins/openai · [返回索引](../CLAUDE.md)

## aliveness 活人感子系统（aliveness/，23 文件）

### 编排器（aliveness_orchestrator.dart）

- 唯一入口 `submit()`：agent 开启 alivenessConfig 才接管，否则返回 false 走宿主原路径。
- 每条用户消息按 `agentId_targetId` 归入会话缓冲，来消息即重置计时器（"看完再回"）。
- 缓冲时长 = 亲密度×0.6 + 惰性×0.4 插值 + 15% 抖动：不熟回得快，熟且懒可拖延。
- 计时结束 `_flush()` 固定 8 步：设上下文 → 四类记忆注入 → Jev/规则决策 → 已读不回判定（决策说不回且亲密度>0.4 才允许）→ 决策延迟（0~300s）→ 注入 systemSuffix 调宿主 `generate()` → 发布（语音或分条气泡）→ 后台三件套（状态演化/记忆提取/遗忘整理）。

### services/（11 文件）

| 服务 | 职责 |
|------|------|
| aliveness_store | 每 agent 数据落盘：`openai/aliveness/<agentId>/` 下 state/stats/decisions.log/memory/schedule + 全局 settings.json |
| memory_service | 类神经元记忆：LLM 提取碎片、激活扩散检索（一级 tag + 二级联想×0.5）、遗忘归档（权重<0.05）、`searchForTool` 供 LLM 工具 |
| decision_service | Jev 决策（七问并行：是否回/延迟/策略四档/语音/转话题/情绪/探索问题），失败或低置信回退本地规则 |
| behavior_executor | 纯函数拆条：按换行分气泡、清 markdown、合并单字语气碎片、超 maxBubbles 合并尾部 |
| proactive_service | 主动消息：每分钟 tick，三重硬限制（免打扰[支持跨午夜]/日限/冷却）；开环事件到期跟进 + 闲置思念（>4h 未互动+亲密度>0.5+5% 概率） |
| voice_service | TTS 合成临时文件 → chat 音频消息 / agent_chat 音频附件 |
| schedule_service | AI 日程表：今日首次互动按人设生成 24h 安排（8~14 条，按天失效），`buildScheduleContext` 注入"正在做"防编造；UI 复用 activity 时间线 |
| state_service | 五维状态惰性演化：能量线性恢复、亲密度半衰期衰减——"关掉对话角色仍在生活" |
| keepalive_service | Android 前台保活（serviceId 258，与 agent_chat 的 257 互斥），支撑 ProactiveService 后台运行 |
| chat_import_service | 聊天记录导入：txt/md/zip（微信导出识别）→ 6000 字符分块 → 并发 3 路 LLM 双提取 → 补记忆或克隆出新 agent |

### channels/（宿主适配器，生命周期=一次缓冲）

- `chat_aliveness_channel`：AI 回复收敛到根消息 AiThread；"正在想…"占位流式更新；分条=首条落定+后续延迟 append；含已读标记与追问入口。
- `agent_chat_aliveness_channel`：无占位（宿主 ChatController 驱动"正在输入中"）；完成后删隐藏窗口整条 AI 消息、一次性重写最终形态。

### 其他

- `models/`：AgentState（五维）、AlivenessConfig（挂 AIAgent 持久化）、MemoryFragment + OpenLoop（开环事件，followUpBy 到期触发主动跟进，7 天过期）。
- `data/question_pool.dart`：亲密度分层探索问题池（低/中/高三档解锁）。
- `screens/`：记忆管理页、决策日志页（"为什么这样回"）、AI 日程时间线、聊天记录导入页。
- `widgets/`：agent 编辑页"活人感增强"配置分组、Jev 设置对话框。

## moments 朋友圈子系统（moments/，10 文件）

- 数据：MomentPost（text/images/source: agent|manual）+ AgentAsset（资产图，name/prompt/path）。
- 存储：帖子 `openai/moments/posts.json`（新帖插头、上限 500）；资产 `openai/moments/<agentId>/assets.json`，图片归档 `openai/moments/`。
- 服务：moments_service（帖子 CRUD + 把生成图发回 agent_chat 会话）、agent_assets_service（资产 CRUD，预置"三视图/房间照片"占位）、image_gen_service（封装 scripts_center 的 ai_image 内置脚本生图，结果拷贝归档避免互扰）。
- UI 入口：agent_chat 聊天页"朋友圈"按钮 → 动态流；资产图管理从 agent 编辑页活人感分组进入。
- agent 自主发圈链路：LLM 工具 `post_moment`（可带 imagePrompt → `generate_image` 用资产图作参考保持形象一致）。主动消息不会自动发圈。

## 与其他插件关系

- **chat（双向）**：chat 的 @AI 消息由本插件 ChatEventHandler 处理并按活人感开关分流；反向经 PluginManager 拿 ChatPlugin 写频道消息/读历史/存音频。
- **agent_chat（host-shell 模式）**：接入薄壳在 `agent_chat/services/aliveness_hook.dart`（接管判断+已读标记）；本插件反向写 Conversation/ChatMessage；agent_chat 的 tool_config_manager 把 'memory'/'moments' 虚拟插件 id 映射到本插件 JS API 工具。
- **tts/activity/notifications/foreground_service**：语音合成、日程时间线 UI、系统通知、前台保活。
