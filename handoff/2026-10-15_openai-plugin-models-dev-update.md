# OpenAI 插件模型库 models.dev 定期更新交接

## 当前目标

定期（建议每月或模型大版本发布后）用 [models.dev](https://models.dev/api.json) 的数据刷新 openai 插件中的预定义模型列表和默认服务商配置，保持不过期。

## 本次已完成（2026-10-15）

- 重写 `lib/plugins/openai/models/llm_models.dart` 的 `llmModelGroups`：16 个分组对齐 models.dev 2026-10 数据，删除过期/虚构模型（deepseek-v3 全系、abab 全系、llama-4-405b 等），补充 GPT-6 系列、Claude 5.5、Gemini 4 Argon、GLM-5.3、Kimi K3、Qwen3.8、Grok 4.7、MiniMax-M3 等，并修正错误 ID 格式（如 `claude-4.6-opus` → `claude-opus-4-6`）。
- 更新 `lib/plugins/openai/controllers/provider_controller.dart` 默认服务商 6 处：Azure api-version → `2024-10-21`；Google → `.../v1beta/openai` + Bearer；Cohere → `api.cohere.com/compatibility/v1`；MiniMax → `api.minimax.cn/anthropic/v1`（anthropic 格式）；GLM CodingPlan → `open.bigmodel.cn/api/coding/paas/v4`（openai 格式）；MiniMax CodingPlan → `api.minimax.cn/anthropic/v1`。
- `flutter analyze` 两个文件均通过。具体改动以 git diff 为准，不在本文重复。

## 定期更新操作流程

1. 拉取数据：`curl -s https://models.dev/api.json -o /tmp/models_dev_api.json`（约 5MB，含 230+ 厂商）。
2. 用 Python/jq 按下方映射表提取目标厂商的模型（过滤 `modalities.output` 含 `text` 的，按 `last_updated` 倒序）和 `api` 端点。
3. 更新 `llm_models.dart`：每组挑 5~15 个代表性模型（最新在前），ID 必须用 models.dev 的 Model ID（即真实 API model 名），不要自造格式。
4. 更新 `provider_controller.dart`：核对各厂商 `baseUrl`、`apiFormat`、`defaultModel`。apiFormat 依据 models.dev 的 `npm` 字段：`@ai-sdk/openai-compatible` → `openai`，`@ai-sdk/anthropic` → `anthropic`。
5. 运行 `flutter analyze lib/plugins/openai/models/llm_models.dart lib/plugins/openai/controllers/provider_controller.dart` 验证。

## 关键映射表（项目分组/服务商 → models.dev provider ID）

| 项目侧 | models.dev ID | 备注 |
|---|---|---|
| deepseek | `deepseek` | api 为 `https://api.deepseek.com` |
| qwen / alibaba-qwen | `alibaba-cn` | 开源组取 `open_weights: true` 的 qwen |
| meta | `meta` + `llama` | meta 现为 Muse 系列；Llama 4/3.3 在 `llama`（api.llama.com） |
| openai | `openai` | api=None（原生 SDK），baseUrl 用官方 `api.openai.com/v1` |
| anthropic | `anthropic` | 同上，`api.anthropic.com/v1` |
| google | `google` | OpenAI 兼容端点 `.../v1beta/openai` |
| zhipu | `zhipuai` | **不是** `zhipu` |
| zhipu (CodingPlan) | `zhipuai-coding-plan` | openai 格式 |
| moonshot | `moonshotai-cn`（国内）/ `moonshotai`（国际） | **不是** `moonshot` |
| minimax | `minimax-cn`（国内）/ `minimax`（国际） | 全线 anthropic 格式端点 |
| minimax (CodingPlan) | `minimax-cn-coding-plan` | anthropic 格式 |
| xai / mistral / cohere / perplexity / groq / openrouter | 同名 | api=None 的用官方已知地址 |
| together | `togetherai` | **不是** `together` |
| xfyun（讯飞） | 无 | models.dev 不收录，保持现状不动 |

## 关键文件

- `lib/plugins/openai/models/llm_models.dart` — 预定义模型分组（仅 `llmModelGroups` 需要维护，上面的类定义勿动）
- `lib/plugins/openai/controllers/provider_controller.dart` — 只需维护 `getDefaultProviders()`
- `lib/plugins/openai/services/anthropic_request_service.dart` — anthropic 格式同时支持 `x-api-key` 和 `Authorization: Bearer` 取 key，改格式时无需动它

## 遗留问题 / 下一步建议

1. **老用户不自动生效**：`getProviders()` 的智能合并只按 id 追加新服务商，不会更新已存在 id 的旧 baseUrl/apiFormat。方案：加版本号字段做配置升级迁移，或提示用户手动删 `providers.json` 重新生成。
2. **硬编码可自动化**：可考虑运行时拉取 `api.json` 缓存到本地，替代硬编码列表（需处理离线回退）。
3. 模型列表每组是人工挑选的非全量（openai 全量 53 个只选了 15 个），更新时保持"最新优先、控制数量"原则即可。
4. 新模型可能要求特定 API 版本（如 Azure 新模型需 2025-04+），更新模型时留意 `doc` 字段链接。

## Suggested skills

- `handoff`：下次更新完成后再次生成本文档的新版本（替换本文的"本次已完成"与映射表增量）。
- `diagnose`：仅当更新后某个 provider 调用失败时使用，按"复现 → 最小化 → 定位"排查。
- WebSearch/WebFetch：models.dev 未覆盖的厂商（讯飞）或端点格式存疑时（本次用于确认 Cohere/Google/Azure 端点）联网核实，不要凭记忆猜 URL。

## 注意事项

- 用户可能并行修改同一文件（本次 `provider_controller.dart` 在编辑期间被用户改了 deepseek baseUrl），编辑前若报"File has been modified"需重读并保留用户改动。
- 默认配置中 API key 均为 `YOUR_API_KEY` 占位符；真实密钥只存在于用户本地 `providers.json`，任何情况下不要写入代码或文档。
- 输出使用简体中文；微小数据修改不需要完整 build，`flutter analyze` 定向验证即可。
