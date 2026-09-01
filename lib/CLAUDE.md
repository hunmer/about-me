# lib/ 应用代码层

`lib/` 是 Aboutme Flutter 客户端的全部代码（约 1943 个 Dart 文件），分四层：**core** 核心层（插件系统、存储、事件总线、JS Bridge 等，16 个子系统）、**plugins** 功能插件层（25 个内置插件，1056 个文件）、**screens** 界面层（主页、设置、控制台与路由注册，350 个文件）、**widgets** 通用组件层（编辑器、日历、表单等，180 个文件）。

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
| `core/` | 核心层：插件管理、存储、配置、事件、JS Bridge、悬浮球、动作、小组件同步等 | [core/CLAUDE.md](core/CLAUDE.md)（旧版格式） |
| `plugins/` | 25 个功能插件，目录均含 `*_plugin.dart` 入口 | 24 个旧版 CLAUDE.md + reminder 新版文档，见 [文件地图](claude/file-map.md) |
| `screens/` | 界面层与路由注册 | [screens/CLAUDE.md](screens/CLAUDE.md)（旧版格式） |
| `screens/home_screen/` | 主屏幕：插件卡片布局、小组件 | [home_screen/CLAUDE.md](screens/home_screen/CLAUDE.md)（旧版格式） |
| `screens/settings_screen/` | 设置界面：应用设置、数据管理 | [settings_screen/CLAUDE.md](screens/settings_screen/CLAUDE.md)（旧版格式） |
| `screens/js_console/` | JavaScript 控制台 | [js_console/CLAUDE.md](screens/js_console/CLAUDE.md)（旧版格式） |
| `widgets/` | 通用组件库 | [widgets/CLAUDE.md](widgets/CLAUDE.md)（旧版格式） |
| `l10n/` | 国际化（zh/en/ja，`unified_translations.dart`） | 未扫描 |

## 扫描状态

- 更新时间：2026-09-02（第二轮：补扫 reminder 插件，25 个插件文档齐全）
- 已扫描：目录结构、`main.dart`、`core/app_initializer.dart`、`screens/route.dart`、`core/builtin_plugins.dart`、插件清单、`plugins/reminder` 全部 10 个文件。
- 未深扫：其余 24 个插件内部实现（沿用旧版 CLAUDE.md）、`core/` 各子系统内部。
- 下一步建议：将旧版插件 CLAUDE.md 逐步迁移为"索引 + claude/ 详情"格式。
