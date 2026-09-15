# 调研发现

- HTTP 客户端位于 `lib/core/storage/http_storage.dart`，当前请求只发送 `X-API-Key`，未携带设备 ID。
- 设置对话框目前只测试 HTTP 并保存配置，没有建立 WS。
- 客户端已有 `RouteRefreshManager` / `SyncDataUpdatedArgs` 刷新事件入口，需要进一步确认全局实例和插件 ID 推导规则。
- 服务端当前源码没有文档所称的 `WebSocketManager` 和 `FileWatcherService`，只有 `types/index.ts` 中的旧 WS 类型。
- 服务端入口直接使用 Node `http.createServer(app)`，可在此挂载 `ws` 服务；依赖树已有 `ws`。
- `authMiddleware.ts` 已提供 `getDeviceIdFromContext()`，读取 `X-Device-ID`。
- `RouteRefreshManager.onFileSynced(path)` 会按路径首段定位插件、调用插件 `refreshData()`，并在当前页面匹配时广播 UI 事件。
- 多数数据插件已实现 `refreshData()`；但仓库中没有调用 `RouteRefreshManager.setPluginManager()`，现有刷新管理器尚未完成初始化。
- Flutter 已依赖 `web_socket_channel ^3.0.0`、`uuid` 和 `shared_preferences`，无需新增客户端包。
- Node 服务端 `package.json` 当前没有直接依赖 `ws`，需明确新增 `ws` 与类型包（不能依赖传递依赖）。
- 最小协议可采用：WS `/api/v1/storage/ws?api_key=...&device_id=...`；服务端认证后登记 `{userId, deviceId}`；写/删成功广播 `{type:'file_updated', data:{file_path,...}}` 给同 userId 且不同 deviceId 的连接。
- 插件 API 全部由 `createPluginRoutes` 统一执行；成功的 POST/PUT/PATCH/DELETE 可广播 `${pluginId}/`，客户端按插件目录映射刷新。
- MCP 使用 `createInternalInvoker` 直调插件处理器、绕过 Express 插件路由，需要在 invoker 成功写操作处单独回调广播。
- 412 根因已确认是客户端 HTTP 存储的 ETag 条件写入；冲突文件为跨设备 UI 状态 `configs/plugin_manager.json`、`configs/route_history.json`，与 WS 刷新无关。
