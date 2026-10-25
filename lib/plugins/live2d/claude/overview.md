# live2d 插件 · 架构总览

> 所属：lib/plugins/live2d · [返回索引](../CLAUDE.md)

## 定位

Live2D 桌宠插件（9 个 Dart 文件）：管理 Live2D **存档**（Archive = 模型 + 绑定 Agent + 偏好）、全局播报设置，并提供对话链路（sendMessage → 清洗回复 → TTS）。它是"数据与设置层"；**渲染视图层不在本插件**，而在 `lib/screens/jelly_home/`（JellyLive2D）——本插件三个 screen 全部复用 jelly_home 的视图组件，形成双向依赖。

## 关键设计

- **存档模型**：`Live2DArchive`（id/name/modelLabel/modelDir/modelFile/agentId/coverPath）只存 Agent id，用时按 id 取最新配置——换 Agent 配置不用改存档。
- **模型来源**：内置 Mao（jelly_live2d_models.dart，对应根 pubspec 的 assets/models/mao/）→ 在线模型（jsdelivr CDN 的 Eikanya/Live2d-model 仓库，`Live2DOnlineCatalog` 解析目录 JSON）→ zip 压缩包导入（`Live2DZipImport` 解压到应用支持目录 live2d_models/，记录持久化在 settings.importedModels、由本地模型库页 `Live2DImportedModelsScreen` 管理）→ 存档自定义。
- **渲染依赖**：`live2d_flutter` 包（path 依赖 `../flutter_live2d-main`，仓库外本地路径），`Live2DViewController.loadModel(modelDir, modelFileName)`。
- **对话复用 agent_chat**：临时会话路由名 `live2d:{archiveId}`、分组 `Live2DPlugin.fixedGroup`，与 jelly_home 的聊天输入共用。
- **回复清洗**：`cleanReply` 去除 `<think>` 思考块与坏 UTF-16 码元；`speakReply` 走 TTS 自动播报。

## 接入面

无 JS API、无 home_widgets、无插件内路由声明。`/live2d` 路由在外部注册（`lib/screens/routing/routes/plugin_common_routes.dart:84`，**指向设置页**而非主列表页）；主列表经 `PluginManager.openPlugin`（`/plugin/live2d`）打开。
