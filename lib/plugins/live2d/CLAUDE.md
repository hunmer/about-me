# live2d 插件（Live2D 桌宠）

[根目录](../../../CLAUDE.md) > [lib](../../) > [plugins](../) > **live2d**

Live2D 桌宠插件（10 个 Dart 文件）：以"存档"为单位管理 Live2D 伙伴——每个存档绑定一个模型（内置 Mao、在线模型或 zip 压缩包导入，导入记录在本地模型库页管理）与一个 AI Agent，支持全局 TTS 播报与打字速度设置。本插件只提供**数据与设置层**，渲染视图复用 `lib/screens/jelly_home/` 的 `JellyLive2D`，对话走 agent_chat 临时会话。

## 约定的规则

- 存档列表持久化在插件 storage 的 `archives.json`；`Live2DArchive` 只存 agentId，用时取最新 Agent 配置。
- 无 JS API、无 home_widgets；`/live2d` 路由在外部注册且**指向设置页**（plugin_common_routes.dart:84），主列表走 `PluginManager.openPlugin`。
- 改内置模型清单要同步三处：jelly_live2d.dart 硬编码定义、根 pubspec.yaml assets、存档表单的模型选择。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 存档模型、三层模型来源、与 jelly_home 的双向依赖 | 第一次接触本插件 |
| [文件地图](claude/file-map.md) | 9 文件速查 + 相关外部文件（渲染/路由/测试） | 找代码 |
| [索引变更记录](claude/changelog.md) | 本文档更新历史 | 重复运行 /init-project 时 |

## 扫描状态

- 更新时间：2026-10-05（第五轮：首次生成，补第四轮遗留缺口）。
- 已扫描：全部 9 文件职责、主类与注册、路由外部注册点、模型加载链（live2d_flutter path 依赖）、与 jelly_home 协作链、两份相关测试。
- 未深扫：l10n 文案内容。
