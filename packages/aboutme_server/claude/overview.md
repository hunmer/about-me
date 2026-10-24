# 架构总览

> 所属：packages/aboutme_server · [返回索引](../CLAUDE.md)

## 薄壳定位

本包**不含数据业务逻辑**——全部来自 aboutme_data_sdk 的处理器；本包只做协议适配（HTTP/WS/JSON-RPC）、认证、限流/审计、广播与静态托管。改数据行为去 SDK 改，本包只关心"怎么暴露"。

```
客户端(AboutmeData.remote) ──REST──► 本服务器 ──同一套 SDK 处理器──► DATA_DIR/users/{id}/...
MCP(AI 工具)             ──JSON-RPC──►     ▲
所有写操作 ──WS file_updated(真实文件路径)──► 客户端/其它设备刷新
浏览器 ──► /admin/（Vue 管理面板）、/debug（插件 API 调试页）
```

## 请求流

`server_builder.dart` 组装 shelf pipeline：CORS → auth_middleware（JWT/API Key 双轨）→ 各路由模块：

| 路由模块 | 职责 |
| --- | --- |
| storage_routes | 文件 CRUD（ETag 条件写 + 限流 + 审计）+ WS `/api/v1/storage/ws` |
| plugin_routes | `/api/v1/plugins/{id}/*` 业务 API（X-API-Key，转发 SDK handler） |
| auth_routes | 注册/登录/Token/API Key/设备/FCM/访问控制 |
| system_routes | 管理员：插件注册表/商店配置（JS 插件执行返回 501） |
| mcp/ | `POST /mcp`（Streamable HTTP，tools.dart 定义工具） |
| debug_page / admin 托管 | `/debug` 静态调试页；`/admin/` Vue 面板 |

## 关键设计

- **用户隔离**：业务命令按认证用户落盘 `users/{userId}/`，互不可见（storage files API 同区）。
- **明文**：无加密层；认证兼容 nodejs 时代（JWT/PBKDF2/API Key 在 SDK 实现）。
- **广播真实文件路径**：REST/MCP 触发的变更同样经 ws_hub 广播，客户端刷新与本地写一致。
- **每用户运行时**：`user_data_runtimes.dart` 为认证用户维护 SDK 运行时实例（数据区子目录隔离）。
- **admin 托管目录探测**：`ADMIN_DIR` 环境变量 → `DATA_DIR/admin` → 本包 `admin/`。
