# Aboutme HTTP Storage Server (Node.js + TypeScript)

基于 Node.js + TypeScript 的 Aboutme 端到端加密 HTTP 存储服务器

## 功能特性
      - ✅ 端到端加密（AES-256-GCM）
      - ✅ JWT 认证 + API Key 支持
      - ✅ 加密文件 CRUD、ETag 并发控制和审计日志
      - ✅ 19 个插件的 RESTful API
      - ✅ **插件系统（安装/启用/禁用/卸载、 before/after 钩子)
      - ✅ 纯文件存储（无需数据库）
      - ✅ ZIP 数据导出
      - ✅ Vue 3 管理界面
      - ✅ 插件商店配置

      - ✅ 从商店安装插件
      - ✅ 上传 ZIP 安装

- ✅ 端到端加密（AES-256-GCM）
- ✅ JWT 认证 + API Key 支持
- ✅ 加密文件 CRUD、ETag 并发控制和审计日志
- ✅ 19 个插件的 RESTful API
- ✅ 纯文件存储（无需数据库）
- ✅ ZIP 数据导出

## 快速开始

### 方式一：npm 全局安装（推荐）

```bash
# 全局安装
npm install -g @hunmer/aboutme-server

# 启动服务器
aboutme-server

# 指定端口启动
PORT=8080 aboutme-server
```

首次启动会在当前目录创建 `data` 文件夹存储数据。

#### 环境变量配置

全局安装时可通过环境变量配置：

```bash
# Linux/macOS
PORT=8080 DATA_DIR=/var/aboutme-data aboutme-server

# Windows PowerShell
$env:PORT=8080; $env:DATA_DIR="C:\aboutme-data"; aboutme-server

# 或创建 .env 文件在运行目录
```

### 方式二：从源码运行

#### 1. 安装依赖

```bash
cd packages/server-nodejs
npm install
```

### 2. 配置环境变量

复制示例配置文件：

```bash
cp .env.example .env
```

编辑 `.env` 文件：

```env
# 服务器配置
PORT=8874
DATA_DIR=./data

# JWT 配置
JWT_SECRET=your-secure-secret-key
TOKEN_EXPIRY_DAYS=36500

# CORS 配置
ENABLE_CORS=true
CORS_ORIGINS=*

# 日志配置
ENABLE_LOGGING=true
```

### 3. 启动服务器

开发模式（热重载）：

```bash
npm run dev
```

生产模式：

```bash
npm run build
npm start
```

## API 端点

### 公开端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 健康检查 |
| `/version` | GET | 版本信息 |

### 认证 API (`/api/v1/auth`)

| 端点 | 方法 | 说明 |
|------|------|------|
| `/register` | POST | 用户注册 |
| `/login` | POST | 用户登录 |
| `/refresh` | POST | 刷新 Token |
| `/set-encryption-key` | POST | 设置加密密钥 |
| `/clear-encryption-key` | POST | 清除加密密钥 |
| `/has-encryption-key` | GET | 检查密钥状态 |
| `/api-keys` | GET/POST | API Key 管理 |
| `/api-keys/:id` | DELETE | 撤销 API Key |
| `/user-info` | GET | 获取用户信息 |

### Storage API (`/api/v1/storage`)

| 端点 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 认证后的连接检查 |
| `/files/{path}` | GET/HEAD/PUT/DELETE | 加密字节 CRUD 与 ETag 条件操作 |
| `/files?prefix=...` | GET/DELETE | 前缀文件列表/清除 |

### 插件 API (`/api/v1/plugins/:pluginId`)

支持 19 个插件，每个都有标准 CRUD：

| 端点 | 方法 | 说明 |
|------|------|------|
| `/items` | GET | 获取列表 |
| `/item/:id` | GET | 获取单个 |
| `/item` | POST | 创建 |
| `/item/:id` | PUT | 更新 |
| `/item/:id` | DELETE | 删除 |

**插件列表**:
chat, notes, activity, goods, bill, todo, agent_chat, calendar_album, calendar, checkin, contact, database, day, diary, nodes, openai, store, timer, tracker

### 插件系统 API (`/api/v1/system/plugins`)

> 所有端点需要管理员权限

| 端点 | 方法 | 说明 |
|------|------|------|
| `/` | GET | 获取已安装插件列表 |
| `/:uuid` | GET | 获取单个插件详情 |
| `/upload` | POST | 上传 ZIP 安装插件 |
| `/:uuid/enable` | POST | 启用插件 |
| `/:uuid/disable` | POST | 禁用插件 |
| `/:uuid` | DELETE | 卸载插件 |
| `/store` | GET | 获取商店插件列表 |
| `/store/install` | POST | 从商店安装插件 |
| `/config` | GET/PUT | 获取/更新商店配置 |

## 插件系统

### 插件结构

插件以 ZIP 文件形式分发，包含以下文件：

```
plugin.zip
├── metadata.json    # 必需 - 插件元信息
└── main.js          # 必需 - 入口文件
```

### metadata.json 示例

