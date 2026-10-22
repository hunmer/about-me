import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/plugins/achievement/achievement_plugin.dart';
import 'package:aboutme/plugins/activity/activity_plugin.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/bill/bill_plugin.dart';
import 'package:aboutme/plugins/calendar/calendar_plugin.dart';
import 'package:aboutme/plugins/calendar_album/calendar_album_plugin.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/checkin/checkin_plugin.dart';
import 'package:aboutme/plugins/contact/contact_plugin.dart';
import 'package:aboutme/plugins/database/database_plugin.dart';
import 'package:aboutme/plugins/day/day_plugin.dart';
import 'package:aboutme/plugins/diary/diary_plugin.dart';
import 'package:aboutme/plugins/goods/goods_plugin.dart';
import 'package:aboutme/plugins/habits/habits_plugin.dart';
import 'package:aboutme/plugins/nfc/nfc_plugin.dart';
import 'package:aboutme/plugins/nodes/nodes_plugin.dart';
import 'package:aboutme/plugins/notes/notes_plugin.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/reminder/reminder_plugin.dart';
import 'package:aboutme/plugins/scripts_center/scripts_center_plugin.dart';
import 'package:aboutme/plugins/store/store_plugin.dart';
import 'package:aboutme/plugins/timer/timer_plugin.dart';
import 'package:aboutme/plugins/todo/todo_plugin.dart';
import 'package:aboutme/plugins/tracker/tracker_plugin.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';
import 'package:aboutme/plugins/webview/webview_plugin.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/media_log/media_log_plugin.dart';
import 'package:aboutme/plugins/moments/moments_plugin.dart';
import 'package:aboutme/plugins/toolbox/toolbox_plugin.dart';

typedef PluginBuilder = PluginBase Function();

class BuiltinPlugins {
  static final List<PluginBuilder> _builders = [
    () => ChatPlugin(),
    () => OpenAIPlugin(),
    () => AgentChatPlugin(),
    () => DiaryPlugin(),
    () => ActivityPlugin(),
    () => CheckinPlugin(),
    () => ContactPlugin(),
    () => HabitsPlugin(),
    () => DatabasePlugin(),
    () => TimerPlugin(),
    () => TodoPlugin(),
    () => DayPlugin(),
    () => TrackerPlugin(),
    () => StorePlugin(),
    () => NodesPlugin(),
    () => NotesPlugin(),
    () => GoodsPlugin(),
    () => BillPlugin(),
    () => CalendarPlugin(),
    () => CalendarAlbumPlugin(),
    () => ScriptsCenterPlugin(),
    () => TTSPlugin(),
    () => NfcPlugin(),
    () => WebViewPlugin(),
    () => ReminderPlugin(),
    () => Live2DPlugin(),
    () => MediaLogPlugin(),
    () => MomentsPlugin(),
    () => AchievementPlugin(),
    () => ToolboxPlugin(),
  ];

  static List<PluginBase> createAll() {
    return _builders.map((builder) => builder()).toList();
  }
}
