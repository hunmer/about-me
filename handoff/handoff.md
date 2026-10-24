# 交接：统一数据 SDK 重构 —— C/D/E/F/G 全阶段完成（2026-10-24 第八轮兼容层移除）

**创建时间：** 2026-10-24（Asia/Shanghai）
**分支：** main（全部改动在工作区未提交，git status 约 80 个 M/?? 文件，属预期；不要 git commit）
**仓库：** /Users/Zhuanz/Documents/Aboutme（macOS，dart 3.13.5 / flutter 3.47.7；首次跑需 `dart pub get`）；第五~八轮在 Windows 工作区（D:\about-me）继续，改动同源
**总计划：** docs/unified_data_sdk_refactor_plan.md
**状态文档：** docs/unified_data_sdk_refactor_status.md（已同步至第八轮）

## 摘要

八轮波次推进，C/D/E/F/G 全部完成：
- C：agent_chat 外围 17 命令 + 7 文件收口 + 封闭
- D：activity 设置收口 + 封闭；tracker goal_images 确认已资源化
- F-P2：system 域（server 全局配置 SDK 化 + 启动迁移 + 集成测试）
- F-P3：8/8 域收口（timer/achievement/reminder/live2d/tts/webview/openai/toolbox/scripts_center）
- F-P1：migrateLegacyAssets + sweep + 分块上传（256MiB）+ capabilities v2 + removeLegacyAsset 二进制修复
- F-P4：FilesTab 426 引导 + 平台适配层评估结论
- G 五轮：system 域 configs 设置命令化 + Flutter 7 类写入面收口 + configs/ 全封闭 + 迁移恢复演练
- G 六轮：photo_editor 建域（第 28 封闭域）+ 顶层裸配置收编 + capabilities protectedPrefixes
- G 七轮：admin FilesTab 消费 protectedPrefixes + REST 远端链路实测
- **G 八轮**：迁移与只读兼容层移除（AboutmeDataService 文件层 API + 全部 Flutter 迁移代码删除，用户手动清空旧数据）

**最终基线（2026-10-24 第八轮）：SDK 214 项全过；`dart analyze` 无 issue；`flutter analyze lib` 无 error（14 项历史 lint）；server 38 全过；admin-vue `npx vue-tsc -b` 通过。**

## 当前封闭状态（migratedDomains 28 域 + configs 前缀，原始写一律 426）

diary、todo、tracker、notes、nodes、contact、day、calendar、checkin、habits、bill、goods、store、calendar_album、media_log、database、agent_chat、activity、timer、achievement、reminder、live2d、tts、webview、scripts_center、openai、toolbox、**photo_editor**。

**configs/ 前缀也已封闭**（在 _protectedRoots，非域）：唯一写入口 = system 域 config 命令。

读 API（SDK AboutmeData.readPath/listPathKeys/existsPath 等）不受封闭限制；SDK 各域内迁移 handler 与 migrateLegacyAssets/migrateLegacyStickers 命令保留为 dormant（Flutter 已不调用）。**Flutter 侧 AboutmeDataService 不再暴露任何文件层转发**（第八轮移除），历史等少量只读直达 `data`。

## system 域 configs 命令速查（第五轮新增）

- `getConfig {key}` → 返回 `{value}`（不存在 value=null；key 为 configs/ 下相对路径，如 `app_config.json`、`bill/settings.json`）
- `setConfig {key, value}` → 覆盖写（value 任意 JSON 值：Map/List/String）
- `deleteConfig {key}` → 返回 `{deleted}`
- 落盘 configs/ 前缀**原位**（借 'configs' 分区，零迁移）；key 白名单校验（禁穿越/反斜杠/空格，允许无扩展名存量键）
- REST：GET/PUT/DELETE /api/v1/plugins/system/config（key 含 '/' 不走路径参数；GET 走 query json-v1 编码）
- Flutter 薄封装：`AboutmeDataService.instance.getConfig/setConfig/deleteConfig`（失败抛 StateError，调用方按缺省语义兜底）

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

