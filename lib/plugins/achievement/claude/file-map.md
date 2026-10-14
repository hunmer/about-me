# achievement 插件 · 文件地图

> 所属：lib/plugins/achievement · [返回索引](../CLAUDE.md)

```text
lib/plugins/achievement/
├── achievement_plugin.dart               # 主类 AchievementPlugin：初始化 controller+resolver、订阅升级事件转弹窗、主视图/插件卡片
├── controllers/
│   └── achievement_controller.dart       # AchievementController：进度存储 + 事件/快照双通道结算 + 升级发积分 + AchievementProgress 模型
├── data/
│   └── achievement_definitions.dart      # 静态表：5 分类 / 74 条定义 / kAchievementById / kPendingAchievementIds(6)
├── models/
│   └── achievement_definition.dart       # AchievementDefinition / AchievementLevels(等级视觉与奖励) / AchievementLevelUpEventArgs
├── stats/
│   ├── achievement_stats_resolver.dart   # 快照结算器：打开成就页时全量 resolveAll（幂等）+ A59 统一计时器事件过滤
│   └── achievement_stats_providers.dart  # buildStatProviders()：57 个成就编号 → (来源插件, 取数函数)，导入 28 个插件取数入口
├── screens/
│   ├── achievement_gallery_screen.dart   # 主界面：概览卡 + 底部双 tab（initState 触发全量快照结算）
│   ├── achievement_in_progress_screen.dart # Tab 正在解锁：按距下一级进度降序
│   ├── achievement_unlocked_screen.dart  # Tab 已解锁：按最近达成倒序，双列徽章墙
│   └── achievement_detail_screen.dart    # 详情页：大徽章 + 达成信息 + 下一里程碑 + 各等级明细
├── widgets/
│   ├── achievement_badge.dart            # 徽章：图标贴纸 + 等级边框色 + Lv 角标（0 = 灰化半透明）
│   └── achievement_unlock_dialog.dart    # 队列式全局达成弹窗（navigatorKey 根弹窗，4s 自动关，lottie 动画）
├── home_widgets/
│   └── home_widgets.dart                 # 注册 achievement_overview 主页小组件（进度环 + 积分 + 最近达成）
└── l10n/
    ├── achievement_translations_zh.dart  # zh_CN（'achievement_*' 键）
    └── achievement_translations_en.dart  # en_US
```

## 相关外部文件

- 注册：`lib/core/builtin_plugins.dart:62`（`AchievementPlugin()`，列于末尾——发积分依赖 store 先就绪）
- 设计文档：`docs/ACHIEVEMENT_SYSTEM_PLAN.md`（定义表与之一一对应）
- 积分发放：`lib/plugins/store/store_plugin.dart`（id `store_plugin`：`controller.addPoints` / `pointAwardSettings` / 积分流水）
- 事件总线：`lib/core/event/event_manager.dart`（EventManager / EventArgs / Value）
- 图标资产：`assets/achievements/A01~A74.webp`（已核实 74 个文件）
- 快照取数依赖 28 个插件（stats_providers.dart 头部 import：chat、agent_chat、openai、live2d、diary、activity、habits、checkin、todo、notes、nodes、day、calendar、calendar_album、reminder、bill、goods、store、contact、tracker、database、timer、tts、webview、scripts_center 等）
- 主页小组件注册：`lib/screens/home_screen/managers/home_widget_registry.dart`
