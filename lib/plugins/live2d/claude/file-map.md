# live2d 插件 · 文件地图

> 所属：lib/plugins/live2d · [返回索引](../CLAUDE.md)

```text
lib/plugins/live2d/
├── live2d_plugin.dart                  # 主类 Live2DPlugin：存档列表(archives.json)/选中存档/sendMessage/TTS/cleanReply
├── models/live2d_archive.dart          # Live2DArchive 数据类
├── screens/
│   ├── live2d_main_screen.dart         # 存档卡片网格（搜索 + 按模型筛选）
│   ├── live2d_settings_screen.dart     # 全局设置：存档切换/自动朗读/TTS 选择/打字速度/预览动作播放
│   └── live2d_archive_form_screen.dart # 存档编辑：封面裁剪/名称/内置模型/在线模型页/绑定 Agent
└── l10n/                               # zh_CN / en_US / ja_JP 翻译（4 文件）
```

## 相关外部文件

- 渲染视图：`lib/screens/jelly_home/widgets/jelly_live2d.dart`（约 1180 行，含内置模型定义与 `modelDefinitionForArchive`）
- 在线模型目录/浏览页：`lib/screens/jelly_home/live2d_online_models.dart`、`live2d_online_model_page.dart`
- 路由：`lib/screens/routing/routes/plugin_common_routes.dart:84`（`/live2d` → Live2DSettingsScreen）
- 注册：`lib/core/builtin_plugins.dart:58`
- 测试：`test/jelly_live2d_crop_region_test.dart`（裁剪区域数学与持久化回退）、`test/live2d_online_models_test.dart`（目录解析/动作截断纯函数）
