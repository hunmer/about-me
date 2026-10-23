# 统一数据 SDK 协议 v1

本文件记录已落地的基础协议；完整改造范围仍以 `unified_data_sdk_refactor_plan.md` 为准，阶段状态见 `unified_data_sdk_refactor_status.md`。

## 边界与初始化

依赖方向为 Flutter/Server → aboutme_data_sdk → shared_models。shared_models 不导入 Flutter、SDK 或持久化实现。业务处理器只能访问 SDK 内部的 PluginData；平台文件访问限于 PluginPersistence 实现。应用文件兼容方法仅用于待迁移业务域，不能用于新增业务功能。

`AboutmeData.open(DataConfig.local(storage: adapter))` 接入本机或 Web 持久化；`DataConfig.http(serverUrl: ..., credentialProvider: ...)` 使用 HTTP。`session` 明确返回模式、连接状态、认证用户和能力。HTTP 不可用时保持 HTTP 模式，不写另一份本地数据。直接使用同步 remote 工厂时，连接状态为 unverified，不能据构造成功认定在线。

SDK 实例绑定数据源和凭据。更换后端/账号必须销毁旧实例、取消旧订阅，再创建新实例；旧实例的在途响应不能写入新实例缓存。宿主的完整切换与各插件展示快照清理由后续迁移统一接入，不允许只切换 WS。

当前配置页采用重启后统一切换：测试连接不会修改活动 WS，保存也不会只替换 WS。本次会话仍使用原数据源，重启后 HTTP/SDK/WS 一起读取新配置；尚未实现进程内全量热切换。

## 动作与传输

动作定义来自 SDK `route_config.dart`；定义包含 actionId、HTTP method/path、resource、capabilityVersion、请求/响应模型和用户数据权限。`GET /api/v1/plugins/capabilities` 在认证后返回该表及已完成迁移的业务域。通用 CRUD 路由不代表对应插件已完成模型适配；只有 migratedDomains 才表示已收口。

local SDK、HTTP SDK、REST、MCP 通过 PluginInvoker 执行相同处理器。MCP 的 `aboutme_data_call` 接收 pluginId、action、params，返回完整结果；`aboutme_data_capabilities` 返回同一能力表。旧工具名称继续兼容，逐域核对后删除重复映射。

业务请求保留 GET/POST/PUT/PATCH/DELETE。GET 使用 `X-Aboutme-Query-Encoding: json-v1`，各参数分别 JSON 编码，因此字符串 `001`、null、列表、对象和布尔值不会混淆；DateTime 编码为 UTC ISO 时间。直接 REST 的普通查询字符串仅按已声明的分页/布尔参数解码，其余保持字符串。DELETE 参数在 JSON 请求体。路径参数由路由决定，query/body 与路径身份冲突时返回 400。

响应为 `{success, data?, error?, code?, timestamp, version?, mutationId?}`。HTTP 非成功状态先映射类型错误，业务门面再映射相同业务失败码。错误码包括 NOT_FOUND、INVALID_PARAMS、CONFLICT、UNAUTHORIZED、FORBIDDEN、OFFLINE、CORRUPT_DATA、UNSUPPORTED 和 INTERNAL_ERROR。损坏 JSON 不当作空文件。网络写入不自动重试，文件 CAS 冲突也不刷新版本重放或强写。

## 事务与并发

当前明确约束为**单服务进程**：同一数据目录只能由这一进程的 SDK runtime 协调写入；不支持未协调的外部脚本、旧文件写入或第二个进程/副本。需要多进程时先迁移事务数据库或跨进程锁。

所有 backend 实例按规范化数据目录共享队列。业务查询同样先取得锁并恢复未完成提交，再执行处理器。命令写入先在内存暂存；校验失败丢弃全部写入。单文件在同目录写临时文件并原子替换，多文件通过 `.sdk/pending.json` 持久提交决定，再按顺序重放，最后移除日志。中断后下一次 SDK 操作先向前完成日志；因此该日志落盘后的不确定请求必须查询或重放相同 mutationId，不能换 ID 重试。

`.sdk/state.json` 的版本与幂等结果和业务文件属于同一提交。当前 `expectedVersion` 是插件业务域版本，属于保守冲突检测；不同实体写入也可能导致冲突，调用方须重查。成功命令返回 version。`clientMutationId` 按插件＋动作隔离，记录持久化保留 30 天；相同 ID/参数返回同一结果，不同参数返回 CONFLICT。30 天后不保证旧 ID 重放去重。

提交完毕才发布一个资源级事件，字段包括 pluginId/resource/entityId/action/version/mutationId/sourceDeviceId。同目录的本地 SDK 实例共享提交事件。恢复完成会发布 recovery 来源的失效事件。普通 Storage API 不可读写或清除 SDK 内部日志/状态。

服务端 UserDataRuntimes 以认证 userId 绑定 backend，REST/MCP 共享注册表。请求 source/sourceDeviceId 放在 Zone 上下文中，避免复用实例时并发请求互相覆盖来源字段。

## 查询与订阅

业务 GET 默认重新验证权威数据，仅同查询的在途请求合并；显式 cacheOnly 才读取旧快照。查询键包含 SDK 实例身份、插件、动作、规范化参数。SDK 实例拥有独立缓存，快照和参数均拷贝，外部修改不污染缓存。

watch 为每个订阅者维护独立生命周期，提供 loading/data/error/stale 状态。取消一个订阅不取消另一个。请求中发生失效时丢弃旧响应并重查，防止慢响应覆盖新结果。HTTP 命令成功主动失效，不依赖本机 WS 回声；WS 只表示资源失效。重连和应用恢复前台调用 revalidate，重查活跃资源。错误状态保留旧快照供展示，但不得当作最新状态。

