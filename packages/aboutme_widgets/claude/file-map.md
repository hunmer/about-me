# 文件地图

> 所属：packages/aboutme_widgets · [返回索引](../CLAUDE.md)

## lib/（Dart 侧，5 文件）

| 文件 | 说明 |
|------|------|
| `aboutme_widgets.dart` | `MyWidgetManager` 全部 API + `_androidProviders` 映射 |
| `aboutme_widgets_platform_interface.dart` / `aboutme_widgets_method_channel.dart` | 插件平台接口模板（MethodChannel `aboutme_widgets`） |
| `models/plugin_widget_data.dart` | 插件小组件共享数据模型（JSON 载荷） |
| `models/widget_stat_item.dart` | 统计项模型 |

## android/src/main/kotlin/github/hunmer/（Kotlin 侧）

| 路径 | 说明 |
|------|------|
| `aboutme_widgets/AboutmeWidgetsPlugin.kt` | 插件注册入口 |
| `aboutme/widgets/BasePluginWidgetProvider.kt` | 全部插件小组件的基类 |
| `aboutme/widgets/providers/*WidgetProvider.kt`（约 40 个） | 各小组件 Provider（1x1 / 2x1 / 专用 / 快速） |
| `aboutme/widgets/providers/*RemoteViewsFactory.kt` + `*WidgetService.kt` | 列表型小组件的 RemoteViews 数据源（TodoList、CalendarTodayList、BillShortcuts） |
| `res/`、`AndroidManifest.xml` | 小组件布局与声明（未深扫） |

## ios/

| 路径 | 说明 |
|------|------|
| `Classes/AboutmeWidgetsPlugin.swift`（19 行） | 插件注册壳 |
| `aboutme_widgets.podspec`、`Resources/PrivacyInfo.xcprivacy` | CocoaPods 清单与隐私清单 |

## 其他

- `example/`：插件示例工程（android/ios 脚手架）。
- `test/`：插件模板测试。
- 参考文档：`docs/aboutme_widgets.md`、`docs/WIDGET_ARCHITECTURE_UNIFIED.md`、`docs/WIDGET_IMPLEMENTATION_GUIDE.md`、`docs/TODO_QUADRANT_WIDGET_IMPLEMENTATION.md`、`docs/CHECKIN_WIDGET_CONFIG.md`。
