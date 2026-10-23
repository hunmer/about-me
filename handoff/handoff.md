# 交接：统一数据 SDK 重构 —— C/D/E/F 四阶段完成，G 阶段待启动

**创建时间：** 2026-10-24（Asia/Shanghai）
**分支：** main（全部改动在工作区未提交，git status 约 75 个 M/?? 文件，属预期；不要 git commit）
**仓库：** /Users/Zhuanz/Documents/Aboutme（macOS，dart 3.13.5 / flutter 3.47.7；首次跑需 `dart pub get`）
**总计划：** docs/unified_data_sdk_refactor_plan.md
**状态文档：** docs/unified_data_sdk_refactor_status.md（已同步至最新，含第二、三轮记录段）

## 摘要

三轮 subagent 波次推进，handoff 剩余任务（C/D/E/F 四阶段）全部实质完成：
- C：agent_chat 外围 17 命令 + 7 文件收口 + 封闭
- D：activity 设置收口 + 封闭；tracker goal_images 确认已资源化
- F-P2：system 域（server 全局配置 SDK 化 + 启动迁移 + 集成测试）
- F-P3：8/8 域收口（timer/achievement/reminder/live2d/tts/webview/openai/toolbox/scripts_center）
- F-P1：migrateLegacyAssets + sweep + 分块上传（256MiB）+ capabilities v2 + removeLegacyAsset 二进制修复
- F-P4：FilesTab 426 引导 + 平台适配层评估结论

**最终基线：`cd packages/aboutme_data_sdk && dart test --concurrency=1` → 201 项全过；`dart analyze` 无 issue；`flutter analyze lib/plugins` 无 error（13 项历史 lint 在未触碰文件）；admin-vue `npx vue-tsc -b` 通过；server 36 过 1 失败（HEAD 既有的并发 UNAUTHORIZED，用干净 worktree 验证过与本轮无关）。**

## 当前封闭状态（migratedDomains 共 27 域，原始写一律 426）

diary、todo、tracker、notes、nodes、contact、day、calendar、checkin、habits、bill、goods、store、calendar_album、media_log、database、agent_chat、activity、timer、achievement、reminder、live2d、tts、webview、scripts_center、openai、toolbox。

读操作（readPath/listPathKeys/existsPath/readPathText）不受封闭限制，迁移代码读旧删旧合法。

## 各域实现模式（新会话可参照）

| 模式 | 参照 | 适用 |
| --- | --- | --- |
| 记录域迁移（migrate/restoreBackup/exportData、首写后快照、孤儿/损坏 CORRUPT_DATA 拒绝） | migrations/record_domains_migration.dart + handlers/tracker.dart | 记录集合域 |
| 单文件快照域（getSnapshot/saveSnapshot + listKeys 类型校验） | handlers/snapshot_domain.dart | timer/achievement/reminder/live2d/tts |
| 薄文件层命令（客户端逻辑不上移，整文件读写） | handlers/agent_chat.dart 外围段、handlers/openai.dart | 有全量缓存+保存链的域 |
| 跨分区一次性迁移（Flutter 侧 listPathKeys 读旧→写命令→deletePath 删旧，幂等） | lib/plugins/scripts_center/services/script_loader.dart 的 migrateLegacyPartition | scripts/configs 等旧布局 |
| 媒体资源化（新写走 SdkMediaService 存 asset://，旧图经 migrateLegacyAssets 批量迁移） | lib/plugins/openai/moments、lib/plugins/toolbox/services/ai_image_service.dart | 含二进制的域 |
| 数据搬家（事务内读旧→写新→删旧） | handlers/database.dart + plugin_data.dart 的 removeLegacyAsset | 顶层旧文件 |

## 剩余任务（按优先级）

