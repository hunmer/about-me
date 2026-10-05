# openai 插件 · 文件地图

> 所属：lib/plugins/openai · [返回索引](../CLAUDE.md)

共 104 个 Dart 文件（2026-10-05 统计）。

```text
lib/plugins/openai/
├── openai_plugin.dart            # 主类（初始化链、JS API、主视图）
├── openai_js_api.dart            # getAgents/getAgent/sendMessage/search_memory/getProviders/testProvider
├── moments_js_api.dart           # generate_image/post_moment/list_agent_assets
├── openai_data_selectors.dart    # openai.agent / openai.prompt 数据选择器
├── sample_data.dart、README_SAMPLE_DATA.md
├── controllers/                  # agent/服务商/模型/工具应用/执行历史控制器
├── handlers/chat_event_handler.dart  # chat @AI 消息分流（活人感开关）
├── repositories/client_openai_repository.dart  # → OpenAIUseCase（接口在 shared_models）
├── models/                       # ai_agent(含 alivenessConfig)/service_provider/prompt_preset/tool_app/...
├── services/                     # request_service(agentlib 传输)/file_processing/市场/资源/soul_forge/预设
├── screens/                      # agent 列表/编辑/市场/资源商店、服务商与模型、预设、插件设置
├── widgets/                      # agent 卡片/网格/抽屉/详情弹窗、市场组件
├── home_widgets/                 # 主屏小组件注册（图标 + 统计概览）
├── l10n/                         # 中/英/日
├── aliveness/                    # ★ 活人感子系统（23 文件，2026-10-04）
│   ├── aliveness_orchestrator.dart   # 编排器（缓冲→8 步 flush）
│   ├── services/                 # store/memory/decision/behavior_executor/proactive/voice/schedule/state/keepalive/chat_import（11 个）
│   ├── channels/                 # chat_aliveness_channel / agent_chat_aliveness_channel（宿主适配器）
│   ├── models/                   # agent_state / aliveness_config / memory_fragment
│   ├── data/question_pool.dart   # 亲密度分层探索问题池
│   ├── screens/                  # 记忆管理 / 决策日志 / AI 日程 / 聊天导入
│   └── widgets/                  # aliveness_settings_section / jev_settings_dialog
└── moments/                      # ★ 朋友圈子系统（10 文件，2026-10-05）
    ├── models/                   # moment_post / agent_asset
    ├── services/                 # moments_service / agent_assets_service / image_gen_service
    ├── screens/moments_screen.dart、photo_viewer_screen.dart
    └── widgets/                  # moment_card / agent_avatar
```

相关测试（仓库根 `test/`）：aliveness_logic_test.dart（591 行纯逻辑单测 9 组）、aliveness_e2e_test.dart（真实 API 验收，含硬编码 Key）。
