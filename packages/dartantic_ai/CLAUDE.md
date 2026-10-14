# dartantic_ai（本地 vendor 版）

上游 [dartantic_ai](https://github.com/csells/dartantic_ai) **3.4.2** 的整包 vendor 镜像（2026-10-06 一次性引入，253 文件），Dart 生态的 LLM Agent 框架：多步工具调用、流式输出、typed output、多模态、embeddings、媒体生成、MCP 客户端。本仓库仅在 3 处做了本地定制（详见 [CUSTOMIZATION.md](CUSTOMIZATION.md)），核心目的：**让 Anthropic 原生格式走自定义/兼容端点（如 bigmodel），让 OpenAI 兼容格式配合 DeepSeek 兼容层**。消费方只有 agent_chat 插件的原生工具调用链路。

## 约定的规则

- 这是 vendor 镜像：**除 CUSTOMIZATION.md 列出的 3 处定制外，不要直接修改**；同步上游按 CUSTOMIZATION.md 的 6 步流程操作（下载 tarball → 比对迁移 → 重放 baseUrl 补丁 → 保留本地测试 → 更新文档 → `dart test` + `flutter analyze`）。
- 消息/结果等抽象类型不在本包，在 pub 依赖 `dartantic_interface`（勿在本包内找 `ChatMessage` 定义）。
- 本包测试自包含（本地假服务器），`dart test` 可离线跑（新增的 `anthropic_custom_base_url_test.dart` 无网络依赖）。
- `example/` 与上游 CHANGELOG 仅供参考，37 个示例可用 `run_all_examples.sh` 批量跑。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 包定位、目录结构、与上游的差异 | 第一次接触本包 |
| [对外接口](claude/public-interfaces.md) | 入口 barrel、Agent/Provider API、消费方用法 | 接入或调试 AI 调用链 |
| [依赖与配置](claude/dependencies-and-config.md) | 依赖构成（interface/各厂商 SDK）、版本 | 升级依赖 |
| [测试与质量](claude/testing-and-quality.md) | 67 个测试的构成与跑法 | 改动后验证 |
| [文件地图](claude/file-map.md) | lib/src 目录速查 | 找文件 |
| [常见问题](claude/faq.md) | baseUrl 定制、DeepSeek 兼容等高频问题 | 排查连通性问题 |
| [索引变更记录](claude/changelog.md) | 本文档集更新历史 | 重复运行 /init-project 时 |

## 扫描状态

- 更新时间：2026-10-14（/init-project 第六轮首次建档）
- 已扫描：pubspec、README/CHANGELOG/CUSTOMIZATION、lib/ 全目录结构、入口 barrel、消费方 grep（全仓库仅 2 处直接引用）、test/ 清单、vendor 提交（11fc480）核实。
- 未深扫：各厂商 ChatModel/Provider 实现细节、example/ 内容、与上游 3.4.2 的逐文件 diff（以 CUSTOMIZATION.md 记录为准）。
