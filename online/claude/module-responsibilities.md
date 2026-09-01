# 模块职责

> 所属：online/ · [返回索引](../CLAUDE.md)

## Web 小程序（`apps/`，清单 `apps.json`）

| 应用 | 标题 | 说明 | 标签 | preload |
|------|------|------|------|---------|
| `password_manager/` | 🔐 密码管理器 | 本地密码存储、分类管理与搜索，数据存本地 | 工具/安全/密码 | ✅（注册保存密码等 Agent 工具） |
| `emoji-time-capsule/` | ⏰ 日记时光胶囊 | 用 Emoji 记录与封存日记时刻的创意展示 | 娱乐/记录/创意 | — |
| `pure_read/` | 📖 阅读记录 | 记录书籍/文章并追踪阅读进度 | 阅读/工具/效率 | ✅ |
| `timeline/` | ⏰ 时间线展示 | 按时间线排列展示记忆瞬间 | 时间线/记忆/展示 | — |

（均为 v1.0.0，author: aboutmeTeam，permissions: storage；产物含 hashed 资产与 `files.json`。）

## 在线脚本（`scripts/`，清单 `scripts.json`）

| 脚本 | 说明 |
|------|------|
| `ai_encouragement_bot/`（metadata.json + script.js + files.json） | AI 鼓励助手：监听用户活动事件 → 发简要信息给 AI → toast 展示鼓励语；permissions: agent_chat |

## Agent 配置（`agents.json`）

多服务商 Agent 定义示例数组：每个 Agent 含 `serviceProviderId`（如 zhipu）、`baseUrl`、`headers`（Bearer Key）、`model`（如 glm-4.6v）、采样参数、图标/图标色、`enableFunctionCalling`、`openingQuestions` 与 `messages[]` 系统提示词（内置"账单分析专家"等示例）。

## 工具

| 文件 | 说明 |
|------|------|
| `generate_files_json.py` | 扫描应用目录生成/更新 `files.json`（文件列表与校验信息） |