## Chat 首批契约

ChatCodec 以 title、date、user 作为规范字段，兼容 name、createdAt、senderId/senderName，保留未知字段、metadata、附件与回复 ID。shared_models DTO 往返保留扩展字段。新发送由处理器确定时间，保留客户端稳定消息 ID，更新消息集合、频道摘要和数量。重复频道/消息 ID 返回冲突，封存频道拒绝新消息。

`data.chat.sendMessage(SendMessageCommand(...))`、`listMessages(channelId, limit, before)`、`watchMessages(...)` 复用动作表。游标为 UTC 时间与唯一 ID 组合；同毫秒消息不会漏页。频道列表只读取频道摘要，不预读所有消息。

## Diary 契约、迁移与旧写封闭

日期固定 YYYY-MM-DD；兼容旧 ISO 日期、Delta 富文本和未知扩展字段。save/update 只提交变更字段，索引和总字数由处理器同事务维护。`data.diary.getEntry` 在不存在时仍返回可用于创建的版本，列表返回真实 total/hasMore；删除接受 expectedVersion。

每次 Diary 非查询命令先检查迁移状态。首次成功命令备份整个 Diary JSON 域到 `sdk_migrations/diary/v1_backup.json`，规范化日期/富文本、补齐漏索引实体并重建统计；命令失败时迁移也回滚。`v1.json` 保存实体数、日期 ID 集合、逐文件 SHA256 和规范化校验结果。备份保存 JSON 语义内容，原始排版空白不属于校验范围。损坏数据、缺失引用和未来 schema 阻止迁移。

`POST /diary/migration` 显式迁移，`GET /diary/migration` 查询报告；这里及以下路径均相对 `/api/v1/plugins`。`GET /diary/export` 导出；`POST /diary/import` 接受 schemaVersion=1、最多 100 篇的批次，已有日期跳过，非法批次不部分提交。

恢复仅在 SDK IO 维护 API 提供：在 backend.execute 的 `diary.restoreMigrationBackup` 事务中调用 `restoreDiaryMigrationBackup`。恢复前写 `before_restore.json`，校验备份后恢复旧 JSON 并删除迁移标记，可再次安全迁移。普通 REST/MCP 不提供任意恢复动作。

capabilities.migratedDomains 当前只有 diary。普通原始文件 PUT/DELETE/前缀清除不能修改 diary、SDK 内部状态、迁移日志、assets、asset_references 或贴图注册表 `stickers/collections.json`；force 和父前缀不能绕过，服务端返回 426 / UPGRADE_REQUIRED。assets 与贴图注册表单独列入 protectedResources，不代表整个 Chat 已完成迁移。

## 资源与贴图合集

`data.assets.upload/read/getMetadata/remove` 使用稳定 UUID ID，持久化引用为 `asset://ID`。上传只接受 content（base64）、fileName、mediaType 与通用命令元数据；不接受任意目标路径。资源不可原位覆盖，编辑必须产生新 ID。文件名仅用于展示与临时文件扩展名，不能决定业务存储路径。

资源首版上限 16 MiB；REST 和 MCP 的 JSON 请求体均在读取流时限制为 24 MiB，超限返回 413。assets.list 支持按 mediaType 前缀过滤和 offset/limit 分页（单页最多 100），读取 assets/index.json 元数据索引，不加载资源内容；列表按时间与 ID 稳定排序。capabilities.assets 声明编码和大小。内容与描述一起走持久化事务，读取时验证字节数和 SHA256，损坏明确返回 CORRUPT_DATA。上传重放相同 clientMutationId 返回原资源；使用不同内容重放同 ID 返回 CONFLICT。

`assets.materialize` 在原生平台返回临时句柄，调用方负责 dispose；`resolvePath` 为仍需要同步路径的播放器提供会话缓存，在 SDK dispose 时释放。宿主选择器的绝对路径仅通过本机 importSelectedFile/readSelectedFile 读取，HTTP 请求不携带本机路径。Web 读取字节与图片显示可用，文件路径物化返回 unsupported。

Chat 贴图合集使用 getStickerCollections/createStickerCollection/renameStickerCollection/addStickers/removeSticker/deleteStickerCollection。新贴图上传资源后提交引用，处理器在锁内读取最新注册表并更新，不接受客户端整表覆盖。首次修改在同事务中备份旧注册表到 `sdk_migrations/chat_stickers/v1_backup.json`，登记 ID/数量/checksum。未知扩展字段保留。

合集和消息的附件引用与 `asset_references` 索引同事务更新；有引用时 remove 返回 CONFLICT。移除合集/消息只释放相应引用，不直接删除共享资源。资源回收和 Chat 全量旧资源迁移仍在实施。受控 readLegacySticker 仅允许旧 stickers 目录图片的只读访问，拒绝路径穿越与业务 JSON；不提供任意路径上传/改写。

## 架构基线

`data_access_inventory.json` 用 Dart AST 记录候选调用、所有插件源文件入口角色和动作覆盖；原生/后台入口额外按语法线索记录。候选不等于已确认违规，needs-review 不能视为已审查。检查按文件＋调用语法计数，新增候选直接失败；存量逐域审查清零后再移除兼容导出。

在仓库根目录运行：

```powershell
dart --packages="packages/aboutme_data_sdk/.dart_tool/package_config.json" "tool/data_access_inventory.dart"
```

`--write` 用于审查后更新基线，不应在 CI 自动调用。工具使用独立 SDK 环境，避免触发 Flutter 音频原生构建钩子。
