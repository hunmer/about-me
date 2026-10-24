# 文件地图

> 所属：packages/aboutme_server · [返回索引](../CLAUDE.md)

```text
aboutme_server/
├── CLAUDE.md              # 本索引
├── README.md              # 官方说明（部分数字为历史快照）
├── pubspec.yaml
├── bin/server.dart        # 入口；bin/aboutme-server 编译产物
├── Dockerfile / docker-compose.yml / .env.example
├── lib/
│   ├── aboutme_server.dart        # 包导出
│   └── src/
│       ├── server_builder.dart    # 服务器骨架（路由挂载）
│       ├── config.dart            # ServerConfig 环境变量
│       ├── auth_middleware.dart / auth_routes.dart
│       ├── storage_routes.dart    # 文件 CRUD + WS
│       ├── plugin_routes.dart     # 业务 REST
│       ├── system_routes.dart     # 管理员接口
│       ├── business_request_body.dart
│       ├── user_data_runtimes.dart
│       ├── ws_hub.dart / fcm_service.dart / debug_page.dart
│       └── mcp/mcp_endpoint.dart、mcp/tools.dart
├── test/                  # 6 个测试文件（见 testing-and-quality.md）
├── admin-vue/             # Vue3 管理前端源码（npm run build → ../admin）
├── admin/                 # 构建产物（服务器托管 /admin/）
├── debug/                 # /debug 静态调试页（读磁盘，改完刷新生效）
└── data/                  # DATA_DIR 默认位置（本机暂不存在——未在本机跑过）
```
