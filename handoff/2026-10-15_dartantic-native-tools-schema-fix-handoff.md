# dartantic_ai 原生 Tools 迁移与 Schema 崩溃修复交接

## 目标

完成 agent chat 对 `dartantic_ai` 原生 tools 的迁移，移除旧的手工工具提示词、JSON 解析和 `run_js` 两阶段编排；并修复构造原生 `Tool` 时遇到的 Map 类型崩溃。

## 当前故障

运行时日志显示：

```text
type '_Map<dynamic, dynamic>' is not a subtype of type 'Map<String, Object?>?'
Tool._hasParameters (package:dartantic_interface/src/tool.dart:84:45)
NativeToolAgentService._buildTools (.../native_tool_agent_service.dart:370:9)
```

已确认原因是空参数时 schema 中的 `properties: {}` 被推断成 `Map<dynamic, dynamic>`。`dartantic_interface` 的 `Tool._hasParameters` 将 schema properties 转成 `Map<String, Object?>`，因此构造 `Tool` 时抛错。

## 已有改动

- `lib/plugins/agent_chat/services/tool_schema_builder.dart`：schema 外层、properties 及属性定义改用 `Map<String, Object?>`；空 properties 显式声明类型；required 使用 `List<String>`。
- `test/native_tool_schema_test.dart`：新增回归用例，验证空参数 schema 可以构造原生 `Tool`。
- 实际实现以当前 `git diff` 为准；不要覆盖或回退用户并行修改。

## 尚未完成 / 下一步

1. 运行 `flutter test test/native_tool_schema_test.dart`，确认新增回归测试和同文件其他测试通过。
2. 若测试仍被 `lib/screens/widgets_gallery/common_widgets/widgets/stacked_accordion_card.dart` 的 Flutter rendering 类型编译错误阻塞，先检查该文件当前内容和错误。它是工作区已有的用户修改，不要重置；判断是否能以最小导入修正解决，避免将无关修改混入本任务。
3. 完成定向 `flutter analyze`。之前摘要记录 `tool_schema_builder.dart` 与 `native_tool_agent_service.dart` 定向分析已通过，但应结合当前代码状态复核。
4. 核验 `dartantic_ai` 迁移是否仍完整：查阅 `tool_orchestrator.dart`、`ai_request_handler.dart`、`agent_chain_executor.dart`、`native_tool_agent_service.dart`。目标是通过 `Agent(..., tools: [...])` 提供工具定义，由 Agent 自主完成多轮工具调用；QuickJS 可以继续作为工具执行后端。模型侧不应回退到 `tool_brief` 工具列表提示词、要求模型返回 JSON 或旧的 `run_js` 编排。

## 工作区注意事项

已观察到以下未提交文件。除 schema builder 与回归测试外，其余改动是用户已有内容，需保留：

- `lib/core/app_initializer.dart`
- `lib/plugins/bill/screens/account_list_screen.dart`
- `lib/screens/widgets_gallery/common_widgets/widgets/stacked_accordion_card.dart`

当前迁移相关服务文件没有出现在已检查的 diff 中；续接时应通过代码和日志确认迁移状态，不能只依赖早前摘要。

## 验收标准

- 空参数工具能够成功构造 `dartantic_ai` 的 `Tool`，不再触发 `_Map<dynamic, dynamic>` 类型转换异常。
- 对话将 tools 注入 Agent，由 Agent 负责工具调用与多轮迭代，不再进入旧的提示词列工具、解析 JSON、再运行 JS 的回退路径。
- 定向测试通过；若因独立的用户工作区编译错误无法运行，记录具体文件和错误，不绕过或删除测试。

## Suggested skills

- `handoff`：若续接工作仍需交接，更新或新增交接文档。
- `procm-http`：仅当本地持久进程管理工具不可用且确实需要操作进程时，按技能流程使用 HTTP fallback。

