# 开发约定

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## 常用命令

```bash
# Flutter 客户端
flutter pub get          # 安装依赖（含 packages/* 与 shared_models 路径依赖）
flutter run              # 运行
flutter analyze          # 静态检查（无独立 lint 命令）
flutter build apk --release / flutter build ios --release

# 同步服务器（packages/aboutme_server，Dart）
# 数据核心在 packages/aboutme_data_sdk：改动 SDK 后需重新构建并在 aboutme_server 侧更新依赖
procm-command start server   # 启动/重启服务器（命令定义见 procm-commands.json，默认端口 8874）
dart test                    # aboutme_server / aboutme_data_sdk 各自包内跑测试
# server-nodejs 已于 2026-10-14 彻底删除（目录不存在），其 npm 命令不再可用

# 构建发布（多平台打包 + GitHub Release）
./scripts/build.sh       # 配置见 scripts/release_config.json
```

## 代码风格（Dart）

- 单文件不超过 1000 行；超限按功能拆分，可用 `part` / `part of` 管理私有类。
- 文件名 `snake_case.dart`，类名 `PascalCase`，变量/方法 `camelCase`，常量 `UPPER_SNAKE_CASE`。
- 注释使用中文；公共 API 必须有文档注释。
- lint 基于 `flutter_lints ^5`，但 `analysis_options.yaml` 忽略了 `use_build_context_synchronously`、`avoid_print` 等多条规则——改动相关代码时需自行注意这些隐患。

## 插件开发约定

- 新插件放 `lib/plugins/<name>/`，入口 `*_plugin.dart` 继承 `BasePlugin`（可 mixin `JSBridgePlugin`），并**必须**在 `lib/core/builtin_plugins.dart` 注册 Builder。
- JS API 命名：`get{Entity}s`（分页列表）/ `get{Entity}ById` / `find{Entity}By{Field}` / `create{Entity}` / `update{Entity}` / `delete{Entity}`。
- 推荐分层：`Plugin（JS API 适配）→ UseCase（业务）→ ClientXxxRepository（数据访问）→ Service + Controller`；接口与 UseCase 定义在 `shared_models/`。
- 路由：在 `lib/screens/routing/routes/<plugin>_routes.dart` 注册，由 `lib/screens/route.dart` 汇总。

## 重要兼容性提醒

- **现行同步服务器是 `packages/aboutme_server`（Dart，默认端口 **8874**）**：数据核心在 `packages/aboutme_data_sdk`。旧文档中的 `server/` 目录、`cd server && dart run bin/server.dart`、`packages/server-nodejs`（2026-10-14 已彻底删除）的 npm 指令一律视为过时。
- **同步为明文**：端到端加密（AES-256-GCM / X-Encryption-Key）已随数据 SDK 化移除（2026-10-12 删除 encryption_service）。
- `flutter_config.yaml` 设置 `tree-shake-icons: false`，因为项目使用动态 `IconData`；不要在构建中开启图标树摇。
- Web 平台差异：`StyledToast` 等库用条件导入（`if (dart.library.io)`）提供存根实现，改动平台相关代码时注意。
- `build/`、`dist/`、`.dart_tool/`、各平台构建产物均为生成物，不要手工编辑或提交。
- `.claude/hooks/` 下存在 auto-commit 等钩子脚本；Agent 不应主动执行 git 提交、分支、reset 等操作。

## 环境变量

- 现行服务器配置集中在 `packages/aboutme_server/lib/src/config.dart`（端口 8874 等，详见该文件与包 README）。
- 旧 server-nodejs 的 `PORT` / `DATA_DIR` / `JWT_SECRET` / `ADMIN_USERNAME` 等环境变量已随包删除。
