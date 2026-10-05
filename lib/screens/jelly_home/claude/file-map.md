# jelly_home · 文件地图

> 所属：lib/screens/jelly_home · [返回索引](../CLAUDE.md)

共 17 个 Dart 文件。

```text
lib/screens/jelly_home/
├── jelly_home_screen.dart          # 主屏：四页签 IndexedStack；_CottageTab 小屋布局；Live2DChatInput
├── companion_controller.dart       # 陪伴数值 ChangeNotifier（离线结算 + SharedPreferences）
├── live2d_online_models.dart       # 模型/动作数据类 + Live2DOnlineCatalog（jsdelivr CDN 目录解析）
├── live2d_online_model_page.dart   # 在线模型浏览页（搜索/分类/刷新，pop 回传定义）
└── widgets/
    ├── jelly_bottom_nav.dart       # 悬浮底部导航（JellyTab: cottage/schedule/board/mine）
    ├── jelly_live2d.dart           # ★ 核心角色视图（约 1180 行）：加载/切换/hit area/控制面板/内置模型定义
    ├── jelly_live2d_crop_dialog.dart    # crop_your_image 裁剪对话框
    ├── jelly_live2d_crop_region.dart    # 归一化裁剪区域值对象（zoom/translate/encode/parse）
    ├── jelly_speech_bubble.dart    # 打字机气泡（Path.union 一次绘制）
    ├── jelly_companion_card.dart   # 陪伴状态卡（2×2 数值格）
    ├── jelly_profile_card.dart     # 资料卡（头像/昵称/等级/经验）
    ├── jelly_stat_card.dart        # 顶部统计卡（今日待办/连续打卡/本月记录）
    ├── jelly_daily_tasks_card.dart # 每日任务卡（无引用，预留）
    ├── jelly_growth_card.dart      # 成长卡（无引用，预留）
    ├── jelly_mood_card.dart        # 今日心情卡（无引用，预留）
    ├── jelly_quick_action.dart     # 快捷操作圆钮（无引用，预留）
    └── jelly_store_banner.dart     # 插件商店横幅（无引用，预留）
```

## 相关外部

- 路由注册：`lib/screens/routing/routes/jelly_home_routes.dart`（`/jelly_home`）
- 页签内容：`lib/screens/home_screen/`（日程/看板）、`lib/screens/settings_screen/`（我的）
- live2d 插件（存档与设置）：`lib/plugins/live2d/`
