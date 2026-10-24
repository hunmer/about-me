# 入口与启动

> 所属：packages/aboutme_server · [返回索引](../CLAUDE.md)

## 启动链

```
bin/server.dart
  → ServerConfig.fromEnvironment()   # 读环境变量（config.dart）
  → server_builder.dart 组装 shelf pipeline
      → auth_middleware → storage/auth/plugin/system 路由 + /mcp + /debug + /admin 托管
      → LocalFileStorage/AuthStore（来自 aboutme_data_sdk 的 io 入口）
      → ws_hub + fcm_service
```

- 开发：`dart run bin/server.dart` 或仓库根 `procm-command start server`（cwd=本包）。
- 编译：`dart compile exe bin/server.dart -o bin/aboutme-server`（bin/ 下已有历史编译产物）。

## Docker

- `Dockerfile`：构建服务器 + **镜像内构建 admin 资产**（2026-10 CI 修复项）。
- `docker-compose.yml`：127.0.0.1:8874，数据持久化本包 `data/`；`.env` 提供 JWT_SECRET/ADMIN_PASSWORD。
- CI：`.github/workflows/` 在 **version tag** 触发服务器 Docker 镜像构建（d5a23130）。

## 管理界面

- 源码 `admin-vue/`（Vue 3 + Vite），`npm run build` 产物 → `admin/`；开发 `npm run dev`（/api 代理 localhost:8874）。
- 托管目录探测顺序：`ADMIN_DIR` → `DATA_DIR/admin` → 本包 `admin/`。