### 1. G 阶段（主体与收尾均完成，仅剩可选项）
- ~~删除兼容层小项~~ **已完成（2026-10-24 第四轮）**：ImagePickerDialog 的 saveDirectory 死参数全链删除（24 文件，avatar/video picker 活参数保留）；openai_plugin uninstall 的 deletePath try-catch 残留清除（卸载保留数据分区）。
- ~~system 域 configs 设置命令化~~ **已完成（2026-10-24 第五轮）**：三命令 + configs/ 全封闭 + Flutter 7 类写入面收口（ConfigManager/PluginBase/bill/webview 商场源/photo_editor ai_edit_config/plugin_manager/route_history）+ script_loader 删旧改命令 + 演练测试。
- ~~原始文件更新全封闭验收 + 迁移恢复演练~~ **已完成（2026-10-24 第五轮）**：configs 进 _protectedRoots；test/system_config_test.dart 演练（旧布局注入→迁移→426→restoreBackup 恢复）。
- ~~photo_editor 建域~~ **已完成（2026-10-24 第六轮）**：getHistory/saveHistory/clearHistory 薄文件层命令 + Flutter PhotoEditorHistory 收口 + 封闭（第 28 域）+ 3 项测试。
- ~~顶层裸配置收编~~ **已完成（2026-10-24 第六轮）**：floating_ball_config / action_config 主配置走 system 命令（key 沿用原文件名），migrateTopLevelConfig 幂等迁移（读旧→写新→删旧，内存去重）；action_config_backups/ 快照目录留文件层顶层。
- ~~capabilities protectedPrefixes~~ **已完成（2026-10-24 第六轮 SDK 侧 + 第七轮 admin 消费）**：admin-vue 在 **packages/aboutme_server/admin-vue**（非仓库根）；api/index.ts fetchProtectedPrefixes/isProtectedPath，FilesTab guardMigratedDelete 双检查（域 + 保护前缀），vue-tsc 通过。
- ~~REST 远端链路 config 命令实测~~ **已完成（2026-10-24 第七轮）**：server test/aboutme_data_remote_test.dart 真实 Shelf server 端到端（斜杠 key query json-v1 编码、PUT/DELETE body、users/&lt;id&gt;/configs/ 落盘、426、capabilities）。注意：**server 业务命令按认证用户隔离落盘 users/&lt;id&gt;/**，测试断言路径勿用 dataDir 根。
- ~~AboutmeDataService 文件层 API~~ **已删除（2026-10-24 第八轮，用户决策：手动清空旧数据，不需要迁移兼容层）**：readPath/writePath/existsPath/listPathKeys 等全部转发方法 + migrateTopLevelConfig 移除；Flutter 侧 6 处一次性迁移代码全删（script_loader 搬家/moments 旧图/agent_assets 路径/ai_image 旧 PNG/openai 头像引用/chat 贴图触发）；运行时读判断（ai_image/photo_editor 历史存在性过滤）改 `data.existsPath` 直达。SDK 侧文件层 API 与迁移命令保留为 dormant（服务端/管理后台依赖，契约与测试不变）。**注意：旧数据区的旧格式引用不再被程序迁移，直接失效（顶层裸配置/旧图/旧贴图等需手动清空或接受失效）**。
- ~~SDK 拆 flutter 变体包~~ **评估结论（2026-10-24）：不拆**。SDK 已零 Flutter 依赖（纯 Dart，依赖仅 shared_models/crypto/encrypt/http/path/pointycastle/uuid），宿主 storage_interface 转发已就位，"SDK 契约 + 宿主实现"依赖倒置已成立；物理拆包无架构收益，仅结构搬家徒增版本同步成本。

### 2. B 阶段状态确认
**已完成（2026-10-24）**：用户拍板关闭，状态文档 B 行已更新（残余外围项转小尾巴跟踪）。

### 3. 记录在案的小尾巴
- ~~chat 旧贴图二进制批量迁移入口~~ **已完成（2026-10-24 第四轮）**：chat_stickers 新增 `migrateLegacyStickers` 命令（dryRun 默认；注册表驱动 stickers/ 旧引用 → asset://，复用 assets 迁移记录幂等，中断重跑安全，迁后删旧，save 维护引用索引）；assets.dart 提取公开函数 `migrateLegacyAssetToResource`；REST POST /chat/sticker-collections/migrate-legacy；Flutter StickerService.migrateLegacyStickers 由 chat 插件 initialize 幂等触发。SDK 测试覆盖 dryRun/执行/共享贴图/幂等/中断恢复。
- 孤立旧文件回收：**本数据区（Windows）无可回收**——`toolbox/` 分区不存在、`openai/agents` 为空目录（已删）；sweep dryRun count=0。macOS 侧数据区如需回收可跑 `sweep {dryRun:true}` 确认后执行。
- ~~store 整表 save* 按行提交~~ **已完成（2026-10-24 第四轮）**：archive/restore/create/update/delete 全部切 SDK 单行命令（新增 createProductRow/updateProductRow/deleteProductRow），排序保留整表（顺序为整表属性）。
- ~~server 并发用例 UNAUTHORIZED 既有 bug~~ **已修复（2026-10-24）**：根因为 AuthStore.verifyApiKey 并发回写 lastUsedAt 时读侧命中写了一半的 api_keys JSON（容错返回空表 → 误判 401）。已加进程内互斥锁 + 临时文件原子写；users.json（login 设备登记/注册）同步治理；api_keys/users 数据损坏由静默空表改为显式 StorageException(invalidData)。`aboutme_data_remote_test` 并发用例现通过。
- ~~分块上传的 Flutter 端封装~~ **已完成（2026-10-24 第四轮）**：AssetsFacade 新增 `uploadChunked`（init→append×N→complete 端到端 sha256、onProgress 回调、256MiB 上限）；SdkMediaService.uploadBytes >16MiB 自动路由分块；SDK 测试覆盖。

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
dart test --concurrency=1          # 基线 214 全绿
dart analyze                       # 须无 issue
cd ../aboutme_server && dart analyze && dart test   # 38 全过
cd admin-vue && npx vue-tsc -b     # 通过（packages/aboutme_server/admin-vue）
cd /Users/Zhuanz/Documents/Aboutme && flutter analyze lib   # 无 error（14 项历史 lint）
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
