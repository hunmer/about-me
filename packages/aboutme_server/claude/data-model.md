# 数据模型

> 所属：packages/aboutme_server · [返回索引](../CLAUDE.md)

本包不定义数据模型（全在 aboutme_data_sdk + shared_models）；此处只记录**落盘形态**。

## 数据区布局（DATA_DIR，默认本包 ./data）

```text
DATA_DIR/
├── auth/
│   ├── users.json      # 登录设备登记/注册（AuthStore，原子写）
│   └── api_keys.json   # API Key（mk_live_，含 lastUsedAt）
├── users/{userId}/
│   ├── {pluginId}/{file}.json   # 业务数据（按认证用户隔离）
│   └── configs/{key}            # system 域 config 命令落盘（原位）
├── admin/              # 托管目录探测顺序之一
└── （FCM service-account 等探测位置）
```

## 要点

- 明文 JSON；storage files API、插件 REST、MCP、SDK 本地模式操作**同一批文件**。
- 写操作经 SDK `legacy_write_policy`：28 域 + configs/ 前缀原始写 426（服务器侧同样生效，业务命令为唯一写入口）。
- AuthStore 并发治理（2026-10-24）：互斥锁 + 临时文件原子写；api_keys/users 损坏显式抛 `StorageException(invalidData)`（不再静默空表）。
- 审计：storage files 写操作带审计记录（local_file_storage，SDK 实现）。
- 二进制媒体为 asset:// 资源（引用计数），分块上传暂存 24h GC（SDK 实现）。
