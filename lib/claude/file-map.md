# 文件地图

> 所属：lib/ 应用代码层 · [返回索引](../CLAUDE.md)

## 顶层文件

| 文件 | 说明 |
|------|------|
| `main.dart` | 应用入口 |
| `firebase_options.dart` | Firebase 配置（生成物，勿手改） |

## core/ 核心层

| 路径 | 说明 |
|------|------|
| `plugin_manager.dart` / `plugin_base.dart` / `builtin_plugins.dart` | 插件系统三件套 |
| `app_initializer.dart` | 启动初始化与 `AppStartupState` |
| `config_manager.dart` | 应用/插件配置 |
| `storage/` + `storage_service.dart` | 存储抽象（IO / IndexedDB） |
| `event/` | 全局事件总线 |
| `js_bridge/` | flutter_js 封装与双向通信 |
| `floating_ball/` · `action/` | 悬浮球、自定义动作 |
| `api_forwarding/` | API 转发客户端（配 api_forwarding_server） |
| `app_widgets/` | 桌面小组件宿主（home_widget_service、floating_ball_service） |
| `route/` · `routing/` | 路由历史、插件路由处理 |
| `services/` | FCM、日志、剪贴板、快捷方式、统一计时器、plugin_widget_sync_helper、toast、文件监听同步等 |
| `notification_controller.dart` · `data_migration_controller.dart` · `theme_controller.dart` · `global_flags.dart` · `watch_connectivity_manager.dart` | 各专职控制器 |
| `analysis/` · `data_filter/` · `l10n/` · `navigation/` · `utils/` · `widgets/` · `app_widgets/` | 其余子系统 |
| 文档 | [core/CLAUDE.md](../core/CLAUDE.md)（旧版格式） |

## plugins/ 插件层（25 个）

| 插件 | 入口 | 文档（旧版格式） |
|------|------|------|
| activity | `activity/activity_plugin.dart` | [activity/CLAUDE.md](../plugins/activity/CLAUDE.md) |
| agent_chat | `agent_chat/agent_chat_plugin.dart` | [agent_chat/CLAUDE.md](../plugins/agent_chat/CLAUDE.md) |
| bill | `bill/bill_plugin.dart` | [bill/CLAUDE.md](../plugins/bill/CLAUDE.md) |
| calendar | `calendar/calendar_plugin.dart` | [calendar/CLAUDE.md](../plugins/calendar/CLAUDE.md) |
| calendar_album | `calendar_album/calendar_album_plugin.dart` | [calendar_album/CLAUDE.md](../plugins/calendar_album/CLAUDE.md) |
| chat | `chat/chat_plugin.dart` | [chat/CLAUDE.md](../plugins/chat/CLAUDE.md) |
| checkin | `checkin/checkin_plugin.dart` | [checkin/CLAUDE.md](../plugins/checkin/CLAUDE.md) |
| contact | `contact/contact_plugin.dart` | [contact/CLAUDE.md](../plugins/contact/CLAUDE.md) |
| database | `database/database_plugin.dart` | [database/CLAUDE.md](../plugins/database/CLAUDE.md) |
| day | `day/day_plugin.dart` | [day/CLAUDE.md](../plugins/day/CLAUDE.md) |
| diary | `diary/diary_plugin.dart` | [diary/CLAUDE.md](../plugins/diary/CLAUDE.md) |
| goods | `goods/goods_plugin.dart` | [goods/CLAUDE.md](../plugins/goods/CLAUDE.md) |
| habits | `habits/habits_plugin.dart` | [habits/CLAUDE.md](../plugins/habits/CLAUDE.md) |
| nfc | `nfc/nfc_plugin.dart` | [nfc/CLAUDE.md](../plugins/nfc/CLAUDE.md) |
| nodes | `nodes/nodes_plugin.dart` | [nodes/CLAUDE.md](../plugins/nodes/CLAUDE.md) |
| notes | `notes/notes_plugin.dart` | [notes/CLAUDE.md](../plugins/notes/CLAUDE.md) |
| openai | `openai/openai_plugin.dart` | [openai/CLAUDE.md](../plugins/openai/CLAUDE.md) |
| reminder | `reminder/reminder_plugin.dart` | [reminder/CLAUDE.md](../plugins/reminder/CLAUDE.md) |
| scripts_center | `scripts_center/scripts_center_plugin.dart` | [scripts_center/CLAUDE.md](../plugins/scripts_center/CLAUDE.md) |
| store | `store/store_plugin.dart` | [store/CLAUDE.md](../plugins/store/CLAUDE.md) |
| timer | `timer/timer_plugin.dart` | [timer/CLAUDE.md](../plugins/timer/CLAUDE.md) |
| todo | `todo/todo_plugin.dart` | [todo/CLAUDE.md](../plugins/todo/CLAUDE.md) |
| tracker | `tracker/tracker_plugin.dart` | [tracker/CLAUDE.md](../plugins/tracker/CLAUDE.md) |
| tts | `tts/tts_plugin.dart` | [tts/CLAUDE.md](../plugins/tts/CLAUDE.md) |
| webview | `webview/webview_plugin.dart` | [webview/CLAUDE.md](../plugins/webview/CLAUDE.md) |

根级公共文件：`plugins/base_plugin.dart`、`plugins/plugin_widget.dart`。

## screens/ 界面层

| 路径 | 说明 |
|------|------|
| `route.dart` + `routing/` | 路由汇总与注册表 |
| `home_screen/` · `settings_screen/` · `about_screen/` · `log_screen/` | 主要页面 |
| `js_console/` | JS 控制台（examples 随 assets 打包） |
| `widgets_gallery/` · `pages/` | 组件展示廊、通用页面 |
| `*_test` / `test_screens`（intent_test、notification_test、form_fields_test、data_selector_test、json_dynamic_test、toast_test） | 测试/演示页面 |
| `floating_widget_screen/` · `l10n/` | 悬浮组件界面、翻译 |
| 文档 | [screens/CLAUDE.md](../screens/CLAUDE.md)、[home_screen](../screens/home_screen/CLAUDE.md)、[settings_screen](../screens/settings_screen/CLAUDE.md)、[js_console](../screens/js_console/CLAUDE.md)（旧版格式） |

## widgets/ 组件层

| 路径 | 说明 |
|------|------|
| `aboutme_editor/` | Quill 富文本编辑器封装 |
| `enhanced_calendar/` · `aboutme_sf_calendar/` | 日历组件 |
| `form_fields/` · `common/` · `file_preview/` · `data_selector_sheet/` · `l10n/` | 表单字段、公共组件、文件预览、数据选择器 |
| 根级单文件 | adaptive_image、app_bar_widget、app_drawer、custom_dialog、folder_breadcrumbs、group_selector_dialog 等 |
| 文档 | [widgets/CLAUDE.md](../widgets/CLAUDE.md)（旧版格式） |
