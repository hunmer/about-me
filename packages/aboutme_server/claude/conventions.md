# 开发约定

> 所属：packages/aboutme_server · [返回索引](../CLAUDE.md)

## 命令

```bash
# 本地开发（推荐经仓库根 procm）
procm-command start server            # = dart run bin/server.dart（cwd 本包）
dart run bin/server.dart              # 直接跑
dart compile exe bin/server.dart -o bin/aboutme-server   # 单文件可执行

# 质量
dart analyze && dart test             # 38 项全过（6 测试文件）
cd admin-vue && npx vue-tsc -b        # 管理前端类型检查
procm-command start server-admin-build  # = admin-vue npm run build → ../admin/

# Docker
cp .env.example .env                  # 设强随机 JWT_SECRET / ADMIN_PASSWORD
docker compose up -d --build          # 127.0.0.1:8874，数据持久化本包 data/
```

## 依赖更新

改了 aboutme_data_sdk 后：重新构建 SDK 并在本包 `dart pub get`（path 依赖）再重启服务器（vite/热重启不适用于 server）。

## 安全提醒

- 未设 `JWT_SECRET` 时回落到**固定开发密钥**（仅限开发环境，启动时有 stderr 警告）。
- `ADMIN_PASSWORD` 默认 `admin123`——生产必须覆盖。
- 服务仅映射 127.0.0.1，不要直接暴露公网；需要外网时自行加反代与 TLS。
