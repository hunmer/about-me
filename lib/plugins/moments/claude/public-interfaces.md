# 对外接口

> 所属：`lib/plugins/moments/` · [返回索引](../CLAUDE.md)

## 路由

- `/moments` — 宿主页（三页签）
- `/moments/profile?agentId={id}` — agent/「我」的个人主页

## 主页小组件

- 图标小组件（1x1），注册于 `home_widgets/`。

## 依赖的 openai 侧能力（本插件不导出 JS API）

- `openai/moments/services/moments_service.dart`：动态数据（`MomentPost`）加载/发布/监听。
- `openai/moments/services/agent_assets_service.dart`：agent 资产图（`AgentAsset`）。
- `openai/moments/services/image_gen_service.dart`：生图。
- `openai/moments_js_api.dart` 中的 AI 工具（agent 侧调用，非本插件导出）：
  - 生图：文生图/图生图（params：prompt 必填、refAssetNames、aspectRatio、n、sendToChat 默认 true）。
  - 发朋友圈：text/tag 必填（tag 须为 MomentTags 之一）、imagePrompt/refAssetNames/sendToChat 可选。
  - 查询资产图列表。

## 相关但不在本目录

- `lib/widgets/moments_nyc_map_demo.dart` + `test/moments_nyc_map_demo_test.dart`：基于 flutter_map 的地图 demo（依赖 `flutter_map: ^8.2.2` 引入缘由）。
