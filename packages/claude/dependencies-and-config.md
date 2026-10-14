# 依赖与配置

> 所属：packages/ · [返回索引](../CLAUDE.md)

## path 依赖接线（根 `pubspec.yaml`）

```yaml
agentlib:                  { path: packages/agentlib }
dartantic_ai:              { path: packages/dartantic_ai }
super_cupertino_navigation_bar: { path: packages/super_cupertino_navigation_bar }
radial_disc_bottom_bar:    { path: packages/radial_disc_bottom_bar }
material_emoji_picker:     { path: packages/material_emoji_picker }
floating_ball_plugin:      { path: packages/floating_ball_plugin }
aboutme_widgets:           { path: packages/aboutme_widgets }
aboutme_foreground_service: { path: packages/aboutme_foreground_service }
aboutme_notifications:     { path: packages/aboutme_notifications }
aboutme_intent:            { path: packages/aboutme_intent }
aboutme_nfc:               { path: packages/aboutme_nfc }
aboutme_data_sdk:          { path: packages/aboutme_data_sdk }
```

- 客户端通过 `package:<插件名>/...` 直接 import；改插件公开 API 需全仓检索调用点。
- `floating_ball_plugin`、`aboutme_intent`、`aboutme_nfc`、`aboutme_widgets` 的 SDK 约束为 `^3.10.0`，与宿主一致。
- `agentlib` 仅依赖 `http` ^1.3.0（dev: `test`）。
- `dartantic_ai` 为上游 3.4.2 vendor 镜像（要求 Dart `^3.10.0`），由 `packages/dartantic_ai/CUSTOMIZATION.md` 记录 Anthropic `baseUrl` 补丁与同步流程。
- `aboutme_data_sdk` 同时被客户端与 `aboutme_server` 依赖——改它需两侧验证。

## 服务器链路要点

- **aboutme_server（现行，Dart）**：入口 `bin/server.dart`（编译产物 `bin/aboutme-server`），`procm-command start server` 启动，默认端口 8874；管理面板 `admin-vue/` 经 `npm run build` 产出到 `admin/` 由服务器托管于 `/admin`。
- **server-nodejs**：已于 **2026-10-14 彻底删除**（曾为 `main: dist/index.js` + npm scripts：build/dev/test/lint/inspector），仓库中不再存在。

## 配置

- 现行服务器配置集中在 `packages/aboutme_server/lib/src/config.dart`（端口/数据目录等，详见包 README）。
- MCP 端点（/mcp）随 aboutme_server 启动，无独立配置；认证走 API Key（`mk_live_` 前缀）。旧 server-nodejs 的 `src/config/serverConfig.ts` 环境变量（PORT/DATA_DIR/JWT_SECRET/ADMIN_* 等）已随包删除。
