# 统一数据 SDK 重构执行状态

更新时间：2026-10-24。总目标仍在进行，**不得将基础设施或通用 CRUD 当作全阶段完成**。

| 阶段 | 状态 | 已落实 | 尚未退出的条件 |
| --- | --- | --- | --- |
| A | 进行中 | AST 候选清单、动作/协议表、HTTP 所有 method、参数/错误、取消离线回退、共享命令锁、恢复日志、版本/持久幂等、提交事件、SDK query/watch、Web 注入入口、Chat/Diary codec 与 typed facade、服务端认证用户 runtime、请求来源/设备上下文隔离 | 清单逐项归属审查、完整动作 schema、进程内账号/后端热切换、Web 持久化原子性验收 |
| B | 已完成（用户 2026-10-23 口头确认，2026-10-24 复核后关闭） | Chat 主业务/Repository/UI/AI/JS/线程/设置/样例已改业务命令，消息 watch/分页；Diary 主业务/统计/示例/导入导出/备份迁移及原始旧写封闭；贴图注册表事务命令、watch、备份和旧写封闭；新附件使用稳定资源 ID | 无（用户确认 Chat/Diary 两域按现状验收退出；残余外围项转入小尾巴跟踪：chat 旧贴图迁移入口待接，媒体选择器/编辑器外围入口与 AI 流式边界按需收口） |
| C | 已完成（agent_chat 全域收口） | notes/nodes：业务命令完备 + Flutter 全走 SDK + 已入 migratedDomains 封闭原始写；agent_chat：主数据（会话/消息/config/getStats）SDK handler 17 路由 + Flutter 5 文件收口（含 openai 复用自动受益）；外围配置 17 命令（tools 插件配置/索引/清空、tool_templates、message_details、route_agent_configs、test_runs、preferences 键白名单）+ Flutter 7 文件收口（tool_config_manager 19 处全部 call 化）+ 已入 migratedDomains 封闭 | notes/nodes restore 路由可选 |
| D | 已完成（全部收口封闭） | todo/tracker/checkin：记录域迁移（migrate/restoreBackup/exportData、首写快照、孤儿/损坏拒绝）+ 封闭；habits：全新 handler（19 动作，文件布局兼容旧数据）+ Flutter 4 文件收口 + 封闭；bill：subscriptions/saveAccounts/getAccountsWithBills 命令 + Flutter 收口 + 封闭；goods：物品 CRUD 修正到 warehouse/{id}.json 内嵌 + updateWarehouse/preferences + Flutter 收口 + 封闭；activity：8 个新命令 + getNotificationSettings/updateNotificationSettings/getTtsSettings/updateTtsSettings + Flutter 设置收口（含额外 3 处残留）+ 封闭；store：全新 handler 五集合 + purchase/redeem/useItem 单事务复合命令 + addPoints clientMutationId 幂等 + point_award_event/achievement 收口 + 封闭 | tracker goal_images 确认已资源化（ImagePickerDialog 的 saveDirectory 为死参数，媒体全部走 SdkMediaService/SDK 资源系统，死参数留 G 清理）；store 整表 save* 按行提交为非阻塞优化未做 |
| E | 已完成（六域入口全部收口） | contact/day/calendar：Flutter 全走 SDK + restoreBackup 路由与 confirmRestore 强制 + resetData 备份格式修复 + 封闭 + 契约测试 16 项；calendar_album：专用 handler（条目 CRUD/tags/import/export/stats）+ Flutter 两 controller 收口（tag 三文件沿用 data/ 顶层零迁移）+ 封闭 + 测试 15 项；media_log：专用 handler（含 seedExamples 幂等替代空数据自动写示例）+ plugin 收口 + 封闭 + 测试 3 项；database：专用 handler + 顶层 records_*/databases 搬家到 database/ 分区（事务内读旧写新删旧，查询只读回退）+ 去静默降级 + 封闭 + 测试 5 项；activity 补 getById 路由 | 无（六域全部退出） |
| F | 资源专项（P1/P2/P3 主体完成，剩 P4） | 通用资源上传/读取/校验/删除、引用索引、临时物化生命周期、宿主文件输入适配；P2 系统配置 SDK 化：system 域，server system_routes 改走 SDK，启动时顶层配置一次性搬入 system/ 分区（集成测试）；P3 全部八域：timer/achievement/reminder/live2d/tts（快照域）、webview（settings/tabs/cards + JS bridge KV）、openai（25 命令薄文件层）、toolbox（10 命令）、scripts_center（23 命令四组 + 分区迁移：scripts/、configs/scripts_center* 一次性迁入 scripts_center/ 分区，script.js 裸文本经命令存 String 值，dart:io 扫描/级联删除由命令替代，迁移幂等）；P1 资源扩展完成：migrateLegacyAssets（白名单域前缀媒体文件批量迁资源，迁移记录幂等，迁后删旧）、sweep（引用=0 回收，dryRun/minAgeHours 保护）、分块上传 init/append/complete（8MiB/块、总 256MiB、sha256 校验、24h 暂存 GC）、BinaryPluginPersistence.exists 修复 removeLegacyAsset 对二进制的存在性判断、capabilities assets.protocolVersion 2；openai/toolbox 媒体资源化：新写全走 SdkMediaService，三套一次性幂等迁移（openai 头像/moments 帖图背景资产图/toolbox 生图历史），显示端经 createImageProvider 资源感知 | P4 管理后台已完成：FilesTab 对已迁移域的删除预判（capabilities 动态域清单）与 426/UPGRADE_REQUIRED 升级引导（apiClient 426 特判 + 单删/批删入口预判 + 失败兜底，vue-tsc 通过）；平台适配层评估完成——StorageInterface 契约已下沉 SDK（宿主 storage_interface.dart 为转发），mobile_storage/web_storage 因 Flutter 插件依赖（path_provider/shared_preferences/fs_shim）实现须留宿主，当前"SDK 契约 + 宿主实现"即依赖倒置的平台适配层，物理拆包归 G 架构清理；chat 旧贴图二进制批量迁移入口待接（readLegacySticker/migrateLegacyAssets 通道均已有）；孤立旧文件（toolbox/image_search/、openai/agents/）可由 sweep 回收；openai uninstall 卸载清理留 G；service-account.json 保持本地 File（部署凭证） |
| G | 主体完成（2026-10-24 第五轮命令化+封闭、第六轮收尾优化完成） | ImagePickerDialog saveDirectory 死参数全链删除（24 文件，avatar/video picker 活参数保留）；openai uninstall deletePath 残留清除（卸载保留数据分区）；文件层 API 调用面调查完成；SDK 拆 flutter 变体包评估完成——**不拆**；**system 域 configs 设置命令化**（getConfig/setConfig/deleteConfig 借 'configs' 分区原地读写零迁移，GET/PUT/DELETE /system/config，key 走 query/body 避免多段路径参数编码歧义；key 白名单校验防穿越）；**Flutter 侧 7 类 configs 写入面全部收口**（ConfigManager app_config/插件设置、PluginBase loadSettings/saveSettings、bill 重写删除回归基类、webview 商场源×2、photo_editor ai_edit_config、plugin_manager 配置、route_history 含 412 特判删除——命令事务写无版本冲突）；script_loader 迁移删旧改走 deleteConfig 命令；**configs/ 前缀进 _protectedRoots 全封闭**（原始写 426，命令/读 API 不受限，server deleteRawFile 同受拦截 FilesTab 426 兜底已有）；迁移恢复演练测试（todo 旧布局磁盘注入→migrate 清单落盘→原始写 426→update 后 restoreBackup 恢复快照）；REST 远端链路验证（json-v1 query 编码头两端匹配，斜杠 key 无歧义）；**photo_editor 建域（第六轮）**：getHistory/saveHistory/clearHistory 薄文件层命令（photo_editor/history.json 原位零迁移），Flutter PhotoEditorHistory 收口，第 28 个封闭域；**顶层裸配置收编（第六轮）**：floating_ball_config 与 action_config 主配置迁入 configs/ 统一通道（AboutmeDataService.migrateTopLevelConfig 读旧→写新→删旧幂等，内存去重；action_config_backups/ 快照目录留文件层顶层）；**capabilities protectedPrefixes 字段（第六轮）**（非域保护前缀对外声明，admin FilesTab 预判消费留 macOS 侧） | admin FilesTab 消费 protectedPrefixes（macOS 侧 admin-vue）；文件层 API 最终定位为迁移与只读兼容层（写通道已全封闭，剩余调用面全部合法：迁移读旧删旧/读判断/备份快照），物理删除仅待迁移代码退役 |

