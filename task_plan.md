# 任务计划

## 目标
HTTP 存储后端配置成功后建立 WS；服务端按 API Key 所属账号向其他设备广播数据更新，客户端收到后重载对应插件。

## 阶段
- [complete] 梳理现有客户端/服务端 HTTP、WS 与刷新链路
- [complete] 实现客户端 WS 生命周期与更新事件处理
- [complete] 实现服务端设备识别、账号广播与更新事件
- [complete] 添加/调整测试并运行验证

## 错误记录
| 错误 | 尝试 | 处理 |
|---|---:|---|
| 文档中的 `webSocketManager.ts`、`fileWatcherService.ts`、`syncRoutes.ts` 不存在 | 1 | 以当前源码为准，改查入口、storageRoutes 与现有事件机制 |
| 误读 `lib/core/event_manager.dart`（实际在 `lib/core/event/`） | 1 | 改用现有 `route_refresh_manager.dart` 接口，无需直接改事件管理器 |
| 首次补丁同时新增并更新同一文件导致 apply_patch 校验失败 | 1 | 合并为一次完整新增后成功应用 |
| 在 `packages/server-nodejs` 工作目录执行仓库根相对路径的 `dart format`，未找到文件 | 1 | 改回仓库根目录单独执行格式化 |
| `tsc` 找不到新增的 `ws` 及类型声明 | 1 | lockfile 已更新但 node_modules 未安装，执行 npm install 后复验 |
| Jest 启动测试服务时 8874 被 procm 服务占用 | 1 | 临时停止持久化服务，测试后重新启动 |
| MCP 定向测试再次被已重启的 procm 服务占用 8874 | 2 | 同样先停服务，完整测试后重启 |

## 完成
- 插件 API 统一广播已接入，Node tsc 与 Jest 22 项测试通过，服务端已重新由 procm 启动。
- 已诊断并修复跨设备 UI 状态文件的 412：客户端 HTTP 存储采用最后写入覆盖；Flutter 存储测试和静态检查通过。
- 已增加 `[SyncDebug]` 跨设备更新链路日志，Flutter 静态检查与 Node TypeScript 检查通过；服务端已重启并确认两台设备 WS 连接。
