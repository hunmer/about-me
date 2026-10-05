# 工具系统迁移 dartantic_ai 原生 function calling

## 结论（探索确认）
- 项目内 `packages/agentlib` 是纯传输门面，无 FC 能力——**保留不动**（非工具请求继续走它）
- `dartantic_ai`：`OpenAIProvider(apiKey, baseUrl, headers)` + `Agent.forProvider` + `Tool(name/description/inputSchema/onCall)`，**工具循环自动**（调用→执行→回传→继续生成，多轮），`sendStream` 流式输出，异常自动回传 LLM
- 296 个工具 JSON 可机械转 `Tool`（type 规范化：String→string 等；22 个 object 参数的嵌套 properties 数据在 JSON 里但模型层未解析，需补）

## 方案：并行路径 + 自动分流（保留旧链路兜底）

**新文件**
1. `lib/plugins/agent_chat/services/native_tool_agent_service.dart` — 核心服务：
   - `runToolLoop({AIAgent, systemPrompt, contextMessages, files, userInput, aiMessageId, onUpdateMessage, onThinking, isCancelling})` → `Future<String>` 最终文本
   - Provider 构造：`OpenAIProvider(apiKey: headers 提取, baseUrl: agent.baseUrl, headers: agent.headers)`（实施时对照 pub cache 源码确认 model 传法）
   - 工具集：ToolConfigManager 启用工具 → `Tool` 列表（name=toolId，description=title+description+returns 摘要，inputSchema=Schema.fromMap）
   - 统一 dispatcher：onCall 收 args → toolId 解析 (pluginId, method)（用 PluginToolSet 索引，不用 split 避开 calendar_album 下划线）→ 生成 JS `const r = await Aboutme.plugins.<p>.<m>(<args>); setResult(r); return r;` → 复用 `ToolService.executeJsCode`（QuickJS 执行层零改动）
   - 每次工具调用构造/更新 `ToolCallStep` 写入 `message.toolCall`（UI/存储/详情对话框零改动）；执行上下文设 `MomentsService.currentAgentId/currentConversationId`（生图工具依赖）
   - `sendStream`：文本 chunk → onUpdateMessage 流式；循环结束取最终 output
2. `lib/plugins/agent_chat/services/tool_schema_builder.dart` — ToolConfig→JSON Schema（type 规范化映射、object 嵌套 properties、required 汇总）
3. `test/native_tool_schema_test.dart` — schema 生成单测（含脏 type 规范化、嵌套 object）

**修改**
4. `pubspec.yaml`：`dartantic_ai`（实施时 `flutter pub add dartantic_ai` 取最新）
5. `tool_config.dart`：`ToolParameter` 补解析 `properties` 嵌套（22 个 object 参数）
6. `agent_chain_executor.dart` `_requestAgentInChain` 开头分流：
   - `apiFormat == 'openai' && enableFunctionCalling && agent.enableFunctionCalling` → 走 `NativeToolAgentService.runToolLoop`，完成后 `completeAIMessage`（复用现有 operationCompleter 语义，活人感零改动）
   - **dartantic 异常自动回退旧两阶段路径**（ToolOrchestrator 保留不删，兼作 anthropic 格式与回退）
7. 图片多模态：contextMessages 里的图片 parts 转 dartantic 的多模态消息（实施时按其 ChatMessage API 处理，DeepSeek vision 场景少，转不了就文本降级）

**保留不动**：ToolOrchestrator（回退+anthropic+模板 rewrite 的 brief/detail prompt）、ToolExecutor（rerun/模板执行）、全部 UI（ToolCallSteps/详情/保存模板）、工具模板第零阶段、js_tool 动态注册（注册进 ToolConfigManager 后自动进入新工具集）、RequestService/agentlib（非工具请求）。

**收益**：工具选择准确率（原生 FC vs prompt 平铺选择题）、参数结构化保证（不再靠模型写 JS）、多轮工具循环（旧架构单轮）、根治 JSON 泄漏类 bug、DeepSeek 无需 json_object 降级 hack。

**代价与控制**：296 工具 schema 全量注入 ≈30k input tokens/次（DeepSeek 约几厘钱，后续可按关键词+pluginAliases 预筛）；新依赖纯 Dart 无 Flutter 冲突。

## 验证
- `flutter analyze` 零新增问题；新单测 + aliveness 逻辑测试全绿
- 用户实测（对话触发工具、生图、发朋友圈）

## 验收步骤（交付后）
1. 重启 app → 对余小满说「你能不能给我看看你的照片」→ 直接生图发聊天（不再出 JSON 占位）
2. 说「查一下我的记忆里有什么」→ search_memory 工具步骤正常显示+总结回复
3. 日志确认走 `[NativeTool]` 路径；断网/接口异常时自动回退旧路径不崩