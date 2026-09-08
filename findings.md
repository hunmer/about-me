# 发现

- AgentLib 资源当前由 `AgentResourceSlots` 保存 skills 和 mcpServers 字符串列表。
- 全局入口在 `lib/plugins/openai/screens/plugin_settings_screen.dart`，目前是文本输入。
- 单 Agent 入口在 `lib/plugins/openai/screens/agent_edit_screen.dart`，目前是文本字段。
- `SuperCupertinoNavigationWrapper` 可直接承载 `MultiFilterBar`、搜索栏和 actions。
- 资源条目已升级为 `AgentResourceItem`，兼容旧的字符串数组格式，并支持 `enabled`、`tags`。
- 本地/URL Skill 导入内容保存在 `AgentResourceItem.content`，资源列表通过插件设置持久化。
- 默认商店源为 `https://gh-proxy.org/https://github.com/hunmer/agent-spaces/raw/refs/heads/main/packages/templates/`，Skills 使用 `skills/index.json` 与 `{path}/SKILL.md`，MCP 使用 `mcps/index.json` 与 `mcps/{filename}`。
- 商店缓存仅保留在当前进程内，手动刷新会绕过缓存重新请求远程索引，不增加持久化依赖。
- gh-proxy 命令行可正常返回资源，但部分 Dart 请求会收到 403；下载层现统一携带 `Aboutme-AgentStore/1.0` 请求头，并只在 gh-proxy 返回 403 时回退 raw GitHub 地址。
