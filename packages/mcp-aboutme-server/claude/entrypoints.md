# 入口与启动

> 所属：packages/mcp-memento-server · [返回索引](../CLAUDE.md)

## 启动链路

- `src/index.ts`：加载 `config.ts`（dotenv）→ 用 `@modelcontextprotocol/sdk` 创建 server（stdio transport）→ 注册 `src/tools/index.ts` 的工具 → 监听 JSON-RPC 消息。
- `npm start` = `node dist/index.js`；`npm run dev` = `tsx src/index.ts`；构建 `npm run build`（tsc → `dist/`）。

## MCP Host 接入

- 全局安装：`npm i -g @hunmer/mcp-memento-server` → `memento-server` 命令，或 `npx @hunmer/mcp-memento-server`。
- 在 MCP Host（如 Claude Desktop）配置中把本命令注册为 stdio 服务器，并通过环境变量注入三要素：`MEMENTO_SERVER_URL` / `MEMENTO_API_KEY` / `MEMENTO_ENCRYPTION_KEY`。

## 调试

- `npm run inspector`（`scripts/start-inspector.js`）启动 MCP Inspector，可视化验证工具调用。
