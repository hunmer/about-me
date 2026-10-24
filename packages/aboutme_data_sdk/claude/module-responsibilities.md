# 模块职责

> 所属：packages/aboutme_data_sdk · [返回索引](../CLAUDE.md)

## handlers/ 分组（33 文件）

| 分组 | 文件 | 职责 |
| --- | --- | --- |
| 记录域（记录集合 + 迁移命令） | activity、bill、calendar、calendar_album、checkin、contact、day、diary、goods、habits、media_log、nodes、notes、todo、tracker | 各域 CRUD/业务命令；migrate/restoreBackup/exportData；首写后快照 |
| 单文件快照域（共用 snapshot_domain） | snapshot_domain.dart | timer/achievement/reminder/live2d/tts 五域的 getSnapshot/saveSnapshot/listKeys |
| 薄文件层域 | agent_chat、openai、webview、scripts_center、toolbox、photo_editor | 客户端逻辑不上移，整文件读写命令（photo_editor 为 2026-10-24 第六轮新增的第 28 封闭域） |
| 特殊域 | chat（+chat_support）、chat_stickers、store、database | chat 消息/频道与支撑；贴图集合 + migrateLegacyStickers；store 含按行命令（createProductRow/updateProductRow/deleteProductRow，排序保留整表）；database 含数据搬家 |
| 全局域 | system、assets | system：getConfig/setConfig/deleteConfig（configs/ 前缀唯一写入口，落盘原位）；assets：资源化 + migrateLegacyAssets/sweep + 分块上传 |
| 共享支撑 | record_domain_support、structured_support、activity_time_segments | 记录域/结构化域公共逻辑；activity 时段拆分 |

## services/ 关键模块

| 文件 | 职责 |
| --- | --- |
| aboutme_data.dart | 客户端唯一入口（local/remote 自动路由、events 事件流） |
| route_config.dart | 全部业务路由表（method+path → 域命令） |
| handler_factory.dart / invoker.dart | 域 handler 工厂与调用器 |
| crud.dart / query_store.dart | 通用 CRUD 与查询存储 |
| chat_facade / diary_facade / assets_facade | 高层门面（AssetsFacade 含 uploadChunked 分块上传封装） |
| asset_materialization*.dart / asset_references.dart / asset_media_type.dart | asset:// 资源物化（io/stub 条件导入）、引用计数、媒体类型 |
| capabilities.dart | capabilities 查询（含 protectedPrefixes，admin FilesTab 消费） |
| plugin_data.dart / local_plugin_backend*.dart / persistent_plugin_backend.dart / file_plugin_persistence.dart | 插件数据后端（本地/持久化/文件持久化） |
| data_config.dart | 数据目录等配置 |
| host_file_input*.dart | 宿主文件 IO 注入（依赖倒置点） |

## lib/src/ 存储层

| 文件 | 职责 |
| --- | --- |
| storage_interface.dart | 存储抽象（宿主转发实现） |
| data_store.dart / local_file_storage.dart | 数据区读写 / 服务端文件存储（认证/审计） |
| http_storage.dart | 远端 HTTP 存储后端（明文 + ETag 条件写） |
| auth_store.dart | API Key/users 存储（并发互斥锁 + 临时文件原子写，2026-10-24 修复） |
| jwt_hs256.dart / pbkdf2.dart | nodejs 认证兼容（JWT 签名 / PBKDF2） |
| legacy_write_policy.dart | **写封闭核心**：migratedDomains（28）+ _protectedRoots（configs/）→ 426 |