## 第三轮（2026-10-24）：scripts_center + F-P1 资源专项

- **scripts_center 完成（第 25 个封闭域）**：跨分区数据（scripts/<id>/metadata.json + script.js 裸文本、configs/scripts_center/* 配置与执行日志、无扩展名 installed 登记）一次性迁入 scripts_center/ 分区（Flutter 侧 migrateLegacyPartition 幂等执行，读旧→写命令→删旧）；SDK 23 命令四组（scripts：list/getMeta/saveMeta/getCode/saveCode/create/delete/exists/syncBuiltin 版本比较；scriptConfig；execLog：recordExecution 头插+滚动 200 上移 handler；store：sources/installed）；script.js 经命令存 String 值（磁盘为 JSON 字符串，读写一致）；dart:io 目录扫描/递归删除由命令等价能力替代；9 项 SDK 测试 + 6 文件 Flutter 收口。
- **F-P1 资源专项完成**：
  - migrateLegacyAssets 命令：白名单（已封闭域 + openai/toolbox/scripts_center/stickers 前缀 + 媒体扩展名）批量迁移分区外旧媒体为资源；迁移记录 legacy_migration.json 幂等（同路径复用既有资源）；迁移成功自动删旧；单次 50 项、分批调用。
  - sweep 命令：引用计数 0 的资源回收，dryRun 默认开、minAgeHours（默认 24）保护刚上传未引用资源。
  - 分块上传三命令：initUpload（size ≤256MiB、可选 sha256、24h 超龄暂存 GC）→ appendChunk（8MiB/块、乱序/重复幂等、越界拒绝）→ completeUpload（缺块/大小/sha256 校验、合并成资源、暂存清理）。暂存 assets/uploads/（manifest .json、chunk 无扩展名不进索引）。REST body 24MiB 上限容纳单块 base64 无需调整。
  - 修复 SDK：BinaryPluginPersistence 增加 exists（字节感知），_TransactionData.removeLegacyAsset 存在性判断不再经 JSON 解码（对 PNG 等二进制旧文件原先必抛 CORRUPT_DATA）。
  - capabilities：assets.protocolVersion 1→2（chunked/migration/sweep 能力描述）。
- **openai/toolbox 媒体资源化 + 封闭（第 26/27 个封闭域）**：openai 默认头像/moments 帖图/背景/资产图、toolbox 生图产物与搜图保存全部改走 SdkMediaService（新数据存 asset:// 引用）；三套一次性幂等迁移（openai 头像 assets+数据区双来源、moments images/assets、toolbox ai_image history）经 migrateLegacyAssets 迁移并更新业务数据引用（'./x' 与 'x' 双形态匹配）；显示端消费链路（avatarUrl/posts images/profile_bg/生图历史）经排查全部资源感知兼容；uninstall 的 deletePath 保留并 catch 426 静默（清理留 G）。
- **migratedDomains 扩至 27 域**（24 + scripts_center + openai + toolbox）。
- **验证**：SDK `dart test --concurrency=1` 全量 **201 项通过**（+9 scripts_center、+4 assets P1）、`dart analyze` 无问题；`flutter analyze lib/plugins` 无 error（13 项历史遗留 lint：1 unused warning + 12 风格 info，均在本轮未触碰文件）；server 36 过 1 失败（HEAD 既有并发 UNAUTHORIZED）。
- **F-P4 完成**：admin-vue FilesTab 426 引导——apiClient 426 特判（status/code 标记 + 统一文案）、fetchMigratedDomains 从 /api/v1/plugins/capabilities 动态拉取封闭域清单、单删/批删入口预判（已迁移域弹升级引导不走删除）、catch 426 兜底与批量失败分类提示；vue-tsc -b 通过。平台适配层收编评估：接口契约已下沉（宿主转发），实现留宿主的依赖倒置模式成立，物理拆包（flutter 变体包）留 G。
- **网络故障恢复**：scripts_center subagent 中途因 API DNS 故障中断，其 SDK 侧成果（handler 228 行 + 9 测试 + 路由注册 + Flutter 6 文件）完整保留，主会话修复 2 个编译错误与 2 个 lint 后收尾。

## 第六轮（2026-10-24）：G 阶段收尾优化

- **photo_editor 建域（第 28 个封闭域）**：handlers/photo_editor.dart 薄文件层命令（getHistory/saveHistory/clearHistory，photo_editor/history.json 顶层 List 原位读写零迁移，损坏与入参校验 CORRUPT_DATA/INVALID_PARAMS 拒绝），去重置顶/上限 50/产物存在性过滤逻辑留在客户端 PhotoEditorHistory；photo_editor 进 migratedDomains（history.json 非媒体扩展名，assets 迁移白名单无影响）；3 项 SDK 测试（CRUD/旧数据兼容/损坏+封闭）。
- **顶层裸配置收编 configs 统一通道**：FloatingBallConfigManager 与 ActionStorage 主配置改走 system config 命令（key 沿用原文件名 floating_ball_config.json / action_config.json）；AboutmeDataService.migrateTopLevelConfig 一次性迁移 helper（configs 已有值或顶层无旧文件为 no-op，内存 Set 去重避免重复远端调用，失败静默下次重试，顶层路径不受封闭、deletePath 删旧合法）；action_config_backups/ 快照目录维持文件层（顶层不封闭，备份为快照非设置）；ActionStorage 的 backup/restore 改经 getConfig→jsonEncode / jsonDecode→setConfig 保持闭环。
- **capabilities protectedPrefixes**：LegacyWritePolicy.protectedPrefixes（assets/asset_references/stickers/sdk_migrations/.sdk/configs）对外声明；admin FilesTab 的预判消费留 macOS 侧 admin-vue（当前 catch 426 兜底已可用）。
- **文件层 API 最终定位明确**：写通道已全封闭（27+1 域 + configs 前缀），剩余调用面全部为合法保留（script_loader/agent_assets/moments/ai_image 迁移读旧删旧、备份快照、existsPath 读判断）；物理删除 API 仅待迁移代码退役后进行。
- **验证**：SDK 214 项全过（+3 photo_editor）、dart analyze 无 issue；server 37 全过；flutter analyze lib 无 error（14 项历史 lint 不变）。

## 第五轮（2026-10-24）：G 阶段 configs 命令化 + 原始文件更新全封闭 + 迁移恢复演练

- **system 域 configs 设置命令化（全部插件设置的统一通道）**：system 域新增 getConfig/setConfig/deleteConfig 三命令（handlers/system.dart），借 'configs' 分区对顶层 configs/ 前缀**原地读写**（与 database 借 'databases' 分区同一惯例），磁盘布局与字节格式不变——存量数据零迁移零搬家。路由 GET/PUT/DELETE /system/config，key 含 '/'（如 bill/settings.json）不走 `:param` 路径参数（多段编码歧义），GET 经 query（json-v1 编码）、PUT/DELETE 经 body。key 白名单校验（字符集 + 禁穿越 + 允许无扩展名存量键 scripts_center_installed_scripts）。
- **configs/ 前缀全封闭（原始文件更新全封闭验收收尾）**：LegacyWritePolicy._protectedRoots 加入 'configs'。原始 writePath/deletePath/clearPathPrefix 与 server deleteRawFile/clearRawFiles 一律 426；system 命令与全部读 API（readPath/listPathKeys/existsPath）不受限。
- **Flutter 侧 configs 写入面 7 类全部收口**（改走 AboutmeDataService.getConfig/setConfig/deleteConfig 薄封装）：ConfigManager（app_config.json + 插件 settings 读写删）、PluginBase.loadSettings/saveSettings（全部插件设置统一入口）、bill_plugin（重写删除回归基类，还获得补默认键能力）、webview app_store_manager（商城源 List + 当前源 ID 字符串字面量）、photo_editor ai_edit_config、plugin_manager 合并配置、route_history（顺带删除 412 冲突重试——命令事务写无文件层版本冲突）。script_loader 的 scripts_center 迁移删旧（configs/scripts_center* 4 处）改走 deleteConfig 命令（原始 deletePath 已被封闭拦截）。
- **迁移恢复演练**：test/system_config_test.dart 新增 5 项——configs 命令 CRUD + 磁盘旧数据原地可读（零迁移兼容证明）+ key 校验 + 封闭验收（原始写 426/命令与读不受限）+ todo 域端到端演练（旧布局磁盘注入 → 迁移前可读 → migrate 清单落盘 → 原始写 426 → update 后 restoreBackup 恢复迁移时快照）。
- **验收基线**：SDK `dart test --concurrency=1` **211 项全过**（206 + 5）、`dart analyze` 无 issue；server `dart test` 37 全过；`flutter analyze lib` 无 error（14 项历史 lint 均在未触碰文件）；全仓 grep configs/ 字面量仅剩 script_loader 迁移读（合法）与路径助手。
- **文件层 API 删除前置进展**：system configs 前置 ✓ 已完成；剩 photo_editor 建域（photo_editor/history.json 与 ai_edit_config 的域归属，configs 部分已收口）。

## 第四轮（2026-10-24）：运行时修复 + G 阶段小项 + 小尾巴清零

- **认证层并发治理（修复 handoff 记录的既有并发 UNAUTHORIZED）**：AuthStore verifyApiKey 并发回写 lastUsedAt 与读侧交错致 api_keys JSON 读半 → 误判 401。加进程内互斥锁 + tmp+rename 原子写；users.json（register/login/registerDevice/deleteDevice/addUser/updateUser）同套治理（锁内原语防重入死锁）；api_keys/users 数据损坏由静默空表改为显式 StorageException(invalidData)；+3 项并发回归测试（对照组验证有效性——去锁即失败）。附带修复：webview 商场 readPath as String? 类型崩溃（SDK 缺省 {} 契约）与写读不对称；路由历史 412（客户端未持版本时 If-None-Match:* 撞已存在文件，_saveHistory 冲突时读刷新重试）。
- **B 阶段关闭**：用户拍板（2026-10-23 口头 + 2026-10-24 复核），B 行更新为已完成。
- **G 阶段小项**：ImagePickerDialog saveDirectory 死参数删除（定义 + 24 处调用 + 表单 extra 链，avatar/video 活参数保留）；openai uninstall deletePath 残留清除；文件层 API 调用面调查（结论：photo_editor 未建域 + configs 设置生态依赖文件层，删除前置未满足）；SDK 拆 flutter 变体包评估（结论：不拆）。
- **小尾巴清零**：chat 旧贴图迁移（migrateLegacyStickers 命令 + assets 提取 migrateLegacyAssetToResource + Flutter 幂等触发，测试含中断恢复）；sweep 本数据区 count=0（macOS 侧数据区可再跑）；store 全部单行命令化（create/update/delete/archive/restore 五切）；分块上传封装（AssetsFacade.uploadChunked + SdkMediaService 自动路由）。
- **验证**：SDK 206 全过、server 37 全过、flutter analyze lib 无 error、dart analyze 无 issue。

## 记录域迁移（todo/tracker）测试已完成

更新时间：2026-10-23。

- `test/record_domains_migration_test.dart` 3 项测试全部通过：首次写入后全量迁移与幂等、孤儿 record 拒绝迁移且不写清单、备份恢复当前快照。
- `migrations/record_domains_migration.dart`：首次成功写入后再做全量快照与校验（写入前预检会导致 addRecord 误拒孤儿记录）；`getMigrationReport` 始终校验当前数据（孤儿 record 即使在清单已写入后也会被发现），清单损坏时抛 `CORRUPT_DATA`。
- `handlers/tracker.dart` `addRecord`：孤儿 record（goalId 不存在的目标）允许写入、跳过 goal 进度更新，由迁移快照校验以 `CORRUPT_DATA` 拒绝；移除了 goal 存在性前置外键校验。
- `route_config.dart` 已为 todo/tracker 增加 `migrate`、`restoreBackup`、`exportData` 路由。
- 验证：`dart test --concurrency=1` 全量 93 项通过；`dart analyze` 无问题。


## 已验证的基础能力

### 2026-10-23 第二轮（C/D 收尾 + F-P2/P3 小域）

- **C 阶段完成**：agent_chat 外围配置 17 个 SDK 命令（tools 5 + templates 3 + message_details 3 + route_agent_configs 2 + test_runs 2 + preferences 2），保持原文件布局与磁盘格式兼容（旧缩进 JSON 文本可读；旧 suggested_questions_last_category 裸文本读取返回 CORRUPT_DATA，客户端按无配置兜底、首次 setPreference 覆盖修复——与旧 readPathText 失败即 null 语义一致）。Flutter 侧 7 文件收口（tool_config_manager 19 处、tool_template_service、message_detail_service、route_agent_config_service、message_input、suggested_questions_dialog、suggested_question_test_dialog）。agent_chat 入 migratedDomains。
- **D 阶段完成**：activity 设置 4 命令（getNotificationSettings/updateNotificationSettings/getTtsSettings/updateTtsSettings，合并语义），Flutter activity_plugin（含额外发现的 3 处残留）与 tts_announcement_settings 收口。activity 入 migratedDomains。tracker goal_images 确认已资源化（saveDirectory 为死参数，媒体全走 SdkMediaService）。store 按行提交为非阻塞优化未做。
- **F-P2 完成**：SDK 新增 system 域（服务器全局配置），server SystemApi 改走 SDK 命令；启动时 dataDir 顶层 plugin_registry.json/store_config.json 一次性搬入 system/ 分区（幂等，集成测试验证）。service-account.json 保持本地 File（部署凭证，避免进入数据区备份/导出）。
- **F-P3 小域完成**：timer/achievement/reminder/live2d/tts 五域统一单文件快照域（handlers/snapshot_domain.dart，getSnapshot/saveSnapshot，listKeys 类型校验），timer 从通用 CRUD 移出（原 items.json 布局从未被 Flutter 使用，属死代码），plugin_mcp 测试同步更新。五域 Flutter 收口 + 入 migratedDomains。
- **migratedDomains 扩至 24 域**（新增 agent_chat、activity、timer、achievement、reminder、live2d、tts、webview）。全仓 grep 确认七域前缀 Flutter 零残留直写；AgentFileSpaceService（agent_files/、agent_chat_files/ dart:io 独立空间）与 ConfigManager（configs/ 前缀）不受封闭影响。
- **验证**：SDK `dart test --concurrency=1` 全量最终 **188 项通过**（+8 agent_chat 外围、+2 activity 设置、+2 system、+5 快照域、+3 webview、+5 openai、+7 toolbox 等）、`dart analyze` 无问题；全部收口域 `flutter analyze` 通过（agent_chat/activity/timer/achievement/reminder/live2d/tts/webview/openai/toolbox）；server 测试债已清（36 过 1 失败，失败为 HEAD 既有）。
- **F-P3 第二波**：webview（9 命令 + 3 文件收口 + 封闭，第 24 个封闭域）；openai（25 命令薄文件层 + 26 路由 + 5 组测试 + 10 文件 54 处收口，uninstall 保留文件层，域不封闭）；toolbox（10 命令 + 2 文件 17 处收口，含旧 scripts_center 脚本配置迁移逻辑进命令，域不封闭——PNG 二进制产物仍走 writeBytes 文件层）。openai/toolbox 不封闭原因：域内二进制（头像/帖图/生图 PNG）经 writeBytes 写入而 writeBytes 同受 LegacyWritePolicy 拦截，封闭即断功能，需等 F-P1 资源迁移。
- **server 测试债清理**：plugin_mcp 跨通路用例改为"业务命令写→文件层读→MCP 修改→落盘一致"（原文件层直写已被封闭取代）；server_integration 两用例与 remote 落盘用例的 todo/ 写入改为未封闭 misc/ 前缀；timer 通用 CRUD 用例改快照域。server 全量 36 过 1 失败——唯一失败"两个 SDK HTTP 客户端与 MCP 并发追加"为 HEAD 上即失败的既有 UNAUTHORIZED 问题（已用干净 worktree 验证），与本轮改动无关。
- **scripts_center 探明结论（未实现）**：40 处全在 scripts/、configs/ 跨分区（scripts/<id>/metadata.json + script.js 裸文本、configs/scripts_center/* 配置与执行日志、configs/scripts_center_installed_scripts 无扩展名、scripts/index.json 仅 Web）；前置问题三个：数据迁入 scripts_center/ 分区、script.js 文本通道（裸 String 或 JSON 包装迁移）、dart:io 目录扫描/递归删除的 handler 等价能力。设计分组：scripts（list/getMeta/saveMeta/getCode/saveCode/create/delete/exists/syncBuiltin）、scriptConfig（get/set/delete）、execLog（list/record/clear，滚动 200 上移 handler）、store（sources/installed）。

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
