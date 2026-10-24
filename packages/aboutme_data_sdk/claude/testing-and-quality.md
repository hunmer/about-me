# 测试与质量

> 所属：packages/aboutme_data_sdk · [返回索引](../CLAUDE.md)

## 命令与基线

```bash
dart test --concurrency=1   # 42 个测试文件，214 项全过（2026-10-24 基线）
dart analyze                # 无 issue
```

必须单并发跑（存储类测试共享数据区/文件系统）。

## 42 个测试文件分组（test/）

| 组 | 文件（计数） |
| --- | --- |
| 本地/远端入口与存储层 | aboutme_data_test、aboutme_data_remote_test、data_store_test、http_storage_test、local_file_storage_test、auth_store_test、jwt_hs256_test、pbkdf2_compat_test、query_store_test、command_runtime_test（10） |
| 域 contract/business | chat_contract、chat_support、chat_stickers、diary_contract、contact_day_calendar_contract、activity_business、activity_cross_day、activity_overlap、activity_settings、bill_subscriptions、calendar_album_business、database_business、goods_business、habits_business、media_log_business、notes_nodes_business、openai_business、photo_editor_business、scripts_center_business、store_business、toolbox_business、webview_business（22） |
| 迁移与封闭 | checkin_migration、diary_migration、record_domains_migration、assets_migration_sweep、system_config_test（含旧布局注入→迁移→426→restoreBackup 演练）（5） |
| agent_chat | agent_chat_business、agent_chat_peripheral（2） |
| 资源契约与其他 | assets_contract、selfcheck_handoff、snapshot_domains（3） |

## 测试技巧

- **inject 模式**：构造损坏/遗留数据用磁盘 File 直写注入（照 `checkin_migration_test.dart`）。
- remote 测试断言用户隔离路径 `users/<id>/`，勿用数据区根。
- 新增封闭域后必须跑全量（--concurrency=1）确认无 426 回归。
