# 架构总览

> 所属：packages/server-nodejs/admin-vue · [返回索引](../CLAUDE.md)

## 页面结构

单页 + Tab 导航（`components/layout/TabNavigation.vue`）：

```
未登录 → Login(Register)Form
登录后 → AppHeader + TabNavigation
         ├─ overview   总览（StatsGrid 统计 + ActivityList 活动）
         ├─ files      同步文件（FilesTab）
         ├─ devices    设备管理（DevicesTab）
         ├─ plugins    服务端插件（PluginsTab）
         ├─ api-keys   API Key 管理（ApiKeysTab + Create/KeyResult Modal）
         └─ settings   设置（ApiControl 接口开关 + DataOperations 数据操作）
```

## 状态层（Pinia setup store 风格）

| store | 职责 |
|-------|------|
| `auth.ts` | 登录态、JWT、用户信息、加密密钥校验 |
| `files.ts` | 文件列表与同步状态 |
| `devices.ts` | 设备列表与推送 |
| `plugins.ts` | 服务端插件列表与启停 |
| `ui.ts` | Tab、加载遮罩等界面状态 |

## 请求层

- `src/api/index.ts` 的 `ApiClient`：fetch 封装（自动带认证头、统一错误处理），baseUrl 存 localStorage 可运行时切换；`downloadFile` 走 blob。
- 全部端点以 `/api/v1/*` 为前缀（清单见 [对外接口](public-interfaces.md)），与宿主 Express 路由一一对应。

## 构建

- `npm run build` = `vue-tsc -b && vite build`；产物由宿主 `npm run build` 拷贝进 `dist/admin` 并静态托管。
