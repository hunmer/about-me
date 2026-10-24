# 模块职责

> 所属：packages/aboutme_server · [返回索引](../CLAUDE.md)

lib/src/ 全部 15 文件（含 mcp/ 子目录）：

| 文件 | 职责 |
| --- | --- |
| server_builder.dart | 组装 shelf pipeline 与全部路由挂载（服务器骨架） |
| config.dart | ServerConfig.fromEnvironment——全部环境变量读取与默认值 |
| auth_middleware.dart | JWT / API Key 双轨认证中间件 |
| auth_routes.dart | 注册/登录/Token/API Key/设备登记/FCM 绑定/访问控制 |
| storage_routes.dart | `/api/v1/storage/files/*` 文件 CRUD（ETag 条件写、限流、审计）+ WS 端点 |
| plugin_routes.dart | `/api/v1/plugins/{id}/*` 业务 REST（转发 SDK 处理器；斜杠 key 走 query json-v1 编码） |
| system_routes.dart | 管理员系统接口（插件注册表/商店配置；JS 插件执行 501） |
| business_request_body.dart | 业务请求体解析（REST body → 命令参数） |
| user_data_runtimes.dart | 按认证用户维护 SDK 运行时（数据区 users/<id>/ 隔离） |
| ws_hub.dart | WebSocket 广播 `file_updated`（真实文件路径，REST/MCP 触发同样广播） |
| fcm_service.dart | FCM 推送（service-account 签名） |
| debug_page.dart | `/debug` 插件 API 调试页（读磁盘静态页，改完刷新即生效） |
| mcp/mcp_endpoint.dart | `POST /mcp` Streamable HTTP 端点（JSON-RPC） |
| mcp/tools.dart | MCP AI 工具定义（工具事实源；grep name 字段 83 处，README 称 68 为历史快照） |
| aboutme_server.dart（lib/ 根） | 包导出 |

另有 bin/server.dart（入口）、Dockerfile + docker-compose.yml（部署）、admin-vue/（Vue3 管理前端源码，构建产物 admin/）。
