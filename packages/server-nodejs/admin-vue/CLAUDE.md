# admin-vue 管理面板

server-nodejs 内置的 Web 管理面板：Vue ^3.5 + TypeScript + Naive UI + Pinia 的单页应用（Vite ^8 构建），负责服务器的一切管理操作——登录/注册、总览统计、文件同步浏览、设备管理、服务端插件管理、API Key 管理与设置（API 开关、数据操作）。构建产物由服务器静态托管于 `/admin`（见根包 `npm run build:admin`）；接口层 `src/api/index.ts` 以 `/api/v1/*` 前缀调用宿主服务器 REST API。

## 约定的规则

- 开发调试：`npm run dev`（Vite dev server，需配置指向后端的 baseUrl）；类型检查+构建：`npm run build`（`vue-tsc -b && vite build`）。宿主侧统一走 `npm run build:admin`。
- 服务器地址（baseUrl）保存在 localStorage（`ApiClient.setBaseUrl`），登录后可切换。
- 新增页面 = 新组件目录（`components/<tab>/`）+ TabNavigation 注册 + 需要状态时加 Pinia store；接口只加在 `src/api/index.ts`。
- 依赖仅 `naive-ui` / `pinia` / `@vicons` / `jszip`，不要引入 UI/状态以外的重依赖。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 页面结构、stores、认证流 | 第一次接触面板 |
| [对外接口](claude/public-interfaces.md) | 面板消费的全部 /api/v1 端点 | 加接口 / 对齐服务端路由 |
| [文件地图](claude/file-map.md) | 全部源码文件速查 | 找代码 |

## 模块索引

| 模块 | 说明 |
|------|------|
| `src/api/` | `ApiClient`（fetch 封装 + baseUrl 管理）与 auth/sync/devices/plugins API 定义 |
| `src/components/login/` | 登录 / 注册表单 |
| `src/components/overview/` | 总览 Tab（统计网格、活动列表） |
| `src/components/files/` | 同步文件浏览 |
| `src/components/devices/` | 设备管理 |
| `src/components/plugins/` | 服务端插件管理 |
| `src/components/api-keys/` | API Key 创建/展示 |
| `src/components/settings/` | 设置（ApiControl、DataOperations） |
| `src/components/layout/` + `common/` | 头部、Tab 导航、公共组件 |
| `src/stores/` | Pinia：auth / files / devices / plugins / ui |

## 扫描状态

- 更新时间：2026-09-02（本次补扫）
- 已扫描：package.json、全部 31 个源码文件清单、api/index.ts 端点全集、stores 定义。
- 未深扫：各 Vue 组件模板细节。
