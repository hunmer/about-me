# jelly_home（果冻小屋 · 默认启动页）

[根目录](../../../CLAUDE.md) > [lib](../../) > [screens](../) > **jelly_home**

应用默认首页（`/jelly_home`，17 个 Dart 文件）：悬浮底部导航四页签（小屋/日程/看板/我的，IndexedStack 保活）。小屋页承载 Live2D 伙伴（角色视图 + 聊天输入 + 陪伴数值卡）——live2d 插件出数据、agent_chat 出会话、openai 出 Agent、本屏出全部视图。软糖风视觉基于自研 design_system。

## 约定的规则

- 本屏是启动页：初始化重的逻辑放懒加载页签内，勿塞进 build。
- Live2D 渲染/在线模型目录的核心实现（jelly_live2d.dart、live2d_online_models.dart）在本目录，live2d 插件反向复用——改这两处要同时验证插件侧预览。
- `widgets/` 下 5 个卡片（daily_tasks/growth/mood/quick_action/store_banner）为预留无引用，排期接入前勿删。
- 流式回复更新用帧末合并 setState（见 jelly_home_screen.dart 的 _scheduleLive2DReply），勿逐 token 重建。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 四页签、Live2D 伙伴链路分工、陪伴数值、持久化 | 第一次接触本屏 |
| [文件地图](claude/file-map.md) | 17 文件速查（标注预留组件） | 找代码 |
| [索引变更记录](claude/changelog.md) | 本文档更新历史 | 重复运行 /init-project 时 |

## 扫描状态

- 更新时间：2026-10-05（第五轮：首次生成，补第四轮遗留缺口）。
- 已扫描：主屏结构、全部 17 文件职责、Live2D 伙伴链路（与 live2d/agent_chat/openai 分工）、持久化键、相关测试两份。
- 未深扫：jelly_live2d.dart 内部渲染细节（1180 行，仅梳理对外行为）。
