# Agent 朋友圈 + 资产图管理 + 生图工具

## 复用结论（探索已确认）
- **生图**：`ScriptsCenterPlugin.instance.scriptExecutor.execute('ai_image', args: {...})` → `result['data']['localPaths']`；ai_image 脚本已支持图生图（`image` 参数传本地路径数组）；用户 apiKey 已配在 `configs/scripts_center/ai_image_config.json`
- **发图片消息**：照抄 `voice_service.dart:155-191` 模式 —— `ChatMessage + FileAttachment.image(filePath: 绝对路径)`，经 `AgentChatPlugin.instance.conversationController.messageService.addMessage` 写入（无需 ChatController）
- **工具系统**：两阶段 Markdown+JS；新工具 = `openai_plugin.dart` 的 `defineJSAPI()` 注册 Dart 函数 + `lib/plugins/agent_chat/tools/openai.json` 加描述条目（ToolConfigManager 自动补拷新 json 字段）
- **UI**：feed 参考 chat timeline 卡片；全屏看图用 PhotoView（calendar_album 已有）；选图用 `ImagePickerDialog`；图片渲染 `ImageUtils.getAbsolutePath` + `Image.file`

## 新增文件 `lib/plugins/openai/moments/`

**models/**
- `moment_post.dart`：`MomentPost{id, agentId, text, images[List<String>相对路径], createdAt, source('agent'|'manual')}`
- `agent_asset.dart`：`AgentAsset{id, name, prompt(占位模板), path(相对路径,null=未生成), createdAt}`

**services/**
- `moments_service.dart`（ChangeNotifier 单例）：
  - 帖子存 `openai/moments/posts.json`（新帖插头部，上限 500）
  - `currentAgentId`/`currentConversationId` 静态上下文（工具执行时取）
  - `sendImageToChat()`：发纯图 AI 消息到当前会话
- `agent_assets_service.dart`：per-agent `openai/moments/<agentId>/assets.json`；首次打开初始化预置占位【三视图】【房间照片】（含生成提示词模板）；CRUD
- `image_gen_service.dart`：`generate({prompt, refImagePaths, aspectRatio})` 调 ai_image（args 传 `showUi:false`）→ localPaths 拷贝到 `openai/moments/images/` 返回相对路径；插件未启用/未配 key 时返回友好错误

**screens/**
- `moments_screen.dart`：ins 风单列 feed（头像+名字+时间+文案+图片区）；单图大图、多图 3 列网格；点图全屏（PhotoView）；长按删除；监听 ChangeNotifier；空态引导
- `agent_assets_screen.dart`：3 列网格资产卡（已生成=图+名；占位=虚线框+名+"生成"角标）；「+」添加：上传照片（ImagePickerDialog+命名）/ 新建占位（名称+提示词）；点资产弹操作：生成图片（prompt 预填模板+自动附加 agent 人设描述）、图生图（以此图为参考生成，结果可存为新资产/替换原图）、重命名、删除；生成中转圈

**widgets/**
- `moment_card.dart`：帖子卡片（头像渲染参考 `agent_card.dart:112` 的 avatarUrl/icon 兜底逻辑）

## 修改文件
1. `lib/plugins/agent_chat/tools/openai.json`：加 3 个工具（带 examples 引导 LLM 配图时用 `refAssetNames` 引用资产图保持形象一致）：
   - `generate_image{prompt必填, refAssetNames?, aspectRatio?, sendToChat默认true}`
   - `post_moment{text必填, imagePrompt?(自动生图配图), refAssetNames?}`
   - `list_agent_assets{}` → 返回 `[{name, hasImage}]`
2. `lib/plugins/openai/openai_plugin.dart` + 新 part `moments_js_api.dart`：defineJSAPI 注册 3 个方法；agentId 解析顺序 `params → MomentsService.currentAgentId → MemoryService.currentAgentId`
3. `lib/plugins/agent_chat/controllers/chat_controller.dart`：`initialize()` 设置 currentConversationId/currentAgentId
4. `lib/plugins/agent_chat/controllers/managers/agent_chain_executor.dart`：`_handleSecondPhaseComplete` 开头更新 currentAgentId（多 agent 链准确）
5. `lib/plugins/agent_chat/screens/chat_screen/chat_screen.dart`：AppBar DSPopover 菜单加「朋友圈」入口
6. `lib/plugins/openai/screens/agent_edit_screen.dart`：AlivenessSettingsSection 后加「资产图库」入口 Section
7. `assets/scripts/ai_image/script.js` + `online/scripts/ai_image/`（两份同步，版本 1.3.2→1.3.3）：支持 `args.showUi` 布尔值覆盖 config，后台调用不弹结果页

## 范围决策（用户未答，按推荐执行）
- 第一版不做点赞/评论（后续可加）
- `generate_image` 默认发送图片到当前聊天（LLM 可传 `sendToChat:false` 只生成不发）

## 验证
- `flutter analyze lib/plugins/openai lib/plugins/agent_chat` + 现有 aliveness 测试不回归
- 用户手动验收（遵循偏好，不自动跑 app）

## 验收步骤（交付后给用户）
1. 聊天页右上菜单 →「朋友圈」打开动态流
2. agent 编辑页 →「资产图库」→ 点【三视图】占位 → 生成（需脚本中心 ai_image 已配 key）
3. 对 agent 说「帮我生成一张xxx图」→ 图片消息出现在聊天
4. 对 agent 说「发一条朋友圈，配一张你在房间的照片」→ 朋友圈出现新帖