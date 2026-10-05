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
| `procm-commands.json` | procm 进程管理命令配置（app：flutter run -d macos；analyze：flutter analyze；server：server-nodejs npm run dev） |
| `handoff/` | Agent 会话交接底稿（5 篇：design-system / live2d / agentlib-store / ai-image / 活人感） |

## lib/（应用代码，1868 个 Dart 文件）

| 目录 | 规模 | 说明 |
|------|------|------|
| `lib/core/` | 147 Dart 文件 | 核心层：插件系统、存储（含 http_storage 后端）、事件、JS Bridge、悬浮球、动作、路由、services/sync 同步器等 |
| `lib/plugins/` | 26 插件 / 1113 文件 | 功能插件（openai 含 aliveness/moments 新子系统）；根级有 `base_plugin.dart`、`plugin_widget.dart` |
| `lib/screens/` | 19 子目录 / 363 文件 | 界面层：jelly_home（默认首页，含 Live2D 渲染核心 jelly_live2d.dart）、home_screen、settings_screen、widgets_gallery、路由注册等 |
| `lib/widgets/` | 18 子目录 / 180 文件 | 通用组件：编辑器、日历、**form_fields 表单字段库（50 文件）**、picker、文件预览等 |
| `lib/services/` `lib/models/` `lib/utils/` `lib/dialogs/` `lib/constants/` | 各 1-9 文件 | 少量顶层服务/模型/工具 |
| `lib/l10n/` | — | 国际化（`unified_translations.dart`） |

## packages/（9 个子包）

| 子包 | 文件数（约） | 类型 |
|------|------|------|
| `server-nodejs/` | 780（含 admin-vue） | Node 同步服务器 |
| `aboutme_widgets/` | 265 | Flutter 原生插件（桌面小组件） |
| `aboutme_intent/` | 121 | Flutter 原生插件（Android Intent） |
| `aboutme_nfc/` | 113 | Flutter 原生插件（NFC） |
| `super_cupertino_navigation_bar/` | 32 | Dart UI 库（iOS 风格导航栏） |
| `aboutme_foreground_service/` | 37 | Flutter 原生插件（前台服务） |
| `aboutme_notifications/` | 34 | Flutter 原生插件（通知） |
| `floating_ball_plugin/` | 33 | Flutter 原生插件（悬浮球） |
| `agentlib/` | 5 Dart 文件 | Dart 包（OpenAI 兼容 HTTP/SSE 传输门面，[文档](../packages/agentlib/CLAUDE.md)） |

> `server-nodejs/src/mcp/`（7 个 TS 文件）为内置 MCP 端点（/mcp，Streamable HTTP，invoker 进程内直调）。已删除：`api_forwarding_server/`、`mcp-aboutme-server/`。

## 其他目录

| 目录 | 说明 |
|------|------|
| `shared_models/` | 共享 Dart 模型包（46 个 Dart 文件：repositories 20 / usecases 20 / sync / auth / utils） |
| `docs/`（67 篇） | 按主题：小组件（WIDGET_*、TODO_QUADRANT_*、CHECKIN_WIDGET_*）、快捷方式（SHORTCUTS_*）、统一计时器（UNIFIED_TIMER_*、README_UNIFIED_TIMER）、Live Activities（live_activities* 5 篇）、原生插件实现（NFC_PLUGIN_*、ABOUTME_INTENT_*、NATIVE_SERVICE_*）、导航（SUPER_CUPERTINO_* 2 篇）、架构（USECASE_MIGRATION_GUIDE、WIDGET_ARCHITECTURE_UNIFIED、bidirectional_sync_implementation、event、http_storage_backend_plan）、AI（AI_PROMPT_GUIDE、PROMPT_*、agent_chat_chain_feature、工具调用结果传递示例）、三方库笔记（openai_dart、fs_shim 等）、`script_examples/` |
| `online/` | `apps/`（4 个小程序 + apps.json）、`scripts/`（在线脚本 + ai_encouragement_bot + ai_image）、`agents.json`；`assets/scripts/` 为 ai_image 内置副本（随 APK 打包，版本升级时覆盖本地） |
| `scripts/` | build.sh、release.sh、build_apk.sh、deploy_to_vercel.sh、fix_ios_build.sh、copy_models.dart 等（有独立 CLAUDE.md） |
| `tool_templates/` | bill / calendar_album / store 三份工具 JSON 模板（随 assets 打包） |
| `android/ ios/ macos/ linux/ windows/ web/ webview/` | 平台宿主工程；`webview/http_server` 为本地 HTTP 服务 |
| `.github/workflows/` | 5 个平台构建工作流 |
| `.claude/` | 仓库级 Claude 配置：hooks（auto-commit.sh）、agents、skills（flutter-layout-fix 等） |
