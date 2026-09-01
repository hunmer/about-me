# api_forwarding_server API 转发服务器

`memento-api-forwarding-server` v1.0.0 —— 一个轻量 WebSocket 代理（仅 4 个 TS 源文件 + ws/uuid 两个依赖），用于在 **Web 前端**与 **Flutter 客户端**之间转发 API 请求：两端用相同的**配对密钥**（形如 `ABCD-1234-EFGH-5678`）连接即完成配对，此后前端发出的请求经服务器转给客户端的 JSBridge 执行、响应原路返回，从而让纯 Web 页面借道用户自己的 Memento 客户端访问插件数据（含 memento-mock 等前端方案）。默认端口 **8654**，支持心跳检测。

## 约定的规则

- 启动：`npm run dev`（tsc && node）；改代码用 `npm run watch`；构建 `npm run build`。
- 消息协议（配对、转发、心跳）以本包 `README.md` 的"消息协议"章节为准。
- 本服务无持久化状态、无配置文件；会话生命周期见 `src/session.ts`。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 三端角色、通信流程、源码结构 | 第一次接触本包 |
| [入口与启动](claude/entrypoints.md) | 启动与接入方式 | 部署 |
| [对外接口](claude/public-interfaces.md) | WebSocket 协议要点 | 对接前端/客户端 |

## 模块索引

| 模块 | 说明 |
|------|------|
| `src/index.ts` | 入口：起 WebSocket 服务（8654） |
| `src/server.ts` | 连接管理、配对匹配、消息路由、心跳 |
| `src/session.ts` | 配对会话生命周期 |
| `src/types.ts` | 消息类型定义 |
| `README.md` | 架构图、消息协议、故障排查（最详尽） |

## 扫描状态

- 更新时间：2026-09-01 23:48 (+0800)
- 已扫描：package.json、README、源码文件清单。
- 未深扫：各消息类型字段（读 `src/types.ts` / README 协议章节）。
