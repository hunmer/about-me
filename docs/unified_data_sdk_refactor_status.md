# 统一数据 SDK 重构执行状态

更新时间：2026-10-23。总目标仍在进行，**不得将基础设施或通用 CRUD 当作全阶段完成**。

| 阶段 | 状态 | 已落实 | 尚未退出的条件 |
| --- | --- | --- | --- |
| A | 进行中 | AST 候选清单、动作/协议表、HTTP 所有 method、参数/错误、取消离线回退、共享命令锁、恢复日志、版本/持久幂等、提交事件、SDK query/watch、Web 注入入口、Chat/Diary codec 与 typed facade、服务端认证用户 runtime、请求来源/设备上下文隔离 | 清单逐项归属审查、完整动作 schema、进程内账号/后端热切换、Web 持久化原子性验收 |
| B | 进行中 | Chat 主业务/Repository/UI/AI/JS/线程/设置/样例已改业务命令，消息 watch/分页；Diary 主业务/统计/示例/导入导出/备份迁移及原始旧写封闭；贴图注册表事务命令、watch、备份和旧写封闭；新附件使用稳定资源 ID | Chat 整域备份迁移和原始旧写封闭、旧资源迁移、媒体选择器及编辑器全部入口、AI 流式/远端删除边界、Diary 查询失败 UI 与外围导入导出；两域完整验收 |
| C | 进行中 | notes/nodes：业务命令完备 + Flutter 全走 SDK + 已入 migratedDomains 封闭原始写；agent_chat：主数据（会话/消息/config/getStats）SDK handler 17 路由 + Flutter 5 文件收口（含 openai 复用自动受益；外围配置保留文件层） | agent_chat 外围配置（tools/tool_templates/route_agent_configs/message_details/suggested_questions 等）入口迁移，之后封闭；notes/nodes restore 路由可选 |
| D | 进行中 | todo/tracker/checkin：记录域迁移（migrate/restoreBackup/exportData、首写快照、孤儿/损坏拒绝）+ 封闭；habits：全新 handler（19 动作，文件布局兼容旧数据）+ Flutter 4 文件收口 + 封闭；bill：subscriptions/saveAccounts/getAccountsWithBills 命令 + Flutter 收口 + 封闭；goods：物品 CRUD 修正到 warehouse/{id}.json 内嵌 + updateWarehouse/preferences + Flutter 收口 + 封闭；activity：8 个新命令（区间统计/标签分组/最近标签心情）+ Flutter 收口（设置文件暂留文件层）；store：全新 handler 五集合 + purchase/redeem/useItem 单事务复合命令 + addPoints clientMutationId 幂等（事件级去重键，修复完成→撤销→再完成刷分）+ point_award_event/achievement 收口 + 封闭 | activity 设置文件（notification/tts）收口与封闭；tracker goal_images 资源化；整表 save* 并发 last-writer-wins 可改按行提交 |
| E | 已完成（六域入口全部收口） | contact/day/calendar：Flutter 全走 SDK + restoreBackup 路由与 confirmRestore 强制 + resetData 备份格式修复 + 封闭 + 契约测试 16 项；calendar_album：专用 handler（条目 CRUD/tags/import/export/stats）+ Flutter 两 controller 收口（tag 三文件沿用 data/ 顶层零迁移）+ 封闭 + 测试 15 项；media_log：专用 handler（含 seedExamples 幂等替代空数据自动写示例）+ plugin 收口 + 封闭 + 测试 3 项；database：专用 handler + 顶层 records_*/databases 搬家到 database/ 分区（事务内读旧写新删旧，查询只读回退）+ 去静默降级 + 封闭 + 测试 5 项；activity 补 getById 路由 | 无（六域全部退出） |
| F | 进行中（资源基础） | 通用资源上传/读取/校验/删除、引用索引、临时物化生命周期、宿主文件输入适配 | 扩展插件（openai 54 处/scripts_center 35 处等 F 批）、资源全量迁移/大文件/回收、系统配置（system_routes 直读写入 SDK）、管理后台与平台桥接 |
| G | 未开始 | — | 删除兼容层、原始文件更新全封闭、迁移恢复验收（等 C/D/E/F 完成） |

