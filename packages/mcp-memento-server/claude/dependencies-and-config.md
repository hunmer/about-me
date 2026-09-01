# 依赖与配置

> 所属：packages/mcp-memento-server · [返回索引](../CLAUDE.md)

## 依赖

| 依赖 | 用途 |
|------|------|
| `@modelcontextprotocol/sdk` ^1.0 | MCP 协议实现（stdio transport、工具注册） |
| `dotenv` ^17 | `.env` 加载 |
| dev：`tsx` ^4.7、`typescript` ^5、`@types/node` ^20 | 开发与构建 |

零其他运行时依赖——HTTP 请求等由 SDK/Node 内建承担（详见 `src/client/memento-client.ts`）。

## 配置（`.env`，仓库内已有一份）

| 变量 | 说明 |
|------|------|
| `MEMENTO_SERVER_URL` | server-nodejs 地址（如 `http://localhost:8874`） |
| `MEMENTO_API_KEY` | 管理面板生成的 API Key（`mk_live_` 前缀） |
| `MEMENTO_ENCRYPTION_KEY` | Base64 加密密钥，须与客户端/服务器约定一致 |

- `.env.example` 模板见 README；`src/config.ts` 为加载逻辑。
- 注意：仓库中的 `.env` 含真实配置，勿将其提交到公开场所。
