import 'plugin_data.dart';
import 'crud.dart';
import 'handlers/activity.dart';
import 'handlers/agent_chat.dart';
import 'handlers/assets.dart';
import 'handlers/bill.dart';
import 'handlers/calendar.dart';
import 'handlers/calendar_album.dart';
import 'handlers/chat.dart';
import 'handlers/checkin.dart';
import 'handlers/contact.dart';
import 'handlers/day.dart';
import 'handlers/database.dart';
import 'handlers/diary.dart';
import 'handlers/goods.dart';
import 'handlers/habits.dart';
import 'handlers/media_log.dart';
import 'handlers/notes.dart';
import 'handlers/nodes.dart';
import 'handlers/store.dart';
import 'handlers/todo.dart';
import 'handlers/tracker.dart';
import 'types.dart';

/// 为指定插件创建处理器（专用 handler 或通用 CRUD）。
/// handler 捕获 [data] 后端实例；同一套逻辑在客户端与服务端执行。
PluginHandlers createHandlersForPlugin(PluginData data, String pluginId) {
  switch (pluginId) {
    case 'assets':
      return createAssetHandlers(data);
    case 'chat':
      return createChatHandlers(data);
    case 'notes':
      return createNotesHandlers(data);
    case 'nodes':
      return createNodesHandlers(data);
    case 'bill':
      return createBillHandlers(data);
    case 'todo':
      return createTodoHandlers(data);
    case 'diary':
      return createDiaryHandlers(data);
    case 'goods':
      return createGoodsHandlers(data);
    case 'activity':
      return createActivityHandlers(data);
    case 'checkin':
      return createCheckinHandlers(data);
    case 'tracker':
      return createTrackerHandlers(data);
    case 'calendar':
      return createCalendarHandlers(data);
    case 'calendar_album':
      return createCalendarAlbumHandlers(data);
    case 'contact':
      return createContactHandlers(data);
    case 'day':
      return createDayHandlers(data);
    case 'database':
      return createDatabaseHandlers(data);
    case 'habits':
      return createHabitsHandlers(data);
    case 'agent_chat':
      return createAgentChatHandlers(data);
    case 'store':
      return createStoreHandlers(data);
    case 'media_log':
      return createMediaLogHandlers(data);
    default:
      return createCrudHandlers(data, pluginId, 'items');
  }
}