```json
{
  "uuid": "data-sync-logger",
  "title": "数据同步日志记录器",
  "author": "Aboutme",
  "description": "监听插件数据变更并记录日志",
  "version": "1.0.0",
  "website": "https://github.com/aboutme/data-sync-logger",
  "permissions": {
    "dataAccess": [],
    "operations": ["read"],
    "networkAccess": false
  },
  "events": ["chat::*", "todo::*"]
}
```

### main.js 示例

```javascript
module.exports.metadata = require('./metadata.json');

module.exports.onLoad = async function() {
  console.log('插件已加载');
};

module.exports.handlers = {
  'chat::before:createChannel': async function(ctx) {
    console.log('创建频道前:', ctx.data);
    return ctx; // 可以修改 ctx.data 或设置 ctx.canceled = true
  },
  'chat::after:createChannel': async function(ctx) {
    console.log('创建频道后:', ctx.success);
  }
};
```

### 事件命名格式

```
{pluginId}::{timing}:{action}{Entity}
```

- `timing`: `before` 或 `after`
- `action`: `create`, `read`, `update`, `delete`
- `entity`: 实体名称（如 `Channel`, `Task`, `Note` 等）

示例：
- `chat::before:createChannel` - 创建频道前
- `todo::after:deleteTask` - 删除任务后
- `notes::*` - 所有 notes 事件（通配符）

## 认证方式

### JWT Token

```http
Authorization: Bearer <token>
```

### API Key

```http
X-API-Key: <api_key>
```

## 加密

所有用户数据都使用 AES-256-GCM 加密。加密密钥由客户端生成和管理，服务器仅存储密文。

### 加密格式

```
base64(iv).base64(ciphertext + authTag)
```

- IV 长度: 16 字节
- 密钥长度: 32 字节 (256-bit)

## MCP 端点 (AI 工具)

服务器内置 MCP (Model Context Protocol) 端点，供 AI 客户端（Claude、Cursor、Cherry Studio 等）以 Streamable HTTP 方式访问个人数据，无需独立进程：

```http
POST http://localhost:8874/mcp
```

### 认证

与插件 API 相同，每个请求需携带：

```http
X-API-Key: mk_live_your_api_key
X-Encryption-Key: your_base64_encryption_key
```

MCP 客户端的权限等同于其认证身份的权限。工具调用在进程内直达插件处理器（无回环 HTTP 请求），数据经 `X-Encryption-Key` 端到端加密。

### 客户端配置示例

```json
{
  "mcpServers": {
    "aboutme": {
      "type": "http",
      "url": "http://localhost:8874/mcp",
      "headers": {
        "X-API-Key": "mk_live_your_api_key",
        "X-Encryption-Key": "your_base64_encryption_key"
      }
    }
  }
}
```

### 可用工具

覆盖 12 个插件、60+ 工具，命名规则为 `aboutme_<插件>_<操作>`：

- **Chat** - 频道/消息管理（获取、创建、发送、搜索等）
- **Notes** - 笔记管理
- **Activity** - 活动记录与统计
- **Goods** - 物品/仓库管理
- **Bill** - 账单/账户管理
- **Todo** - 任务管理
- **Diary** - 日记管理
- **Checkin** - 签到管理
- **Calendar** - 日历事件
- **Contact** - 联系人管理
- **Tracker** - 目标追踪
- **Day** - 纪念日管理

完整工具列表可通过 `tools/list` 获取。

## 项目结构

```
server-nodejs/
├── src/
│   ├── index.ts              # 入口
│   ├── config/
│   │   └── serverConfig.ts   # 配置
│   ├── services/
│   │   ├── authService.ts    # 认证服务
│   │   ├── encryptionService.ts # 加密服务
│   │   ├── fileStorageService.ts # 文件存储
│   │   ├── pluginDataService.ts # 插件数据
│   │   └── fileStorageService.ts # 文件存储与条件写入
│   ├── middleware/
│   │   ├── authMiddleware.ts # 认证中间件
│   │   └── apiEnabledMiddleware.ts # API 启用检查
│   ├── routes/
│   │   ├── authRoutes.ts     # 认证路由
│   │   ├── storageRoutes.ts  # 存储路由
│   │   └── pluginRoutes/     # 插件路由
│   ├── mcp/                  # MCP 端点 (Streamable HTTP)
│   │   ├── index.ts          # /mcp 路由 (认证 + 无状态 transport)
│   │   ├── server.ts         # MCP Server 工厂 (工具分发)
│   │   ├── invoker.ts        # 进程内插件处理器调用器
│   │   ├── client.ts         # 插件 API 客户端 (进程内直调)
│   │   ├── tools.ts          # 工具定义 (60+)
│   │   └── types.ts          # 类型定义
│   └── types/
│       └── index.ts          # 类型定义
├── tests/
│   ├── api.test.ts           # 集成测试
│   └── mcp.test.ts           # MCP 端点测试
├── package.json
├── tsconfig.json
├── jest.config.js
└── .env.example
```

## 运行测试

```bash
# 运行所有测试
npm test

# 带覆盖率报告
npm run test:coverage

# 插件系统 API 测试 (需要服务器运行)
node test-api.mjs
```

## 开发

```bash
# 开发模式
npm run dev

# 编译
npm run build
```

## 许可证

MIT