## 记录域迁移（todo/tracker）测试已完成

更新时间：2026-10-23。

- `test/record_domains_migration_test.dart` 3 项测试全部通过：首次写入后全量迁移与幂等、孤儿 record 拒绝迁移且不写清单、备份恢复当前快照。
- `migrations/record_domains_migration.dart`：首次成功写入后再做全量快照与校验（写入前预检会导致 addRecord 误拒孤儿记录）；`getMigrationReport` 始终校验当前数据（孤儿 record 即使在清单已写入后也会被发现），清单损坏时抛 `CORRUPT_DATA`。
- `handlers/tracker.dart` `addRecord`：孤儿 record（goalId 不存在的目标）允许写入、跳过 goal 进度更新，由迁移快照校验以 `CORRUPT_DATA` 拒绝；移除了 goal 存在性前置外键校验。
- `route_config.dart` 已为 todo/tracker 增加 `migrate`、`restoreBackup`、`exportData` 路由。
- 验证：`dart test --concurrency=1` 全量 93 项通过；`dart analyze` 无问题。


## 已验证的基础能力

### 2026-10-23 本轮新增（波次推进）

- legacy_write_policy 封闭域扩至 12 个：diary、todo、tracker、notes、nodes、contact、day、calendar、checkin、habits、bill、goods（原始写返回 426）。封闭前逐域确认 Flutter 侧零残留直写；activity 因 notification/TTS 设置文件仍在 activity/ 前缀下文件层读写而暂缓。
- checkin：deleteRecord 命令（删记录回滚统计）、记录域迁移四命令、repository 收口；test/checkin_migration_test.dart。
- habits：全新 handler 19 动作（habits/skills/records 分文件/view_settings，文件布局与旧客户端一致天然兼容）、Flutter 3 controller + 视图收口；test/habits_business_test.dart（双实例追加）。
- bill：subscriptions CRUD、saveAccounts/getAccountsWithBills（保留 JSON 字符串账户格式字节级兼容）、两个 controller 收口；test/bill_subscriptions_test.dart。
- goods：物品 CRUD 修正为 warehouse/{id}.json 内嵌布局（弃 items.json 旧格式）、updateWarehouse/clearWarehouse/preferences、plugin 全部直写收口；test/goods_business_test.dart。
- activity：getRange/getRangeStats（区间聚合一次调用替代逐日循环）、标签分组/最近标签/最近心情命令、ActivityService 四类文件收口（设置文件除外）；test/activity_business_test.dart。
- 全量测试 111 项通过、dart analyze 无问题；各域 flutter analyze 目录级通过。
- 波 C（已完成）：store 全新 handler（五集合 snake_case 兼容 + purchase/redeem/useItem 复合命令业务失败全回滚 + addPoints clientMutationId 幂等；point_award_event 九类事件按实体 ID 去重、checkin 按天、成就按级），store/achievement 收口并封闭 store；agent_chat 主数据 handler（conversations/messages 分文件/config 无扩展名经 checkedPath 可行/getStats），5 文件收口，openai 复用自动受益，全量 135 项通过。
- contact/day/calendar 契约测试 16 项（test/contact_day_calendar_contract_test.dart）；修复三域 restoreBackup 缺 confirmRestore 校验、calendar resetData 空库首调写坏备份格式（backupDomain→ensureDomainBackup）。
- 波 D（已完成）：calendar_album（15 测试；tag 三文件确认落盘 data/ 顶层，经 'data' 分区沿用原路径零迁移；加 onPluginChanged watch）、media_log（3 测试；seedExamples 幂等）、database（5 测试；PluginData 新增 removeLegacyAsset 受控通道支持事务内删分区外旧文件；去 catch 返回 [] 静默降级）。三域已入 migratedDomains 封闭（共 16 域）。
- 最终基线：`dart test --concurrency=1` 全量 **158 项通过**、`dart analyze` 无问题、各域 flutter analyze 目录级通过。

