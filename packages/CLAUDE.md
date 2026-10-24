# packages/ 子包集合

`packages/` 汇集 Aboutme 的 12 个子包，分四类：**同步服务器链路**（`aboutme_data_sdk` 纯数据 SDK + `aboutme_server` Dart 薄壳服务器，含 `admin-vue` 管理前端源码；旧 Node 服务器 `server-nodejs` 已于 2026-10-14 彻底删除）、**4 个本地 Dart 库**（agentlib AI 传输门面、dartantic_ai vendor 镜像、super_cupertino_navigation_bar 导航 UI、radial_disc_bottom_bar 弧形底部导航）与 **6 个 Flutter 原生插件**（悬浮球、前台服务、通知、Intent、NFC、桌面小组件）。Dart 子包经根 `pubspec.yaml` 的 path 依赖被客户端直接引用。

## 约定的规则

- 修改 Dart 子包公开 API 后需在客户端同步更新调用处（path 依赖，无版本缓冲）。
- **同步服务器用 `aboutme_server`（Dart，默认端口 8874）**：改 `aboutme_data_sdk` 后需重 build 并在 aboutme_server 下重新 install；数据业务逻辑在 aboutme_data_sdk，服务器只做路由/认证/广播/托管（薄壳）。
- `dartantic_ai` 是上游 3.4.2 vendor 镜像，只允许 [CUSTOMIZATION.md](dartantic_ai/CUSTOMIZATION.md) 列出的 3 处定制。
- 管理前端源码在 `aboutme_server/admin-vue`（Vue 3 + Vite），`npm run build` 产物输出到 `aboutme_server/admin/` 由服务器托管于 `/admin/`。
- 原生插件的平台代码（android/ ios/）改动需同时在客户端宿主工程验证。
- 历史包 api_forwarding_server（8654）/ mcp-aboutme-server 已删除，勿再引用。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [子包总览](claude/overview.md) | 13 个子包的定位与关系 | 了解 packages 全貌 |
| [模块职责](claude/module-responsibilities.md) | 各子包职责明细（含 6 个原生插件） | 选择要改的子包 |
| [依赖与配置](claude/dependencies-and-config.md) | path 依赖接线、各包清单要点 | 动依赖 / 加新包 |

## 模块索引

| 模块 | 类型 | 职责摘要 | 文档 |
|------|------|----------|------|
| `aboutme_data_sdk/` | Dart 库（数据核心） | 纯数据 SDK：存储接口/HTTP 远端存储/认证（JWT+PBKDF2）/33 个域 handler（28 域写封闭 426 + system/assets）/AboutmeData 本地-远程路由；客户端与服务器共用 | [aboutme_data_sdk/CLAUDE.md](aboutme_data_sdk/CLAUDE.md) |
| `aboutme_server/` | Dart 服务 | 同步服务器（薄壳）：REST 各域业务 API、文件存储 ETag 条件写、WS file_updated 广播、FCM、MCP /mcp、管理界面托管（admin-vue 源码在本包）+ Docker 部署；默认端口 8874 | [aboutme_server/CLAUDE.md](aboutme_server/CLAUDE.md) |
| `agentlib/` | Dart 库 | OpenAI 兼容 HTTP/SSE 传输门面（AgentLibClient，openai 与 agent_chat 消费） | [agentlib/CLAUDE.md](agentlib/CLAUDE.md) |
| `dartantic_ai/` | Dart 库（vendor 镜像） | 上游 dartantic_ai 3.4.2 整包 vendor；仅 3 处本地定制（Anthropic baseUrl 等），agent_chat 原生工具调用消费 | [dartantic_ai/CLAUDE.md](dartantic_ai/CLAUDE.md) |
| `super_cupertino_navigation_bar/` | Dart 库 | iOS 风格大标题导航栏 UI 库（vendor @2.1.2 + 搜索框定制 + sketchFont） | 无独立文档（`docs/SUPER_CUPERTINO_*`） |
| `radial_disc_bottom_bar/` | Dart 库 | 弧形圆盘浮动底部导航栏（双层同心圆弧 + 滑动药丸，含 golden 测试） | 无独立文档 |
| `floating_ball_plugin/` | 原生插件 | 系统级悬浮球 | 无独立文档（见 [模块职责](claude/module-responsibilities.md)） |
| `aboutme_foreground_service/` | 原生插件 | 前台服务（封装 flutter_foreground_task） | 无独立文档 |
| `aboutme_notifications/` | 原生插件 | 通知管理（封装 awesome_notifications） | 无独立文档 |
| `aboutme_intent/` | 原生插件 | Android Intent / 桌面快捷方式 | 无独立文档（`docs/ABOUTME_INTENT_IMPLEMENTATION.md`） |
| `aboutme_nfc/` | 原生插件 | NFC 读写 | 无独立文档（`docs/NFC_PLUGIN_IMPLEMENTATION.md`） |
| `aboutme_widgets/` | 原生插件 | Android/iOS 桌面小组件（40+ Provider，双尺寸） | [aboutme_widgets/CLAUDE.md](aboutme_widgets/CLAUDE.md) |

## 扫描状态

- 更新时间：2026-10-25（后续优化轮：**aboutme_data_sdk 与 aboutme_server 首次独立建档**——各 CLAUDE.md 索引 + claude/ 10 详情，模块索引链接从 README 改指各自 CLAUDE.md，修正过时数字"12 处理器/19 插件 API/68 工具"。此前 2026-10-14 第六轮：补入两包条目；server-nodejs 删除；material_emoji_picker 迁入 lib/widgets 后删包，子包数 12）
- 已扫描：12 个子包清单与接线；**aboutme_data_sdk（69 lib 文件）与 aboutme_server（15 lib 文件）源码级建档（2026-10-25）**；dartantic_ai 全量（见其 claude/）；agentlib、aboutme_widgets 前几轮已建档。
- 未深扫：radial_disc_bottom_bar 源码；5 个原生插件的 android/ios 平台代码；admin-vue 前端组件细节。
- 注意：`radial_disc_bottom_bar/build/` 编译产物被误提交进 git；`skills/moe-ui-skill` 是无 .gitmodules 的 gitlink（根目录层面）。
