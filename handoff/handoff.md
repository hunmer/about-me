# 交接：统一数据 SDK 重构 —— C/D/E 阶段主体完成，剩余收尾与 F/G

**创建时间：** 2026-10-23（Asia/Shanghai）
**分支：** main（全部改动在工作区未提交，git status 有大量 M/?? 文件，属预期）
**仓库：** D:/about-me
**总计划：** docs/unified_data_sdk_refactor_plan.md
**状态文档：** docs/unified_data_sdk_refactor_status.md（已同步至最新）

## 摘要

本轮以 subagent 波次推进，完成了：tracker 孤儿 record 测试修复、16 域旧写封闭（426）、D 阶段全部 8 域 SDK 命令化、E 阶段全部 6 域收口、C 阶段 notes/nodes 完成与 agent_chat 主数据完成。

**最终验证基线：`cd packages/aboutme_data_sdk && dart test --concurrency=1` → 158 项全部通过；`dart analyze` 无问题；各域 `flutter analyze lib/plugins/<域>` 目录级通过。**

## 已完成（本轮证据）

### 封闭（legacy_write_policy.dart migratedDomains，原始写一律 426）
diary、todo、tracker、notes、nodes、contact、day、calendar、checkin、habits、bill、goods、store、calendar_album、media_log、database（共 16 域）。

### 各域实现要点（新会话可参照的模式）
| 模式 | 参照 | 适用 |
| --- | --- | --- |
| 记录域迁移（migrate/restoreBackup/exportData 路由、首写后快照、孤儿/损坏 CORRUPT_DATA 拒绝） | migrations/record_domains_migration.dart + handlers/tracker.dart、checkin.dart | todo/tracker/checkin |
| 首写备份（首次成功写前备份原始文件到 `<域>/migration_v1_backup.json`） | handlers/habits.dart、agent_chat.dart、store.dart、media_log.dart、database.dart | 单/多文件新域 |
| 结构化域备份恢复（structuredDomainFiles 清单 + ensureDomainBackup/restoreDomainBackup） | handlers/structured_support.dart | contact/day/calendar/calendar_album |
| 幂等积分（clientMutationId 事件级去重） | handlers/store.dart + lib/plugins/store/events/point_award_event.dart | 复合命令 |
| 数据搬家（事务内读旧→写新→删旧，查询只读回退） | handlers/database.dart + plugin_data.dart 的 removeLegacyAsset | 旧路径迁移 |
| saveConversations/saveAccounts 等全量保存（兼容旧客户端整文件语义） | handlers/agent_chat.dart、bill.dart | 有静态缓存+保存链的 Flutter 侧 |

### 本轮修复的缺陷
- tracker addRecord 孤儿记录语义（允许写入、迁移校验拒绝）
- contact/day/calendar restoreBackup 强制 confirmRestore（原无校验）
- calendar resetData 空库首调写坏备份格式（backupDomain→ensureDomainBackup）
- store 积分"完成→撤销→再完成"刷分漏洞（实体级幂等键）

## 剩余任务（按优先级）

### 1. C 阶段收尾：agent_chat 外围配置迁移 → 封闭
主数据（conversations/messages/config/getStats）已完成（handlers/agent_chat.dart，17 路由）。剩余文件层直写（均 lib/plugins/agent_chat/ 下）：
- services/tool_config_manager.dart（969 行，`agent_chat/tools` 前缀 20+ 处，被 lib/core/js_bridge/js_tool_registry.dart、platform/mobile_js_engine.dart 复用）
- services/tool_template_service.dart:167,210,223
- services/message_detail_service.dart:41,61,84
- services/route_agent_config_service.dart:60,81
- widgets/message_input.dart:110,122；suggested_questions_dialog.dart、suggested_question_test_dialog.dart、suggested_question_test_runner.dart
- test_runs/、quick_toolbar_actions
全部改走 data.call 后，把 'agent_chat' 加入 migratedDomains。

