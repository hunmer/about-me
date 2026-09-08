# AgentLib 资源管理 UI

## 目标
为全局 Skills/MCP 增加独立列表管理、过滤和 selector，并接入 Agent 编辑页。

## 阶段
- [complete] 读取现有导航/筛选组件与资源模型
- [complete] 完善资源模型与持久化
- [complete] 实现 Skills/MCP 列表页和过滤
- [complete] 实现 selector 并接入 Agent 编辑页
- [complete] 定向分析与测试
- [complete] 增加资源编辑与 Skill 导入
- [complete] 增加 Skills/MCP 默认商店推荐与安装
- [complete] 优化商店缓存、刷新与安装状态
- [complete] 增加商店条目详情与元数据展示
- [complete] 修复 Skill/MCP 下载 403 回退

## 错误记录
| Skill 下载返回 403 | Dart 请求未携带客户端标识且代理可能限制请求 | 增加请求 headers，并在 gh-proxy 403 时回退 raw.githubusercontent.com |
