# 文件地图

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## 根目录

| 路径 | 说明 |
|------|------|
| `pubspec.yaml` / `pubspec.lock` | Flutter 应用清单与锁文件 |
| `lib/main.dart` | 应用入口（唯一顶层入口文件 + `firebase_options.dart`） |
| `CLAUDE.md` + `claude/` | 本文档体系（根索引 + 详情） |
| `README.md` | 项目介绍（注意：其中 `cd server` 指令已过时） |
| `analysis_options.yaml` / `flutter_config.yaml` | 分析器与构建配置 |
| `firebase.json` / `vercel.json` | Firebase / Vercel 部署配置 |
| `procm-commands.json` | procm 进程管理命令配置（app/analyze/server 等） |
| `design.md` | 标准页面结构规范（页面 = 导航栏 Wrapper + body） |
| `handoff/` | Agent 会话交接底稿（6 篇：design-system / live2d / agentlib-store / ai-image / 活人感 / data-sdk-server-unification） |
| `plan/` | 产品规划（活人感增强系统 PRD 与执行方案） |
| `outputs/` | 界面截图产物（todo-app 演示图） |
| `tools/` | 切图脚本资产（agent_covers 封面切分） |
| `skills/` | 嵌套仓库 moe-ui-skill（gitlink，内容不在本仓追踪） |

## lib/（应用代码，1881 个 Dart 文件）

| 目录 | 规模 | 说明 |
|------|------|------|
| `lib/core/` | 151 Dart 文件 | 核心层：插件系统、存储（含 http_storage 后端）、数据服务入口（`data/aboutme_data_service.dart`）、事件、JS Bridge、悬浮球、动作、路由、services（含旧 sync 同步器、app_usage、window_geometry）等 |
| `lib/plugins/` | 28 插件 / 1140 文件 | 功能插件（openai 含 aliveness/moments；media_log、achievement 为 2026-10 新增）；根级有 `base_plugin.dart`、`plugin_widget.dart` |
| `lib/screens/` | 345 文件 | 界面层：jelly_home（默认主页，含 Live2D 渲染 jelly_live2d_* 12 文件与状态面板）、onboarding、startup 闸门、home_screen、settings_screen、widgets_gallery、路由注册等 |
| `lib/widgets/` | 179 文件 | 通用组件：编辑器、日历、**form_fields 表单字段库（手绘化外壳）**、picker、gallery_viewer、arc_context_menu、emoji_picker 表情选择器（手绘风，原 material_emoji_picker 包迁入）等 |
| `lib/design_system/` | 49 文件 | 设计系统：手绘纸墨风（skribble 引擎、色板/主题预设、light_header/list_item_card/scribble_marks 等组件） |
| `lib/services/` `lib/models/` `lib/utils/` `lib/dialogs/` `lib/constants/` | 各 1-9 文件 | 少量顶层服务/模型/工具 |
| `lib/l10n/` | — | 国际化（`unified_translations.dart`，中/英） |

## packages/（13 个子包）

| 子包 | 文件数（约） | 类型 |
|------|------|------|
| `aboutme_server/` | 23 源文件 | **Dart 同步服务器（现行）**：REST/WS/MCP/FCM/管理托管（含 admin-vue 前端源码） |
| `aboutme_data_sdk/` | 45 源文件 | **纯数据 SDK（现行数据核心）**：存储/认证/12 插件处理器 |
| `dartantic_ai/` | 128 Dart | dartantic_ai 3.4.2 vendor 镜像（[文档](../packages/dartantic_ai/CLAUDE.md)） |
| `aboutme_widgets/` | 265 | Flutter 原生插件（桌面小组件） |
| `aboutme_intent/` | 121 | Flutter 原生插件（Android Intent） |
| `aboutme_nfc/` | 113 | Flutter 原生插件（NFC） |
| `super_cupertino_navigation_bar/` | 32 | Dart UI 库（iOS 风格导航栏 + sketchFont） |
| `radial_disc_bottom_bar/` | 23 | Dart UI 库（弧形圆盘底部导航） |
| `aboutme_foreground_service/` | 37 | Flutter 原生插件（前台服务） |
| `aboutme_notifications/` | 34 | Flutter 原生插件（通知） |
| `floating_ball_plugin/` | 33 | Flutter 原生插件（悬浮球） |
| `agentlib/` | 5 Dart 文件 | Dart 包（OpenAI 兼容 HTTP/SSE 传输门面，[文档](../packages/agentlib/CLAUDE.md)） |

> MCP 端点内置于 aboutme_server（`lib/src/mcp/`，68 工具，与 REST 共用 data_sdk 处理器）。已删除：`api_forwarding_server/`、`mcp-aboutme-server/`、`server-nodejs/`（2026-10-14）。

## 其他目录

| 目录 | 说明 |
|------|------|
| `shared_models/` | 共享 Dart 模型包（46 个 Dart 文件：repositories 20 / usecases 20 / sync / auth / utils） |
| `docs/`（70 篇） | 按主题：小组件（WIDGET_*、TODO_QUADRANT_*、CHECKIN_WIDGET_*）、快捷方式（SHORTCUTS_*）、统一计时器（UNIFIED_TIMER_*、README_UNIFIED_TIMER）、Live Activities（live_activities* 5 篇）、原生插件实现（NFC_PLUGIN_*、ABOUTME_INTENT_*、NATIVE_SERVICE_*）、导航（SUPER_CUPERTINO_* 2 篇）、成就系统（ACHIEVEMENT_ICONS/ACHIEVEMENT_SYSTEM_PLAN）、架构（USECASE_MIGRATION_GUIDE、WIDGET_ARCHITECTURE_UNIFIED、bidirectional_sync_implementation、event、http_storage_backend_plan、floating_window）、AI（AI_PROMPT_GUIDE、PROMPT_*、agent_chat_chain_feature）、三方库笔记（openai_dart、fs_shim 等）、`script_examples/`、切图资产（emoji_sheet/、jelly_icons/、achievement_icons/） |
| `online/` | `apps/`（4 个小程序 + apps.json）、`scripts/`（在线脚本 + ai_encouragement_bot + ai_image）、`agents.json`；`assets/scripts/` 为 ai_image 内置副本（随 APK 打包，版本升级时覆盖本地） |
| `scripts/` | build.sh、release.sh、build_apk.sh、deploy_to_vercel.sh、fix_ios_build.sh、copy_models.dart 等（有独立 CLAUDE.md） |
| `tool_templates/` | bill / calendar_album / store 三份工具 JSON 模板（随 assets 打包） |
| `android/ ios/ macos/ linux/ windows/ web/ webview/` | 平台宿主工程；`webview/http_server` 为本地 HTTP 服务 |
| `.github/workflows/` | 5 个平台构建工作流 |
| `.claude/` | 仓库级 Claude 配置：hooks（auto-commit.sh）、agents、skills（flutter-layout-fix 等） |
