<p align="center">
  <img src="assets/icon/icon.png" width="128" alt="Aboutme 图标">
</p>

<h1 align="center">Aboutme</h1>

<p align="center">
Aboutme 是一个使用 Flutter 构建的跨平台个人助手应用，集成了聊天、日记和活动追踪功能。
</p>

<p align="center">
  <a href="https://hunmer.github.io/aboutme_docs/">📖 文档</a> •
  <a href="https://github.com/hunmer/Aboutme/releases">📦 下载</a>
</p>

## 项目介绍

这是一个使用 Flutter 开发的多功能记录应用集合，旨在降低不同应用间切换的成本。愿景是实现终身使用、持续改进和收集个人数据，利用 AI 进行数据分析和决策以改善生活。

## ✨ 特性

<table>
<tr>
<td align="center" width="33%">

### 🚀 跨平台支持
Android、iOS、Web、Windows、macOS、Linux 全平台覆盖

</td>
<td align="center" width="33%">

### 🔌 插件化架构
18+ 功能插件，可独立开发和维护

</td>
<td align="center" width="33%">

### 🔒 本地优先
支持可选的端到端加密 HTTP 存储，数据掌控在用户手中

</td>
</tr>
<tr>
<td align="center">

### 🤖 AI 驱动
完全由 AI 编写，内置多种 AI 助手

</td>
<td align="center">

### 🌍 国际化
内置中英双语支持

</td>
<td align="center">

### 📱 现代 UI
Material Design 3 设计语言

</td>
</tr>
<tr>
<td align="center">

### ⚡ JavaScript 脚本
内置 JavaScript 引擎，支持自定义脚本扩展

</td>
<td align="center">

### 🧩 Web 小程序
支持运行 Web 小程序，无缝集成轻量级应用

</td>
<td align="center">

### 🖥️ 可部署后端
支持部署独立后端服务，提供 API 接口

</td>
</tr>
<tr>
<td align="center">

### 🔑 API Key 管理
内置 API Key 创建和管理，方便第三方应用集成

</td>
<td align="center">

### 🔧 MCP 服务
集成 Model Context Protocol，支持多种 AI 模型接入

</td>
<td align="center">

### 🔗 HTTP/WebSocket SDK
内置 SDK，轻松实现实时通信和 API 集成

</td>
</tr>
</table>

## 🏗️ 项目结构

```
Aboutme/
├── lib/                    # Flutter 应用代码
│   ├── core/               # 核心功能（插件系统、存储、事件）
│   ├── plugins/            # 功能插件（25+）
│   ├── screens/            # 应用界面
│   └── widgets/            # 通用组件
├── packages/               # 子包（原生插件、服务端）
│   ├── aboutme_server/     # Dart 同步服务器（REST + WS + MCP 端点 /mcp + admin-vue 管理面板）
│   └── ...                 # 数据 SDK、原生插件等
├── shared_models/          # 共享数据模型
└── docs/                   # 文档
```

## 🚀 快速开始

### 移动端/桌面端

1. 安装 [Flutter SDK](https://flutter.dev)
2. 克隆项目并安装依赖
   ```bash
   git clone https://github.com/hunmer/Aboutme.git
   cd Aboutme
   flutter pub get
   ```
3. 运行应用
   ```bash
   flutter run
   ```

### 同步服务器

```bash
cd packages/aboutme_server
dart pub get
dart run bin/server.dart
# 访问 http://localhost:8874/admin/（管理面板源码在 admin-vue/，npm run build 构建到 ../admin）
```

### 应用内配置存储后端（设置 → 存储后端）

应用通过「设置 → 存储后端」对话框切换本地存储 / HTTP 服务器同步。选择「HTTP 服务器」后各字段填写方式：

| 字段 | 填写说明 |
|------|----------|
| 服务器地址 | 服务器**根地址**（不带路径，末尾 `/` 会自动去除），SDK 自动拼接 `/api/v1/storage/files`。本机开发填 `http://127.0.0.1:8874`。校验规则：必须 HTTPS，仅 `localhost` / `127.0.0.1` 允许 HTTP——手机/模拟器需用局域网 IP 连接，此时必须配 HTTPS 反向代理 |
| API Key | 以 `mk_` 开头，通过服务端创建（见下方）。随每个请求以 `X-API-Key` 头发送 |
| 用户 ID | 可留空。仅本地记录展示用，不参与请求——服务端根据 API Key 自动识别所属用户目录 |

**获取 API Key**（任选其一）：

- 管理面板：访问 `http://localhost:8874/admin/`，登录后在 API Key 页签创建
- 命令行：
  ```bash
  # 登录拿 token（默认管理员 admin/admin123）
  curl -s -X POST http://localhost:8874/api/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"admin123","device_id":"setup"}'
  # 用 token 创建 Key（返回 mk_ 开头的 key）
  curl -s -X POST http://localhost:8874/api/v1/auth/api-keys \
    -H "Authorization: Bearer <上一步返回的token>" \
    -H "Content-Type: application/json" -d '{"name":"my-app"}'
  ```

**对话框按钮**：

- **测试连接**：校验必填项后请求 `/api/v1/storage/health` 并建立 WebSocket，成功/失败会显示在对话框内
- **迁移本地数据**：将本地后端的数据一次性上传到所填 HTTP 服务器（自动先测试连接，并显示进度）
- **保存**：切换后端类型（本地 ↔ HTTP）时会弹确认框——切换会改变应用读写数据的位置；保存后立即连接/断开 WebSocket

### MCP 端点 (AI 集成)

MCP 服务内置于 Dart 同步服务器（`packages/aboutme_server`），启动服务器后即可使用：

```bash
procm-command start server
# 或: cd packages/aboutme_server && dart run bin/server.dart

# MCP 端点: http://localhost:8874/mcp (Streamable HTTP, 需认证)
# 请求头: X-API-Key
```

## 📖 更多文档

- [完整文档](https://hunmer.github.io/aboutme_docs/)
- [Dart 服务器与 MCP 文档](packages/aboutme_server/README.md)
- [核心功能文档](lib/core/CLAUDE.md)

## 📄 许可证

[CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/deed.zh)

本项目采用知识共享署名-非商业性使用 4.0 国际许可协议，允许非商用前提下使用、修改和分发，**禁止用于商业目的**。如需商业授权，请联系作者。
