# 依赖与配置

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## SDK 与运行时

- Dart `^3.7.0` / Flutter（`pubspec.yaml`，版本 `2.1.3+160323`）
- Node.js `>= 18`（三个 Node 子包一致要求）

## Flutter 关键依赖（按用途分组）

| 用途 | 依赖 |
|------|------|
| 状态/路由 | `get`（GetX ^4.7.3）、`provider` |
| 存储 | `shared_preferences`、`path_provider`、`fs_shim`、`webdav_client` |
| 网络 | `dio`、`http`、`web_socket_channel` |
| 加密 | `encrypt`（AES-256-GCM 同步）、`crypto` |
| AI | `openai_dart`、`intelligence` |
| JS 引擎 | `flutter_js` |
| 富文本/编辑器 | `flutter_quill`（+ extensions）、`flutter_markdown` |
| 日历 | `syncfusion_flutter_calendar`、`device_calendar`、`timezone` |
| WebView | `flutter_inappwebview` |
| 桌面小组件 | `home_widget`、`live_activities` |
| 消息推送 | `firebase_core`、`firebase_messaging` |
| 多媒体 | `audioplayers`、`record`、`video_player`（+win）、`flutter_tts`、`image`、`flutter_image_compress` |
| UI | Material 3、`adaptive_theme`、`fl_chart`、`lottie`、`smooth_sheets`、`super_cupertino_navigation_bar` 等 |

### 路径依赖（workspace 内子包）

`floating_ball_plugin`、`aboutme_widgets`、`aboutme_foreground_service`、`aboutme_notifications`、`aboutme_intent`、`aboutme_nfc`（均位于 `packages/`）与 `shared_models`。

### dependency_overrides

- `location_web`：git 覆盖（等待上游 issue #1031 修复）
- `timezone` ^0.10.0
- `file_picker`：git master 分支

## Node 子包依赖要点

- **server-nodejs**：`express` + `express-ws`/`ws`（HTTP/WS）、`jsonwebtoken`（JWT）、`firebase-admin`（FCM 推送）、`winston`（日志）、`adm-zip`/`archiver`（ZIP 导出与插件安装）、`chokidar`（文件监听）、`hookable`（插件钩子）、`multer`（上传）；构建期 `typescript ^5.5`、`jest` + `supertest`。管理面板 `admin-vue/`：Vue ^3.5 + `naive-ui` + `pinia` + Vite ^8。
- **mcp-aboutme-server**：`@modelcontextprotocol/sdk` ^1.0、`dotenv`。
- **api_forwarding_server**：`ws`、`uuid`，零其他运行时依赖。

## 配置文件清单

| 文件 | 作用 |
|------|------|
| `pubspec.yaml` | 应用依赖与资源声明（assets 含 `assets/tool_templates/`、`lib/plugins/agent_chat/tools/` 等） |
| `analysis_options.yaml` | flutter_lints ^5 + 多条 error 级规则忽略 |
| `flutter_config.yaml` | `tree-shake-icons: false`（动态图标需要） |
| `firebase.json` | Firebase 项目 `test-3f050`（android/ios/macos/web/windows） |
| `vercel.json` | Web 产物静态部署（`build/web`） |
| `.metadata` / `devtools_options.yaml` | Flutter 工具元数据 |
| `packages/server-nodejs/src/config/serverConfig.ts` | 服务端环境变量集中定义 |
| `scripts/release_config.json` | 构建发布配置（`release_config.example.json` 为模板） |

环境变量说明见 [conventions.md](conventions.md#环境变量)。
