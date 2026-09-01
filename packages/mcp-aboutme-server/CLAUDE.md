# mcp-memento-server MCP 服务器

`@hunmer/mcp-memento-server` v1.0.0 —— 基于 `@modelcontextprotocol/sdk` 的 MCP（Model Context Protocol）服务器，通过 **stdio** 与 AI 客户端（Claude Desktop 等 MCP Host）通信，把 Memento 的个人数据能力暴露为 AI 可调用的工具：覆盖 chat、notes、activity、goods、bill、todo、diary、checkin、calendar、contact、tracker、day 共 **12 个插件域、60+ 工具**（命名 `memento_{plugin}_{action}`）。工具经内建的 `MementoClient` 调用 server-nodejs 的 REST API（API Key + 加密），本体不存数据。

源码极小（src 下 6 个 TS 文件），ESM（`"type": "module"`），Node ≥ 18。

## 约定的规则

- 构建 `npm run build`（tsc）→ 运行 `npm start`；开发 `npm run dev`（tsx）；调试用 `npm run inspector`（MCP Inspector）。
- 配置三个环境变量（`.env`）：`MEMENTO_SERVER_URL`（指向 server-nodejs）、`MEMENTO_API_KEY`（管理面板生成，`mk_live_` 前缀）、`MEMENTO_ENCRYPTION_KEY`。
- 新增工具：在 `src/tools/index.ts` 按命名规范添加定义，客户端能力放 `src/client/memento-client.ts`。
- 仓库内已有 `.env` 文件（含真实配置），注意不要泄露或提交密钥变更。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 分层、工具域清单、运行形态 | 第一次接触本包 |
| [入口与启动](claude/entrypoints.md) | 启动链路与 MCP Host 接入方式 | 部署 / 接入 AI 客户端 |
| [对外接口](claude/public-interfaces.md) | 工具清单（按插件域分组） | 查工具名 / 加工具 |
| [依赖与配置](claude/dependencies-and-config.md) | 依赖与 .env 说明 | 配置环境 |

## 模块索引

| 模块 | 说明 |
|------|------|
| `src/index.ts` | 服务器启动（stdio transport） |
| `src/config.ts` | 环境变量加载与校验 |
| `src/tools/index.ts` | 全部 MCP 工具定义 |
| `src/client/memento-client.ts` | 调用 server-nodejs REST 的客户端 |
| `src/types/index.ts` | 类型定义 |
| `scripts/start-inspector.js` | MCP Inspector 启动器 |

## 扫描状态

- 更新时间：2026-09-01 23:48 (+0800)
- 已扫描：package.json、README、src 结构、工具定义清单（工具名抽取）。
- 未深扫：各工具完整 JSON Schema 参数（可在 `src/tools/index.ts` 现查）。