- SDK 原有 41 项测试中的旧强写预期已改成显式冲突；新增 runtime、query、契约测试。
- 100 个独立 backend 并发追加保留全部消息；业务失败丢弃暂存写入。
- 版本冲突不写入、不发事件；相同 mutationId 在新 backend 中返回原结果，参数变化返回冲突。
- 模拟多文件提交中断后，下一实例先完成消息/频道/索引/幂等状态，再对外查询。
- 损坏 JSON 返回 CORRUPT_DATA，原文件不被覆盖；路径穿越被拒绝。
- 多订阅者独立取消、失效期间旧响应被丢弃、离线保留旧快照、旧实例返回不污染新实例。
- 同目录另一 SDK 实例提交能更新本地 watch；同毫秒消息游标无重复、无遗漏。
- 实际 Shelf 服务已验证 SDK GET/POST/PUT/PATCH/DELETE、null、字符串 ID、路径身份冲突和分页校验。
- 两个 SDK HTTP 客户端与 MCP 混合并发追加后，本地 SDK 查询得到相同数据。
- 同一服务端按认证用户复用 runtime，并发 REST/MCP 的 source/sourceDeviceId 通过 Zone 隔离。
- Chat/Diary 的 Repository 更新保留字段缺省与显式 null，旧 DTO 的版本冲突不会自动覆盖；日记 JS 使用真实分页统计。
- Diary 首次成功命令与规范化迁移同事务；损坏/未来格式拒绝覆盖；备份可通过 SDK 维护事务恢复，再次迁移安全。
- Diary 的普通原始 PUT/DELETE/父前缀清除（包括 force、Windows 大小写与尾部点空格变体）返回 426 / UPGRADE_REQUIRED。
- 资源与贴图 15 项定向测试通过：并发追加、重命名、持久幂等、资源索引分页、资源引用保护、损坏校验、越界路径、物化释放。
- 真实服务器验证资源 local/HTTP/REST/MCP 内容与引用一致；原始 assets、贴图注册表写入被拒绝。

配置页沿用“保存后重启生效”：连接测试仅使用临时连接，本会话 HTTP/SDK/WS 保持原账号；完整进程内热切换尚未实现。

资源首版使用有界 JSON/base64（单个 16 MiB），REST/MCP 请求体在读取流时限制为 24 MiB。原生临时句柄可显式 dispose；兼容播放器的会话路径由 SDK 销毁时清理。Web 可读取资源字节和展示图片，文件路径物化明确 unsupported。大视频/分块上传、旧资源批量迁移和无引用回收仍未完成。

贴图合集/消息引用与独立资源引用索引同事务提交，移除合集不直接删除共享资源。贴图备份目前只包含原注册表 JSON，旧二进制资源尚未纳入完整迁移备份。Chat 尚未列入 migratedDomains，不能据贴图注册表封闭推断整个 Chat 已封闭。

Flutter 侧 chat_channel_persistence 与 plugin_sample_data_http 共 14 项测试通过，包括客户端附件/贴图走业务 API、日记离线统计抛错与重试清除错误。SDK/服务端全量测试在文档前一轮已通过。以上是基础测试证据，不替代 Flutter 插件端到端验收。未使用真实浏览器。没有扫描或改写真实用户数据目录，也未部署服务。

## 下一工作项

1. 补齐 Chat 旧数据/旧资源迁移及媒体选择器、编辑器、完整引用清理；补 AI 流式与远端删除测试。
2. 完成 Diary 错误展示、外围全量备份导入/导出；推进 A 的清单审查、完整 schema、Web 原子性与热切换。
3. ~~修复 tracker 孤儿 record 迁移场景~~ 已完成（2026-10-23）：addRecord 允许孤儿写入，迁移校验以 CORRUPT_DATA 拒绝；todo/tracker 迁移测试 3/3、全量 93 项通过。
4. 依次推进 C/D/E/F，全部完成后才删除兼容层并验收 G。
