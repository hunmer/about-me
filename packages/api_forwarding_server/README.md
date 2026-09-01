# Aboutme API 转发服务器

一个 WebSocket 代理服务器，用于在 **Web 前端** 和 **Flutter 客户端** 之间转发 API 请求，实现前端通过 Aboutme 客户端访问插件功能。

---

## 📋 目录

- [架构概述](#架构概述)
- [三端角色](#三端角色)
- [通信流程](#通信流程)
- [快速开始](#快速开始)
- [详细配置](#详细配置)
- [消息协议](#消息协议)
- [故障排查](#故障排查)

---

## 架构概述

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│   Web 前端      │         │  转发服务器       │         │  Flutter 客户端  │
│  (Frontend)     │         │  (8654 端口)     │         │   (Client)      │
├─────────────────┤         ├──────────────────┤         ├─────────────────┤
│                 │         │                  │         │                 │
│ • React/Vue     │◄──────►│                  │◄──────►│ • Aboutme App   │
│ • aboutme-mock  │  WS     │  • 配对管理       │  WS     │ • 插件系统      │
│ • 浏览器        │         │  • 消息路由       │         │ • JSBridge API  │
│                 │         │  • 心跳检测       │         │                 │
└─────────────────┘         └──────────────────┘         └─────────────────┘
         │                           │                           │
         └───────────────────────────┴───────────────────────────┘
                          配对密钥: ABCD-1234-EFGH-5678
```

### 核心功能

- ✅ **配对匹配**：通过相同的配对密钥连接前端和客户端
- ✅ **双向转发**：前端的请求 → 服务器 → 客户端 → 服务器 → 前端的响应
- ✅ **心跳检测**：保持连接活跃，检测断线
- ✅ **会话管理**：管理配对后的会话状态
- ✅ **角色分离**：前端（`frontend`）和客户端（`client`）各一个，不会混淆

---

## 三端角色

### 1️⃣ 转发服务器（中间层）

**文件位置**：`api_forwarding_server/`

**职责**：
- 作为中间人，连接 Web 前端和 Flutter 客户端
- 管理配对和会话
- 转发 API 请求和响应

**启动命令**：
```bash
cd packages/api_forwarding_server
npm install
npm start    # 默认端口 8654
```

**日志示例**：
```
[服务器] 监听端口: 8654
[会话] 认证请求: frontend, key: ABCD-1234-EFGH-5678
[会话] 新会话创建: xxx-xxx-xxx
[会话] xxx: 转发请求 msg_123 -> bill.getAccounts
[会话] xxx: 转发响应 msg_123 -> 成功
```

---

### 2️⃣ Flutter 客户端（数据层）

**文件位置**：`lib/core/api_forwarding/`

**职责**：
- 提供 Aboutme 插件的 JSBridge API
- 处理来自前端的 API 请求
- 返回真实的插件数据

**配置方式**：
1. 打开 Aboutme 应用
2. 进入 **设置 > 开发者测试 > 转发数据服务**
3. 填写配置：
   - 服务器地址：`ws://localhost:8654`
   - 配对密钥：`ABCD-1234-EFGH-5678`
   - 设备名称：`Aboutme Client`
   - ✅ 启动时自动连接（可选）
4. 点击"连接"

**客户端状态**：
- 🟠 **未连接**：橙色提示，需要点击连接
- 🔵 **等待前端连接...**：蓝色提示，等待 Web 前端连接
- 🟢 **已连接到前端**：绿色提示，配对成功

**日志示例**：
```
[API转发] 正在连接到 ws://localhost:8654...
[API转发] 认证成功，已匹配对端
[API转发] 收到消息: request, 数据: {...}
[API转发] 调用: bill.getAccounts
[API转发] 调用成功，结果: [...]
[API转发] 发送响应: {...}
```

---

### 3️⃣ Web 前端（调用层）

**文件位置**：前端项目根目录的 `aboutme-config.ts` 和 `index.tsx`

**职责**：
- 提供用户界面
- 通过 `Aboutme.plugins.*.*` 调用 API
- 接收并显示返回的数据

**配置方式**：

1. **创建配置文件** (`aboutme-config.ts`)：
```typescript
export const aboutmeConfig = {
  enabled: true,                      // 启用转发模式
  serverUrl: 'ws://localhost:8654',  // 服务器地址
  pairingKey: 'ABCD-1234-EFGH-5678', // 配对密钥（与客户端相同）
  timeout: 0,                         // 0 = 无超时
};
```

2. **初始化** (`index.tsx`)：
```typescript
import('aboutme-mock').then((module) => {
  module.default({
    enableForwarding: aboutmeConfig.enabled,
    serverUrl: aboutmeConfig.serverUrl,
    pairingKey: aboutmeConfig.pairingKey,
    timeout: aboutmeConfig.timeout,
  });
});
```

**使用示例**：
```javascript
// 获取账单账户
let accounts = await Aboutme.plugins.bill.getAccounts({});
console.log('账户列表:', accounts);

// 获取 Todo 列表
let todos = await Aboutme.plugins.todo.getItems({ count: 10 });
console.log('待办事项:', todos);

// 获取日记条目
let diaries = await Aboutme.plugins.diary.getEntries({ limit: 5 });
console.log('日记列表:', diaries);
```

**日志示例**：
```
[Aboutme Mock] 启用转发模式
[WebSocket] 正在连接到 ws://localhost:8654...
[WebSocket] 连接已建立，正在认证...
[WebSocket] 认证成功，已匹配对端
[WebSocket] 调用: bill.getAccounts
[WebSocket] 收到 API 响应: {...}
[WebSocket] API 调用成功，结果: [...]
```

---

## 通信流程

### 完整请求流程

```
1. 前端发起调用
   └─> Aboutme.plugins.bill.getAccounts({})
       └─> WebSocketClient.callPlugin()

2. 前端发送请求消息
   └─> WebSocket 服务器
       {
         "type": "request",
         "requestId": "msg_123",
         "pluginId": "bill",
         "methodName": "getAccounts",
         "params": {}
       }

3. 服务器转发给客户端
   └─> 查找配对会话
   └─> 发送给 Flutter 客户端

4. 客户端处理请求
   └─> ApiForwardingService 收到消息
   └─> 调用 JSBridgeManager
   └─> 执行 bill.getAccounts()
   └─> 获得结果

5. 客户端发送响应
   └─> WebSocket 服务器
       {
         "type": "response",
         "requestId": "msg_123",
         "success": true,
         "result": [...]
       }

6. 服务器转发给前端
   └─> 查找配对会话
   └─> 发送给 Web 前端

7. 前端接收响应
   └─> WebSocketClient 处理响应
   └─> resolve Promise
   └─> 返回给调用者
```

### 时序图

```
前端          服务器           客户端
 │             │                │
 │── 连接 ────►│                │
 │             │── 等待配对 ────►│
 │             │                │
 │◄─ 认证成功 ──┤                │
 │             │                │
 │── 请求 ────►│── 转发请求 ────►│
 │             │                │
 │             │                │── 执行 API ──
 │             │                │
 │             │◄── 响应 ────────┤
 │◄─ 响应 ────►│                │
 │             │                │
```

---

## 快速开始

### 第一步：启动服务器

```bash
cd packages/api_forwarding_server
npm install
npm start
```

输出：
```
[服务器] 监听端口: 8654
```

### 第二步：启动 Flutter 客户端

1. 打开 Aboutme 应用
2. 进入 **设置 > 开发者测试 > 转发数据服务**
3. 配置并点击"连接"

等待状态显示：🔵 **等待前端连接...**

### 第三步：启动 Web 前端

```bash
cd your-frontend-project
npm run dev
```

浏览器控制台输出：
```
[Aboutme Mock] 启动转发模式
[WebSocket] 认证成功，已匹配对端
```

Flutter 客户端状态变为：🟢 **已连接到前端**

### 第四步：测试连接

在浏览器控制台执行：

```javascript
// 测试 1: 获取账户列表
let accounts = await Aboutme.plugins.bill.getAccounts({});
console.log('账户:', accounts);

// 测试 2: 获取待办事项
let todos = await Aboutme.plugins.todo.getItems({ count: 5 });
console.log('待办:', todos);

// 测试 3: 获取日记
let diaries = await Aboutme.plugins.diary.getEntries({ limit: 3 });
console.log('日记:', diaries);
```

成功的话会返回真实数据！

---

## 详细配置

### 服务器配置

**环境变量**：
- `PORT` - 服务器端口（默认：8654）

**启动参数**：
```bash
# 默认端口 8654
npm start

# 自定义端口
PORT=3000 npm start
```

### Flutter 客户端配置

**配置项**：

| 配置项 | 说明 | 示例 |
|--------|------|------|
| 服务器地址 | WebSocket 服务器地址 | `ws://localhost:8654` |
| 配对密钥 | 用于匹配前端和客户端 | `ABCD-1234-EFGH-5678` |
| 设备名称 | 客户端标识 | `Aboutme Client` |
| 启动时自动连接 | 应用启动时自动连接服务器 | 开关 |

**存储位置**：
- SharedPreferences（Android/iOS）
- 配置键：`api_forwarding_*`

### Web 前端配置

**配置文件** (`aboutme-config.ts`)：

```typescript
export const aboutmeConfig = {
  // 是否启用转发模式
  enabled: true,

  // 服务器地址
  serverUrl: 'ws://localhost:8654',

  // 配对密钥（与客户端一致）
  pairingKey: 'ABCD-1234-EFGH-5678',

  // 请求超时（毫秒，0 = 无超时）
  timeout: 0,
};
```

**初始化代码** (`index.tsx`)：

```typescript
import { aboutmeConfig } from './aboutme-config';

if (import.meta.env.DEV && typeof window.Aboutme === 'undefined') {
  import('aboutme-mock').then((module) => {
    module.default({
      enableForwarding: aboutmeConfig.enabled,
      serverUrl: aboutmeConfig.serverUrl,
      pairingKey: aboutmeConfig.pairingKey,
      timeout: aboutmeConfig.timeout,
    });
  });
}
```

---

## 消息协议

### 1. 认证消息

**前端/客户端 → 服务器**

```json
{
  "type": "auth",
  "id": "msg_1767420000000_abc123",
  "timestamp": 1767420000000,
  "role": "frontend" | "client",
  "pairingKey": "ABCD-1234-EFGH-5678",
  "clientInfo": {
    "platform": "web" | "android" | "ios",
    "version": "1.0.0",
    "deviceId": "unique-device-id",
    "deviceName": "My Device"
  }
}
```

### 2. API 请求消息

**前端 → 服务器 → 客户端**

```json
{
  "type": "request",
  "id": "msg_1767420000000_def456",
  "timestamp": 1767420000000,
  "requestId": "msg_1767420000000_req789",
  "pluginId": "bill",
  "methodName": "getAccounts",
  "params": {}
}
```

### 3. API 响应消息

**客户端 → 服务器 → 前端**

```json
{
  "type": "response",
  "id": "msg_1767420000000 ghi012",
  "timestamp": 1767420000000,
  "requestId": "msg_1767420000000_req789",
  "success": true,
  "result": [
    {
      "id": "cash-001",
      "name": "现金账户",
      "balance": 1000.00
    }
  ]
}
```

### 4. 心跳消息

**双向**

```json
// Ping
{
  "type": "ping",
  "id": "msg_1767420000000_ping",
  "timestamp": 1767420000000
}

// Pong
{
  "type": "pong",
  "id": "msg_1767420000000_ping",
  "timestamp": 1767420000000
}
```

---

## 故障排查

### 问题 1：前端无法连接

**症状**：
```
[WebSocket] 错误事件: Event
[WebSocket] 连接已关闭
```

**解决方案**：
1. 确认服务器正在运行：`lsof -i :8654`
2. 检查服务器地址是否正确：`ws://localhost:8654`
3. 检查防火墙设置

---

### 问题 2：相同角色的连接已存在

**症状**：
```
[WebSocket] 收到消息: {"type":"response",...,"message":"相同角色的连接已存在"}
```

**原因**：前端或客户端重复连接

**解决方案**：
1. 关闭所有浏览器标签页，只保留一个
2. 确保 Flutter 客户端只连接一次
3. 检查是否有多个地方在初始化

---

### 问题 3：前端收到响应但数据为空

**症状**：
```javascript
let data = await Aboutme.plugins.bill.getAccounts({});
console.log(data); // undefined
```

**原因**：响应格式不匹配或超时

**解决方案**：
1. 检查 Flutter 日志确认是否返回数据
2. 检查服务器日志确认是否转发响应
3. 增加超时时间或设置 `timeout: 0`

---

### 问题 4：客户端调用失败

**症状**：
```
[API转发] 调用失败: Exception: 插件不存在
```

**原因**：插件 ID 或方法名错误

**解决方案**：
1. 确认插件已加载到 JSBridge
2. 检查插件 ID 拼写（小写）
3. 检查方法名是否正确

---

### 问题 5：配对超时

**症状**：
```
[WebSocket] 收到消息: {"type":"response",...,"message":"配对超时"}
```

**解决方案**：
1. 先连接客户端，等待显示"等待前端连接..."
2. 再刷新前端页面
3. 确保配对密钥完全一致

---

## 开发调试

### 查看服务器日志

```bash
cd packages/api_forwarding_server
npm start
```

输出：
```
[服务器] 监听端口: 8654
[会话] 认证请求: client, key: ABCD-1234-EFGH-5678
[会话] 认证请求: frontend, key: ABCD-1234-EFGH-5678
[会话] 新会话创建: xxx-xxx-xxx
[会话] xxx: 转发请求 msg_123 -> bill.getAccounts
[会话] xxx: 转发响应 msg_123 -> 成功
```

### 查看 Flutter 日志

```bash
flutter run
```

输出：
```
[API转发] 正在连接到 ws://localhost:8654...
[API转发] 认证成功，已匹配对端
[API转发] 调用: bill.getAccounts
[API转发] 调用成功，结果: [...]
```

### 查看前端日志

打开浏览器开发者工具（F12）> Console

输出：
```
[Aboutme Mock] 启用转发模式
[WebSocket] 正在连接到 ws://localhost:8654...
[WebSocket] 认证成功，已匹配对端
[WebSocket] 调用: bill.getAccounts
[WebSocket] API 调用成功，结果: [...]
```

---

## 相关文件

### 服务器端
- `src/server.ts` - WebSocket 服务器
- `src/session.ts` - 会话管理
- `src/types.ts` - 消息类型定义
- `src/index.ts` - 入口文件

### Flutter 客户端
- `lib/core/api_forwarding/api_forwarding_service.dart` - 转发服务
- `lib/core/api_forwarding/api_forwarding_config.dart` - 配置管理
- `lib/screens/settings_screen/widgets/api_forwarding_settings_dialog.dart` - 设置对话框

### Web 前端
- `aboutme-mock/src/websocket-client.ts` - WebSocket 客户端
- `aboutme-mock/src/index.ts` - 初始化和 API 代理

---

## 许可证

MIT
