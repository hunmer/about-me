# 开发约定

> 所属：仓库根目录 · [返回索引](../CLAUDE.md)

## 常用命令

```bash
# Flutter 客户端
flutter pub get          # 安装依赖（含 packages/* 与 shared_models 路径依赖）
flutter run              # 运行
flutter analyze          # 静态检查（无独立 lint 命令）
flutter build apk --release / flutter build ios --release

# 同步服务器（packages/server-nodejs）
npm install
npm run dev              # ts-node-dev 热重载
npm run build            # 含 admin-vue 构建 + tsc + 拷贝 plugins/admin
npm test                 # jest --runInBand
npm run lint             # eslint src/**/*.ts

# MCP 端点（packages/server-nodejs/src/mcp/，挂载于主服务器 /mcp，Streamable HTTP）
npm run build && npm start
npm run inspector        # MCP Inspector 调试

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

- **旧文档中的 `server/` 目录已不存在**：Dart 版同步服务器已移除，现行服务器是 `packages/server-nodejs`（默认端口 **8874**，不是旧文档写的 8080）。遇到 `cd server && dart run bin/server.dart` 一类指令一律视为过时。
- `flutter_config.yaml` 设置 `tree-shake-icons: false`，因为项目使用动态 `IconData`；不要在构建中开启图标树摇。
- Web 平台差异：`StyledToast` 等库用条件导入（`if (dart.library.io)`）提供存根实现，改动平台相关代码时注意。
- `build/`、`dist/`、`.dart_tool/`、各平台构建产物均为生成物，不要手工编辑或提交。
- `.claude/hooks/` 下存在 auto-commit 等钩子脚本；Agent 不应主动执行 git 提交、分支、reset 等操作。

## 环境变量

| 服务 | 变量 | 说明 |
|------|------|------|
| server-nodejs | `PORT` | 默认 8874 |
| server-nodejs | `DATA_DIR` | 数据目录，默认 `./data` |
| server-nodejs | `JWT_SECRET` / `TOKEN_EXPIRY_DAYS` | JWT 配置（未设置时使用开发默认值并告警） |
| server-nodejs | `ADMIN_USERNAME` / `ADMIN_PASSWORD` | 管理面板账号，默认 admin/admin123 |
| server-nodejs | `ALLOW_REGISTER` / `ENABLE_CORS` / `CORS_ORIGINS` / `MAX_REQUEST_SIZE` | 注册与 CORS 开关 |
| server-nodejs (MCP) | 无额外变量 | MCP 端点随主服务器启动，认证走请求头 `X-API-Key` / `X-Encryption-Key`，工具进程内直调插件处理器 |
