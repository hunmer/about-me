# Aboutme

Aboutme 是一个基于 Flutter 的**跨平台个人助手应用**（Android / iOS / Web / Windows / macOS / Linux），采用插件化架构内置 25 个功能插件（聊天、日记、账单、习惯、AI 对话等），数据本地优先存储，支持 WebDAV 与自建服务器的端到端加密同步。

本仓库是 monorepo：除 Flutter 客户端（`lib/`）外，还包含 6 个原生能力子包、3 个 Node.js/TypeScript 服务（同步服务器、MCP 服务器、API 转发服务器）、共享模型包（`shared_models/`）与 71 篇专题文档（`docs/`）。技术栈：Flutter/Dart ^3.7 + GetX + flutter_js，Node ≥ 18（Express、MCP SDK）。

## 约定的规则

- 同步服务器在 `packages/server-nodejs`（默认端口 **8874**）；旧文档中 `cd server && dart run ...` 已失效，勿再引用。
- 新插件必须注册到 `lib/core/builtin_plugins.dart`；JS API 命名 `get{Entity}s` / `create{Entity}` / `update{Entity}` / `delete{Entity}`；推荐 UseCase 分层（接口放 `shared_models/`）。
- Dart 风格：单文件 ≤1000 行、snake_case 文件名、中文注释；`flutter analyze` 为质量门槛（无测试目录）。
- `tree-shake-icons: false` 是硬性要求（动态 IconData）；Web 平台部分库走条件导入存根。
- `build/`、`dist/`、`.dart_tool/`、`Aboutme.ipa` 为生成物，不要编辑；Agent 不主动执行 git 操作。
- 完整命令（构建/测试/发布）与环境变量说明见 [开发约定](claude/conventions.md)。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 仓库形态、运行时拓扑、设计取舍 | 第一次接手项目 |
| [开发约定](claude/conventions.md) | 命令、代码风格、插件规范、环境变量 | 写代码之前 |
| [模块职责](claude/module-responsibilities.md) | 全部模块/插件的职责速查 | 定位功能归属 |
| [入口与启动](claude/entrypoints.md) | main.dart 启动链、各服务入口、CI | 排查启动问题、加初始化逻辑 |
| [对外接口](claude/public-interfaces.md) | 路由、JS Bridge、REST/WS、MCP 工具、转发协议 | 对接或扩展接口 |
| [依赖与配置](claude/dependencies-and-config.md) | 依赖分组、路径依赖、配置文件清单 | 升级依赖、改配置 |
| [数据模型](claude/data-model.md) | 本地存储、shared_models、同步协议、服务端存储 | 改数据结构、做同步 |
| [测试与质量](claude/testing-and-quality.md) | 测试现状、质量工具与风险 | 提测、补测试 |
| [文件地图](claude/file-map.md) | 目录速查表（含 docs/ 主题分类） | 找文件 |
| [常见问题](claude/faq.md) | 高频问题与定位路径 | 遇到问题先查这里 |
| [索引变更记录](claude/changelog.md) | 本文档体系的更新历史 | 重复运行 /init-project 时 |

## 模块索引

| 模块 | 职责摘要 | 文档 |
|------|----------|------|
| `lib/` | Flutter 应用代码（core / plugins×25 / screens / widgets，1823 个 Dart 文件） | [lib/CLAUDE.md](lib/CLAUDE.md) |
| `lib/plugins/` | 插件层聚合索引：插件体系架构 + 25 插件职责/路由/约定 | [lib/plugins/CLAUDE.md](lib/plugins/CLAUDE.md) |
| `lib/plugins/chat` | 频道式聊天/消息记录（109 文件，含 @AI 事件桥） | [lib/plugins/chat/CLAUDE.md](lib/plugins/chat/CLAUDE.md) |
| `lib/plugins/agent_chat` | 一对一 AI 对话：三阶段工具调用/Agent 链/语音通话 | [lib/plugins/agent_chat/CLAUDE.md](lib/plugins/agent_chat/CLAUDE.md) |
| `packages/` | 9 个子包聚合索引（3 个 Node 服务 + 6 个原生插件） | [packages/CLAUDE.md](packages/CLAUDE.md) |
| `packages/server-nodejs` | 同步服务器（REST + WS + 管理面板 + 服务端插件系统） | [packages/server-nodejs/CLAUDE.md](packages/server-nodejs/CLAUDE.md) |
| `packages/mcp-aboutme-server` | MCP 服务器（AI 工具接口，60+ 工具） | [packages/mcp-aboutme-server/CLAUDE.md](packages/mcp-aboutme-server/CLAUDE.md) |
| `packages/api_forwarding_server` | WebSocket 配对转发服务器（端口 8654） | [packages/api_forwarding_server/CLAUDE.md](packages/api_forwarding_server/CLAUDE.md) |
| `shared_models/` | 客户端/服务端共享模型（Repository / UseCase / 同步协议） | [shared_models/CLAUDE.md](shared_models/CLAUDE.md) |
| `scripts/` | 多平台构建与发布脚本 | [scripts/CLAUDE.md](scripts/CLAUDE.md) |
| `online/` | WebView 小程序仓库（4 应用）、在线脚本与 Agent 配置 | [online/CLAUDE.md](online/CLAUDE.md) |
| `docs/` | 71 篇专题文档（小组件/快捷方式/计时器/原生插件实现等） | 未扫描（主题分类见 [文件地图](claude/file-map.md)） |

```mermaid
graph TD
    Root["Aboutme 仓库"] --> Lib["lib/ 客户端"]
    Root --> Pkg["packages/"]
    Root --> Shared["shared_models/"]
    Root --> Docs["docs/ · online/ · scripts/"]
    Pkg --> Srv["server-nodejs 同步服务器"]
    Pkg --> MCP["mcp-aboutme-server"]
    Pkg --> FWD["api_forwarding_server"]
    Pkg --> Native["6 个原生插件"]
    Lib --> Core["core 核心层"]
    Lib --> Plugins["plugins ×25"]
    Lib --> UI["screens · widgets"]
```

## 扫描状态

- 更新时间：2026-09-05（第三轮：新建 lib/plugins 聚合文档 + chat/agent_chat 独立文档集，全量核实 25 插件）
- 已扫描：前两轮全部范围（根配置、lib 启动链、3 个 Node 子包、shared_models、admin-vue、online、reminder）+ 本轮：25 个插件主类逐个验证（继承/mixin/路由/分层）、路由全集、home_widgets 覆盖、chat 与 agent_chat 内部实现、openai 结构、跨插件依赖网；test/ 出现 3 个冒烟测试（design_system/jelly/live2d），已更新测试章节。
- 跳过：`build/`、`dist/`、`node_modules/`、`.git/`、平台宿主工程内部（android/ios/macos/linux/windows/web）、assets 二进制。
- 未深扫（下次增量优先）：openai 与其余 22 个插件的 screens/widgets 内部（已有职责表）、5 个原生插件的 android/ios 平台代码、`docs/` 正文、server-nodejs handler 实现细节。
- 详细覆盖度量与续跑建议见 [索引变更记录](claude/changelog.md)。
