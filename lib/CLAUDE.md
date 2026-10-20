# lib/ 应用代码层

`lib/` 是 Aboutme Flutter 客户端的全部代码（1981 个 Dart 文件，2026-10-20 统计），分五层：**core** 核心层（插件系统、存储、数据服务入口、事件总线、JS Bridge、l10n 等，154 文件）、**plugins** 功能插件层（29 个内置插件，约 1166 个文件）、**screens** 界面层（默认主页 jelly_home、onboarding/startup 启动闸门、设置、控制台与路由注册，397 文件）、**widgets** 通用组件层（编辑器、日历、表单字段库、moments 地图 demo 等，191 文件）、**design_system** 设计系统（手绘纸墨风 skribble 主题与组件，51 文件）。另有小型顶层目录：**l10n**（国际化聚合 `unified_translations.dart`，4 文件）、utils（12）、services/models/dialogs/constants（各 1）。

插件通过 `BasePlugin` + `JSBridgePlugin` 接入核心层，经 `builtin_plugins.dart` 静态注册；路由统一汇总于 `screens/route.dart`。启动链与分层规范见下方详情文件。

## 约定的规则

- 新插件：`lib/plugins/<name>/` + 在 `lib/core/builtin_plugins.dart` 注册 + 在 `lib/screens/routing/routes/` 注册路由。
- 插件优先用 UseCase 分层，Repository/UseCase 接口放 `shared_models/`（迁移指南 `docs/USECASE_MIGRATION_GUIDE.md`）。
- 通用 UI 组件放 `lib/widgets/`，插件私有 UI 留在插件目录内。
- 单文件 ≤1000 行，超限用 `part`/`part of` 拆分；中文文档注释。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [分层总览](claude/overview.md) | 四层职责划分与依赖方向 | 理解整体结构 |
| [入口与启动](claude/entrypoints.md) | main.dart 启动链、初始化顺序、路由挂载 | 排查启动/初始化问题 |
| [开发约定](claude/conventions.md) | 插件开发模式、JS API 命名、i18n、主题 | 写新插件之前 |
| [文件地图](claude/file-map.md) | 各层目录与插件入口速查 | 找代码 |

## 模块索引

| 模块 | 说明 | 文档 |
|------|------|------|
| `core/` | 核心层：插件管理、存储（含 http_storage 远程后端与 services/sync 同步器）、配置、事件、JS Bridge、悬浮球、动作、小组件同步、l10n 等 | [core/CLAUDE.md](core/CLAUDE.md)（旧版格式） |
| `plugins/` | 29 个功能插件，目录均含 `*_plugin.dart` 入口 | **[plugins/CLAUDE.md](plugins/CLAUDE.md)**（插件体系架构 + 职责速查 + 路由全景）；chat / agent_chat / openai / live2d / media_log / achievement / moments 有独立文档集 |
| `screens/` | 界面层与路由注册（**默认主页为 jelly_home 果冻小屋**，首启经 onboarding → startup 闸门） | [screens/CLAUDE.md](screens/CLAUDE.md)（旧版格式） |
| `screens/home_screen/` | 主屏幕：插件卡片布局、小组件 | [home_screen/CLAUDE.md](screens/home_screen/CLAUDE.md)（旧版格式） |
| `screens/jelly_home/` | 果冻小屋主页（四页签 + Live2D 渲染 + 状态面板） | [jelly_home/CLAUDE.md](screens/jelly_home/CLAUDE.md) |
| `screens/settings_screen/` | 设置界面：应用设置、数据管理 | [settings_screen/CLAUDE.md](screens/settings_screen/CLAUDE.md)（旧版格式） |
| `widgets/` | 通用组件库（含 form_fields 表单字段库，已手绘化） | [widgets/CLAUDE.md](widgets/CLAUDE.md)（旧版格式） |
| `design_system/` | 设计系统：手绘纸墨风（skribble 引擎、色板×墨线主题预设、TegakiZatsu 字体） | 无独立文档（建议下轮建档） |
| `l10n/` | 国际化聚合层：`unified_translations.dart` 汇入应用层 + core + 全部 29 个插件的 zh/en 翻译（GetX `.tr`），含 arb 文件（app_en/app_zh） | 未深扫 |

## 扫描状态

- 更新时间：2026-10-20（第七轮增量：29 插件、1981 文件、moments 建档、l10n 聚合体系确认——全部插件 + core + 应用层均有 zh/en 翻译）。
- 已扫描：目录结构与各层文件数（2026-10-20 统计）、`main.dart`（skribble 图标注册、窗口几何、App 使用统计）、`core/app_initializer.dart` 重写、`screens/route.dart`（onboarding → startup 闸门 → jelly_home）、`core/builtin_plugins.dart`（29 插件注册）、29 个插件主类核对、media_log 与 achievement 与 moments 全量、chat/agent_chat/openai/live2d 深扫（第五轮）+ 后续 diff 复核、`l10n/unified_translations.dart` 聚合结构。
- 未深扫：openai 之外其余插件的 screens/widgets 内部（职责与结构见 [plugins/CLAUDE.md](plugins/CLAUDE.md)）、`core/` 各子系统内部细节、`design_system/` 内部（无独立文档）、l10n key 全量清单与 arb 生成链路。
- 下一步建议：为 `design_system/`（51 文件）建档；逐步迁移其余旧版插件 CLAUDE.md。
