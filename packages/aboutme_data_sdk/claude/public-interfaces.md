# 对外接口

> 所属：packages/aboutme_data_sdk · [返回索引](../CLAUDE.md)

## AboutmeData（客户端唯一入口）

```dart
// 文件层（28 域 + configs/ 前缀的写被 426 拦截；读不受限）
await data.writeFile(pluginId, file, value);
final file = await data.readFile(pluginId, file);

// 业务层（与 REST/MCP 同一套处理器，按 route_config 路由表解析）
final r = await data.call('todo', 'create', {...});
await data.get('todo', 'getStats');   // 返回 {success, data, error, code}
```

> 注意：这是 SDK 的 `AboutmeData`（文件层 API 保留，供服务端/管理后台/本地宿主）；**Flutter 侧 `AboutmeDataService` 的文件层转发已于 2026-10-24 删除**，只暴露业务层命令。

## Facade 高层接口

- `AssetsFacade.uploadChunked`：init→append×N→complete 端到端分块上传（sha256 校验、onProgress 回调、256MiB 上限）；`SdkMediaService.uploadBytes` >16MiB 自动路由分块。
- `ChatFacade` / `DiaryFacade`：chat / diary 域的高层封装。

## 域命令速查（节选，完整路由见 route_config.dart）

- **system 域**（configs/ 前缀唯一写入口）：`getConfig {key}` → `{value}`；`setConfig {key, value}`（覆盖写，value 任意 JSON）；`deleteConfig {key}` → `{deleted}`。key 为 configs/ 下相对路径，白名单校验（禁穿越/反斜杠/空格）。
- **assets 域**：`migrateLegacyAssets {items:[{sourcePath,fileName?,mediaType?}]}`（白名单 27 域 + stickers 前缀，单次 50 项分批）；`sweep {dryRun=true, minAgeHours=24}`（引用=0 回收）；`initUpload/appendChunk/completeUpload`（8MiB/块、总 256MiB、24h 暂存 GC）。
- **chat_stickers**：`migrateLegacyStickers`（dryRun 默认、幂等、迁后删旧）。
- **store**：`createProductRow/updateProductRow/deleteProductRow`（按行提交；排序保留整表）。
- **database**：数据搬家（事务内读旧→写新→删旧）。

## capabilities

`capabilities` 查询返回 `protectedPrefixes` 等信息；admin-vue FilesTab 据此做删除双检查（域 + 保护前缀）。

## REST / MCP 通路

本包 handler 不直接暴露 HTTP；由 `packages/aboutme_server` 的 `/api/v1/plugins/*` 与 `POST /mcp` 包装为 REST/JSON-RPC（同一套处理器）。
