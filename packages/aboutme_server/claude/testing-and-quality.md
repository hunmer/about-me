# 测试与质量

> 所属：packages/aboutme_server · [返回索引](../CLAUDE.md)

## 命令与基线

```bash
dart analyze && dart test   # 38 项全过（2026-10-24 基线）
cd admin-vue && npx vue-tsc -b
```

## 6 个测试文件（test/）

| 文件 | 覆盖 |
| --- | --- |
| server_integration_test | 服务器集成（路由/认证/存储全链路） |
| aboutme_data_remote_test | **真实 Shelf server 端到端**：斜杠 key query json-v1 编码、PUT/DELETE body、users/<id>/configs/ 落盘、426、capabilities、并发（AuthStore 401 修复回归） |
| business_request_body_test | 业务请求体解析 |
| system_config_migration_test | system config 迁移演练（服务器侧） |
| fcm_service_test | FCM 签名向量 |
| plugin_mcp_test | MCP 端点与工具 |

## 注意事项

- 断言落盘路径必须带 `users/<id>/` 用户隔离前缀，勿用 DATA_DIR 根。
- README"29 个测试"为历史快照（现 38 项）。
- 集成测试起真实 server，注意端口/数据目录隔离（照现有测试的临时目录模式）。
