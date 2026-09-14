# 依赖与配置

> 所属：packages/ · [返回索引](../CLAUDE.md)

## path 依赖接线（根 `pubspec.yaml`）

```yaml
agentlib:                  { path: packages/agentlib }
super_cupertino_navigation_bar: { path: packages/super_cupertino_navigation_bar }
floating_ball_plugin:      { path: packages/floating_ball_plugin }
aboutme_widgets:           { path: packages/aboutme_widgets }
aboutme_foreground_service: { path: packages/aboutme_foreground_service }
aboutme_notifications:     { path: packages/aboutme_notifications }
aboutme_intent:            { path: packages/aboutme_intent }
aboutme_nfc:               { path: packages/aboutme_nfc }
```

- 客户端通过 `package:<插件名>/...` 直接 import；改插件公开 API 需全仓检索调用点。
- `floating_ball_plugin`、`aboutme_intent`、`aboutme_nfc`、`aboutme_widgets` 的 SDK 约束为 `^3.10.0`（高于宿主 `^3.7.0` 的语义下限，实际以当前工具链为准）。
- `agentlib` 仅依赖 `http` ^1.3.0（dev: `test`），SDK `^3.7.0`。

## Node 子包清单要点

| 子包 | main / bin | scripts |
|------|-----------|---------|
| server-nodejs | `main: dist/index.js`；`bin: aboutme-server` | build（含 build:admin + tsc + 拷贝）、dev（ts-node-dev）、test（jest --runInBand）、lint（eslint）、inspector（MCP Inspector） |

## 配置

- server-nodejs 环境变量集中在 `src/config/serverConfig.ts`（PORT / DATA_DIR / JWT_SECRET / TOKEN_EXPIRY_DAYS / ADMIN_USERNAME / ADMIN_PASSWORD / ALLOW_REGISTER / ENABLE_CORS / CORS_ORIGINS / MAX_REQUEST_SIZE / ENABLE_LOGGING）。
- MCP 端点随主服务器启动，无独立配置；认证走请求头 `X-API-Key` / `X-Encryption-Key`。
