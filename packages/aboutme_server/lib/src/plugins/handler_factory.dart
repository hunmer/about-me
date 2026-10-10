import 'package:aboutme_data_sdk/io.dart';

import 'crud.dart';
import 'handlers/activity.dart';
import 'handlers/bill.dart';
import 'handlers/calendar.dart';
import 'handlers/chat.dart';
import 'handlers/checkin.dart';
import 'handlers/contact.dart';
import 'handlers/day.dart';
import 'handlers/diary.dart';
import 'handlers/goods.dart';
import 'handlers/notes.dart';
import 'handlers/todo.dart';
import 'handlers/tracker.dart';
import 'types.dart';

/// 为指定插件创建处理器（专用 handler 或通用 CRUD），
/// 与 nodejs factory.ts 的分发一致。
PluginHandlers createHandlersForPlugin(
  PluginDataStore store,
  String pluginId,
) {
  switch (pluginId) {
    case 'chat':
      return createChatHandlers(store);
    case 'notes':
      return createNotesHandlers(store);
    case 'bill':
      return createBillHandlers(store);
    case 'todo':
      return createTodoHandlers(store);
    case 'diary':
      return createDiaryHandlers(store);
    case 'goods':
      return createGoodsHandlers(store);
    case 'activity':
      return createActivityHandlers(store);
    case 'checkin':
      return createCheckinHandlers(store);
    case 'tracker':
      return createTrackerHandlers(store);
    case 'calendar':
      return createCalendarHandlers(store);
    case 'contact':
      return createContactHandlers(store);
    case 'day':
      return createDayHandlers(store);
    default:
      return createCrudHandlers(store, pluginId, 'items');
  }
}
