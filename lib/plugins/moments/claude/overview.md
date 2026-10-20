# 插件总览

> 所属：`lib/plugins/moments/` · [返回索引](../CLAUDE.md)

## 定位与分工

moments 是「AI 朋友圈」的**界面壳插件**（29 个内置插件之一），2026-10 独立成插件。整体架构是"UI 在 moments、数据在 openai"：

| 层 | 位置 | 内容 |
|----|------|------|
| UI 壳 | `lib/plugins/moments/`（13 文件） | 三屏一页签 + 贴纸/投稿面板 + 桌面小组件 + l10n |
| 数据层 | `lib/plugins/openai/moments/` | 模型 `MomentPost` / `AgentAsset`；服务 `MomentsService` / `AgentAssetsService` / `ImageGenService` |
| AI 工具 | `lib/plugins/openai/moments_js_api.dart` | 生图、发朋友圈、查资产图（挂在 openai 插件） |

moments 最初（2026-10-05）作为 openai 插件内的子系统诞生，后独立成插件承接 skygram 参考稿 UI；openai 侧旧 screens/widgets 仍保留（agent 侧入口）。

## 页面结构

- `screens/moments_home_screen.dart` 宿主页：顶部统一导航栏（super_cupertino `PersistentNavigationBar` 静态组件），底部圆盘 dock 即 tabs，`LazyIndexedStack` 切换三页，不跳路由。
- `screens/moments_feed_screen.dart` 动态流（tab 0）：发帖、刷新（暴露 `MomentsFeedScreenState` 供 GlobalKey 调用）。
- `screens/moments_memories_screen.dart` 回忆页（tab 1）：全部动态的图片按标签筛选，双列便签瀑布流归档。
- `screens/moments_profile_screen.dart` 个人主页：push 子页（自带返回顶栏），`agentId` 参数区分「我」与某个 agent。

## 核心组件

- `widgets/moments_compose_sheet.dart`：发布投稿面板（内容体，由通用 `SmoothBottomSheet` 提供标题/把手/关闭）。
- `widgets/moment_stickers.dart`：头像旁 SVG 刻贴纸（4 枚 die-cut 贴纸，参考稿 sticker-chili 等）。
- `widgets/moments_shared.dart`：共享 UI，如 `InterestPill` 手绘软糖标签。
- `home_widgets/register_icon_widget.dart`：注册 1x1 图标小组件。
