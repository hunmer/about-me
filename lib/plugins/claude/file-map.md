# 插件目录速查

> 所属：`lib/plugins/` · [返回索引](../CLAUDE.md)
> `h` = home_widgets，`js` = `<id>_js_api.dart`（part），`ds` = `<id>_data_selectors.dart`（part），`rh` = `<id>_route_handler.dart`，`sm` = 引用 shared_models（UseCase/Repository）。2026-10-20 起全部 29 个插件均有 `l10n/`（zh/en 翻译）。

| 插件 | 子目录结构 | 标记 |
|------|-----------|------|
| chat | screens/{channel_list,chat_screen,timeline,tags} · models · repositories · services · home_widgets · events · l10n · utils | h js ds sm |
| agent_chat | controllers/{chat_controller/managers×7,conversation_controller} · screens/{chat_screen,conversation_list_screen,tool_management_screen,tool_template_screen,...} · services（16+）· models · repositories · home_widgets · l10n | h ds sm |
| openai | controllers · handlers · models · repositories · screens · services · widgets · home_widgets · **aliveness**（活人感子系统）· **moments**（朋友圈数据层：models/screens/services/widgets）· l10n + `moments_js_api.dart` | h js ds sm |
| moments | screens/{home(三页签),feed,memories,profile} · widgets（compose_sheet/stickers/shared）· home_widgets · l10n | rh h（数据层在 openai） |
| activity | screens · models · repositories · services · widgets · h | h js sm |
| habits | controllers/{timer,completion_record,habit,skill} · models · repositories · screens · services · utils · widgets · h | h js ds rh sm |
| goods | dialogs · models · repositories · screens · widgets · h | h js ds rh sm |
| notes | controllers · data · models · repositories · screens · utils · widgets · h | h js ds sm |
| store | controllers · events · models · repositories · screens · widgets · h | h js sm |
| bill | controls（非 controllers）· data · models · repositories · screens · services · widgets · h | h js sm |
| todo | controllers · models · repositories · screens · services · views · widgets · h | h js ds rh sm |
| calendar_album | controllers · models · repositories · screens · utils · widgets · h | h js ds sm |
| webview | models · screens · services · widgets · h · assets（test_jsbridge.html） | h js |
| checkin | controllers · models · repositories · screens · widgets · h | h js rh sm |
| tracker | controllers · models · repositories · screens · utils · widgets · h | h js ds rh sm |
| nodes | controllers · models/{node,notebook} · repositories · screens · widgets · h | h js sm |
| scripts_center | models · screens · services（script_loader/manager/executor/store_manager/download_manager）· widgets · h | h ds |
| contact | controllers · models · repositories · screens · utils · widgets · h | h js sm |
| day | controllers · models · repositories · screens · utils · widgets · h | h js sm |
| calendar | controllers · models · pages · repositories · screens · services · utils · widgets · h | h js sm |
| timer | models · views（非 screens）· services · storage · repositories · h | h js sm |
| diary | models · repositories · screens · utils · widgets · h | h js sm |
| tts | models · services · screens · widgets · h | h |
| nfc | card_handlers/{read,custom_write,checkin,goods_usage,habit_timer,tracker_progress} · models · widgets · nfc_controller | h |
| database | controllers · models · services · widgets · repositories | js sm（h 为根级单文件） |
| reminder | screens/{list,form} · services · models | 无路由/无 h/无 js |
| live2d | l10n · models · screens/{live2d_main,live2d_settings,online_models} | 路由 `/live2d`（设置页）/无 h/无 js |
| media_log | models · screens · widgets · home_widgets · l10n | h sm（2026-10 新增，详见独立文档） |
| achievement | definitions · events · services · widgets · home_widgets · l10n | 无路由/无 js（2026-10 新增，详见独立文档） |

## 根级文件

- `base_plugin.dart` — BasePlugin 基类（StorageManager 懒获取）
- `plugin_widget.dart` — InheritedWidget，Widget 树传递插件实例

## 插件内自带文档（改代码前先看）

- `JS_API.md` / `JS_API_DOC.md` / `JS_API_GUIDE.md`：notes、store、todo、timer、tracker
- `HTTP_SERVER_GUIDE.md`（webview）、`MIGRATION_REPORT.md`（database）、`NOTIFICATION_README.md`（activity）
- chat/agent_chat/media_log/achievement/moments 的 `CLAUDE.md` + `claude/`
