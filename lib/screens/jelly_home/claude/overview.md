# jelly_home · 架构总览

> 所属：lib/screens/jelly_home · [返回索引](../CLAUDE.md)

## 定位

果冻小屋——**应用默认启动页**（`AppRoutes.initialRoute` → `/jelly_home`，route.dart:303）。`JellyBottomNav` + `IndexedStack` 四页签切换内容（不切路由，各页保活）：

| 页签 | 内容 |
|------|------|
| 小屋 cottage | 自定义软糖风布局：资料卡 + 统计卡 → Live2D 角色 + 聊天输入 + 陪伴卡 |
| 日程 schedule | HomeScheduleScreen（来自 home_screen 模块） |
| 看板 board | HomeScreen(asRoot: false)（插件卡片网格） |
| 我的 mine | SettingsScreen |

`HeroMode` 只在当前页启用；页签索引不持久化，重启回到小屋页。

## Live2D 伙伴链路（jelly_home_screen.dart:144-162）

`JellyLive2D` 接收 live2d 插件选中存档的模型定义；`Live2DChatInput`（同文件 :243-390）构造 agent_chat 的 ChatController（临时会话 `live2d:{archiveId}`，Agent 由 openai 插件管理），监听 MessageService，AI 回复经 `Live2DPlugin.cleanReply` 清洗后帧末合并 setState（避免流式每 token 重建整页），完成后 `speakReply` TTS。点击命中 hit area 记录陪伴互动。

**分工**：live2d 插件 = 数据与设置；agent_chat = 会话基础设施；openai = Agent 与请求；jelly_home = 全部视图。

## 陪伴数值（companion_controller.dart）

`CompanionController extends ChangeNotifier`：情绪/精力/好感度/陪伴天数，离线时间结算（精力衰减、跨天情绪回落、好感日上限、连续天数），SharedPreferences 键前缀 `companion.*`。

## 本地持久化

- 陪伴数值：`companion.*`（SharedPreferences）。
- 角色尺寸：`jelly_live2d.size`（200-560，默认 360）。
- 每模型裁剪区域：`jelly_live2d.crop.{base64url(modelDir+modelFile)}`（整图时删键）。

## 设计说明

`widgets/` 下 5 个卡片/组件当前**无引用**（设计稿预留）：jelly_daily_tasks_card、jelly_growth_card、jelly_mood_card、jelly_quick_action、jelly_store_banner——排期接入前勿删。