### 2. D 阶段收尾
- activity 设置文件收口：lib/plugins/activity/activity_plugin.dart:677-760 与 models/tts_announcement_settings.dart:97-118 仍 writePath('activity/notification_settings.json'、'activity/tts_announcement_settings.json')。迁为 SDK 命令（可仿 media_log 的 getSettings/updateSettings）后封闭 activity。
- tracker goal_images 资源化（lib/plugins/tracker/widgets/goal_edit_page.dart:282 saveDirectory）——归 F 阶段资源体系。
- store 整表 save* 并发 last-writer-wins 可改按行提交（非阻塞）。

### 3. F 阶段（未开始，四线可并行）
- **P1 资源扩展**：handlers/assets.dart 大文件/分块上传（现 16MiB 有界 JSON/base64；REST/MCP 24MiB 在 packages/aboutme_server/lib/src/business_request_body.dart:10）、migrateLegacyAssets 批量迁移（chat 旧贴图二进制、各域历史本地图片路径）、引用计数=0 的 sweep/回收（asset_references.dart 已有索引）。capabilities.dart 协议版本需 bump。
- **P2 系统配置 SDK 化**：packages/aboutme_server/lib/src/system_routes.dart:36-37,106-121 直接 File 读写 plugin_registry.json/store_config.json；fcm_service.dart:38-51 读 service-account.json。迁入 SDK 系统/资源服务。
- **P3 扩展插件**（readPath/writePath 计数）：openai 54、scripts_center 35、toolbox 16、webview 13、timer/achievement/reminder/live2d/tts 各 2。逐插件按 D 阶段模式做。注意 timer 已在 SDK `_genericPlugins`（route_config.dart 尾部）可先评估。
- **P4 管理后台与平台桥接**：packages/aboutme_server/admin-vue/src/components/files/FilesTab.vue 对已迁移域展示 426/UPGRADE_REQUIRED 引导（服务端 gating 已就绪）；lib/core/storage/mobile_storage.dart、web_storage.dart 收编为 SDK 平台适配层。

### 4. B 阶段状态确认
用户已于 2026-10-23 确认 Chat/Diary"已经完成"。状态文档 B 行仍列有退出条件（Chat 整域备份迁移/旧写封闭/旧资源迁移/媒体选择器编辑器入口/AI 流式与远端删除测试、Diary 错误 UI 与外围导入导出）。**新会话先与用户确认**这些是否仍需处理，避免与用户判断冲突。

### 5. G 阶段（最后）
C/D/E/F 全部完成后：删除兼容层、原始文件更新全封闭、迁移恢复验收。

## 共享文件（多 agent 并行时的冲突点）
- packages/aboutme_data_sdk/lib/src/services/route_config.dart（各域段；新段统一插在"其他插件使用通用路由"注释行前）
- …/handler_factory.dart（各域 case）
- …/migrations/record_domains_migration.dart（recordDomainFiles switch）
- lib/src/legacy_write_policy.dart（migratedDomains；**必须在该域 Flutter 零残留直写后才能加**，加完跑全量测试）
- …/handlers/structured_support.dart（structuredDomainFiles）

## 验证命令
```bash
cd packages/aboutme_data_sdk
dart test --concurrency=1          # 基线 158 全绿；新域加测试后相应增长
dart analyze                       # 须无 issue
# Flutter 侧（Windows）：
cd D:/about-me && flutter analyze lib/plugins/<域>
```

## 注意事项
- 测试里构造损坏/遗留数据用磁盘 File 直写注入（照 test/checkin_migration_test.dart 的 inject 模式）；封闭域的 data.writeFile/writePath 会 426。
- handler 内部 data.read/write 不受 LegacyWritePolicy 限制（policy 只拦 AboutmeData 原始文件 API 层）。
- Flutter 侧收口参照：lib/plugins/checkin/repositories/client_checkin_repository.dart、lib/plugins/day/controllers/day_controller.dart（watch/query/call 模板）。
- 不要 git commit（用户未要求）。改 mira-app-core 才需要 build + mira-app-server 重新 install（本轮未涉及）。
