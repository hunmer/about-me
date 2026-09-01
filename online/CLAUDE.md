# online/ 在线内容仓库

Aboutme WebView 插件的官方在线内容仓库，含三块：**Web 小程序**（`apps/`，4 个：密码管理器、日记时光胶囊、阅读记录、时间线展示，由 `apps.json` 清单索引，供应用内"应用商店"发现与安装）、**在线脚本**（`scripts/`，`scripts.json` 清单 + AI 鼓励助手等 JS 脚本）、**AI Agent 配置**（`agents.json`，多服务商 Agent 定义示例）。小程序发布形态为预构建静态产物（`index.html` + `assets/index-*.js/css`）+ `files.json` 完整性清单；部分小程序带 `preload.js`——它在 **QuickJS 引擎**（非 WebView）中执行，通过 `aboutme.registerTool()` 向 Agent Chat 注册 AI 可调用工具。

## 约定的规则

- 小程序元数据固定字段：`id / title / icon / desc / files / version / author / homepage / tags / permissions`（见 `apps/apps.json`）；`files.json`（文件清单与校验）用根下 `generate_files_json.py` 重新生成。
- `preload.js` 运行于 QuickJS：只能用 `aboutme.registerTool()` 等 Dart 注入的 API，Dart 侧会先验证 `aboutme.registerTool` 存在，脚本内无需轮询等待。
- 目录名即小程序 `id`；新增小程序 = 新目录 + files.json + 在 `apps.json` 登记；在线脚本同理登记到 `scripts.json`。
- 小程序产物为构建后的静态文件，修改功能应改源码工程后重新构建，而非手改压缩产物。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 清单机制、preload 工具注册架构 | 开发新小程序前 |
| [模块职责](claude/module-responsibilities.md) | 4 个小程序与脚本、Agent 配置明细 | 挑选/定位内容 |

## 模块索引

| 模块 | 说明 |
|------|------|
| `apps/apps.json` + 4 个应用目录 | 小程序清单与产物 |
| `scripts/scripts.json` + `ai_encouragement_bot/` | 在线脚本清单与示例 |
| `agents.json` | AI Agent 配置（多服务商、系统提示词） |
| `generate_files_json.py` | files.json 生成工具 |

## 扫描状态

- 更新时间：2026-09-02（本次补扫）
- 已扫描：apps.json / scripts.json 全部条目、各应用文件清单、password_manager 的 preload.js、ai_encouragement_bot 结构、agents.json 结构。
- 未深扫：各小程序压缩产物内部（均为构建物）、emoji-time-capsule/timeline 无 preload 的应用细节。
