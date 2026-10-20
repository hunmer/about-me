# 依赖与配置

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## SDK 与运行时

- Dart `^3.10.0` / Flutter（`pubspec.yaml`，版本 `0.0.1`）
- 同步服务器为 Dart（`packages/aboutme_server`，无 Node 运行时要求）；`server-nodejs` 已于 2026-10-14 彻底删除

## Flutter 关键依赖（按用途分组）

| 用途 | 依赖 |
|------|------|
| 状态/路由 | `get`（GetX ^4.7.3）、`provider`、`flutter_riverpod` ^3.4.3 + `fast_immutable_collections` |
| 存储 | `shared_preferences`、`path_provider`、`fs_shim`、`flutter_secure_storage` |
| 网络 | `dio`、`http`、`web_socket_channel` |
| AI | 本地 `agentlib` transport、本地 `dartantic_ai`（agent_chat 原生工具调用）、`intelligence` |
| JS 引擎 | `flutter_js` |
| 富文本/编辑器 | `flutter_quill`（+ extensions）、`flutter_markdown` |
| 日历 | `syncfusion_flutter_calendar`、`device_calendar`、`timezone` |
| WebView | `flutter_inappwebview` |
| 桌面小组件 | `home_widget`、`live_activities` |
| 消息推送 | `firebase_core`、`firebase_messaging` |
| 多媒体 | `audioplayers`、`record`、`video_player`（+win）、`flutter_tts`、`image`、`image_compress_plus`（flutter_image_compress 社区分支，支持 Windows/Linux） |
| UI/设计系统 | Material 3、`adaptive_theme`、`fl_chart`、`lottie`、`smooth_sheets`、`skribble` + `skribble_icons_material`（手绘纸墨风核心）、`flutter_svg`、`super_cupertino_navigation_bar`、`radial_disc_bottom_bar`、`flutter_map` ^8.2.2（moments NYC demo 地图）、`graphview` ^1.5.1 |
| 国际化 | `intl` ^0.20.2、`flutter_localizations`、`syncfusion_localizations`（GetX `.tr` + unified_translations 聚合，zh/en） |
| 桌面窗口 | `window_manager`、`screen_retriever`（窗口位置/大小记忆） |

> 注：`crypto` 仍在依赖中；`encrypt` 已移除（加密归 aboutme_data_sdk 自身依赖），客户端加密服务已删除（2026-10-12），同步现为明文。

### 路径依赖（workspace 内子包）

`agentlib`、`dartantic_ai`、`super_cupertino_navigation_bar`、`radial_disc_bottom_bar`、`floating_ball_plugin`、`aboutme_widgets`、`aboutme_foreground_service`、`aboutme_notifications`、`aboutme_intent`、`aboutme_nfc`、`aboutme_data_sdk`（均位于 `packages/`）与 `shared_models`；另有仓外 path 依赖 `live2d_flutter`（`../flutter_live2d-main`）。

### dependency_overrides

- `location_web`：git 覆盖（等待上游 issue #1031 修复）
- `timezone` ^0.10.0

## 子包依赖要点

- **aboutme_data_sdk / aboutme_server**（Dart，现行）：数据 SDK 仅依赖 `http`/`crypto` 等纯 Dart 库；服务器依赖 `shelf` 系路由 + `mcp_dart`（MCP 端点）+ firebase-admin 推送（详见各自 pubspec）。
- **dartantic_ai**（vendor）：核心 `dartantic_interface ^4.0.1` + 各厂商 SDK（openai_dart/anthropic_sdk_dart 等）。
- **agentlib**（Dart）：仅依赖 `http` ^1.3.0；dev 依赖 `test`。
- **server-nodejs**（已于 2026-10-14 彻底删除）：曾用 express/ws/jsonwebtoken/firebase-admin/winston 等；管理面板已平移为 `aboutme_server/admin-vue/`。

## 配置文件清单

| 文件 | 作用 |
|------|------|
| `pubspec.yaml` | 应用依赖与资源声明（assets 含 white_noise、脚本、表情包、成就图标、Live2D 背景等） |
| `analysis_options.yaml` | flutter_lints ^5 + 多条 error 级规则忽略 |
| `flutter_config.yaml` | `tree-shake-icons: false`（动态图标需要） |
| `firebase.json` | Firebase 项目 `test-3f050`（android/ios/macos/web/windows） |
| `vercel.json` | Web 产物静态部署（`build/web`） |
| `.metadata` / `devtools_options.yaml` | Flutter 工具元数据 |
| `packages/aboutme_server/lib/src/config.dart` | 现行服务器配置（端口/数据目录等） |
| `scripts/release_config.json` | 构建发布配置（`release_config.example.json` 为模板） |
| `procm-commands.json` | procm-mcp 进程管理命令（start server 等） |

环境变量说明见 [conventions.md](conventions.md#环境变量)。
