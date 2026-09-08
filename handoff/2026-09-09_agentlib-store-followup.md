# AgentLib Skills/MCP 商店工作交接

## 当前目标

继续维护 Aboutme 项目中的 AgentLib Skills/MCP 资源管理、默认商店推荐和安装流程；本轮重点关注 Skill 下载 403 的线上验证。

## 当前状态

- 已移除根项目对 `openai_dart` 的依赖，改用本地 `packages/agentlib` 动态 HTTP 实现。
- 已完成全局 Skills/MCP 列表、启用状态过滤、Skills Tags 过滤、Agent 编辑页 selector、资源编辑以及本地/URL Skill 导入。
- 已接入与 agent_spaces Web 相同的默认商店源：
  `https://gh-proxy.org/https://github.com/hunmer/agent-spaces/raw/refs/heads/main/packages/templates/`
- Skills 使用 `skills/index.json` 和 `{path}/SKILL.md`；MCP 使用 `mcps/index.json` 和 `mcps/{filename}`。
- 商店支持搜索、Skills 标签过滤、索引缓存、手动刷新、安装中防重复点击、详情弹窗和 MCP 环境变量提示。
- 最近修复下载 403：请求增加 `User-Agent`/`Accept`；当 `gh-proxy.org` 返回 403 时，自动回退到对应的 `raw.githubusercontent.com` 文件地址。

## 关键文件

- `lib/plugins/openai/screens/agent_resource_list_screen.dart`
- `lib/plugins/openai/screens/agent_resource_store_screen.dart`
- `lib/plugins/openai/services/agent_resource_store_service.dart`
- `lib/plugins/openai/widgets/agent_resource_selector.dart`
- `packages/agentlib/lib/agent_slots.dart`
- `task_plan.md`
- `findings.md`
- `progress.md`

## 最近验证

- Flutter 定向 `analyze` 通过。
- `packages/agentlib` 的 Dart 测试通过，4/4。
- `git diff --check` 通过。
- 尚未执行完整 Flutter build，也尚未在真实 Flutter 运行环境中复现/确认 403 修复。

## 下一步建议

1. 在实际应用中打开 Skills 商店，安装一个推荐 Skill，确认代理 403 时 raw GitHub 回退能成功完成下载。
2. 若仍失败，记录实际响应状态、最终请求 URL 和响应体摘要，重点检查网络环境是否阻断 `raw.githubusercontent.com`。
3. 视需要增加可配置备用镜像、重试策略和本地持久化索引缓存。
4. 若要支持 MCP 环境变量实际配置，需要扩展 `AgentResourceItem` 持久化字段并增加配置界面，当前只做了提示展示。

## Suggested skills

- `planning-with-files`：继续多阶段修改时，维护 `task_plan.md`、`findings.md` 和 `progress.md`。
- `openai-docs`：仅在继续处理 OpenAI/AgentLib API 或 SDK 行为时使用。
- `skill-creator`：仅在需要把资源管理能力抽成新的 Codex skill 时使用。

## 注意事项

- 保留用户已有的 Live2D 等无关改动，不执行破坏性 git 回滚。
- 修改文件使用 `apply_patch`，最终输出使用简体中文。
- 当前工作树包含未提交修改，详情以 `git status` 和上述规划文件为准。