### 1. G 阶段（最后阶段，建议专门会话）
- 删除兼容层：AboutmeDataService 的文件层 API（readPath/writePath 等，lib/core/data/aboutme_data_service.dart:81-95）仅供迁移代码使用，全部迁移完成后收口；ImagePickerDialog 的 saveDirectory 死参数；openai_plugin uninstall 的 deletePath try-catch 残留。
- 原始文件更新全封闭验收 + 迁移恢复演练。
- SDK 拆 flutter 变体包（mobile_storage/web_storage 物理收编——当前"SDK 契约 + 宿主实现"依赖倒置已成立，物理拆包是包结构级改动）。

### 2. B 阶段状态确认（需用户拍板）
状态文档 B 行仍列 Chat/Diary 退出条件；用户 2026-10-23 已口头确认"已经完成"。请用户最终拍板后更新 B 行状态。

### 3. 记录在案的小尾巴
- chat 旧贴图二进制批量迁移入口待接（readLegacySticker 与 migrateLegacyAssets 通道均已有，接入需结合 chat_stickers 贴图注册表事务设计；注意用户已确认 chat 域完成，动前先确认）。
- 孤立旧文件回收：`toolbox/image_search/`、`openai/agents/` 无引用者，可调 `assets sweep`（dryRun 先行）。
- store 整表 save* 按行提交（非阻塞优化）。
- server 并发用例 UNAUTHORIZED 既有 bug（aboutme_data_remote_test"两个 SDK HTTP 客户端与 MCP 并发追加"，HEAD 可复现）——排查认证层竞态。
- 分块上传的 Flutter 端封装（SdkMediaService 目前只封了单次 upload；>16MiB 场景接 init/append/complete）。

## F-P1 资源命令速查（SDK 已实现，test/assets_migration_sweep_test.dart）
- `migrateLegacyAssets {items:[{sourcePath,fileName?,mediaType?}]}`：白名单（27 域 + stickers 前缀 + 媒体扩展名）批量迁移，legacy_migration.json 幂等，迁后删旧，单次 50 项分批。
- `sweep {dryRun=true, minAgeHours=24}`：引用=0 回收。
- `initUpload {fileName,mediaType,size,sha256?}` / `appendChunk {uploadId,index,content}` / `completeUpload {uploadId}`：8MiB/块、总 256MiB、24h 暂存 GC。

## 共享文件（多 agent 并行时的冲突点）
- packages/aboutme_data_sdk/lib/src/services/route_config.dart（各域段；静态路由先于参数路由；PUT /xxx/:id 类路由的 handler 必须从 params 取同名路径参数键）
- …/handler_factory.dart（各域 case）
- …/legacy_write_policy.dart（migratedDomains；**必须在该域 Flutter 零残留直写后才能加**，加完跑全量测试）
- lib/src/services/aboutme_data.dart（兼容层 API）

## 验证命令
```bash
cd packages/aboutme_data_sdk
dart test --concurrency=1          # 基线 201 全绿
dart analyze                       # 须无 issue
cd ../aboutme_server && dart analyze && dart test   # 36 过 1 失败（既有）
cd ../admin-vue && npx vue-tsc -b  # 通过
cd /Users/Zhuanz/Documents/Aboutme && flutter analyze lib/plugins/<域>
```

## 注意事项
- 测试里构造损坏/遗留数据用磁盘 File 直写注入（照 test/checkin_migration_test.dart 的 inject 模式）。
- handler 内部 data.read/write 不受 LegacyWritePolicy 限制；writeBytes/writeFile/writePath/deletePath/clearPathPrefix 均受 426 拦截，读 API 不受限。
- data.get/call 返回完整响应 {success, data, error, code}，取值先判 success。
- `_TransactionData` 事务内任何 read 抛过 StorageException 都会被提交层重放（handler 内 catch 无效，见 agent_chat getPreference 注释）。
- subagent 并行时勿同时改 SDK 共享文件；subagent 中途网络故障中断时先检查其遗留文件完整度再接手（本轮 scripts_center 即如此救回）。
- 做微小的代码修改不需要每次都 build；本仓库不涉及 mira-app-core。

## Suggested skills
- 无强制依赖。若下轮启动 G 阶段，建议先用 planning-with-files 建任务清单（删兼容层影响面大，需逐域回归）。
