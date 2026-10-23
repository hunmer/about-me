import 'dart:convert';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';

/// MCP 工具定义与分发（移植自 nodejs mcp/tools.ts + client.ts + server.ts）。

Map<String, dynamic> _schema(
  Map<String, dynamic> properties, [
  List<String>? required,
]) => {
  'type': 'object',
  'properties': properties,
  if (required != null) 'required': required,
};

Map<String, dynamic> _prop(String type, [String? description]) => {
  'type': type,
  if (description != null) 'description': description,
};

Map<String, dynamic> _arrayProp([String? description]) => {
  'type': 'array',
  'items': {'type': 'string'},
  if (description != null) 'description': description,
};

/// 工具定义列表（与 nodejs getToolDefinitions 一致）。
final List<Map<String, dynamic>> toolDefinitions = [
  // Chat
  {'name': 'aboutme_chat_getChannels', 'description': '获取聊天频道列表', 'inputSchema': _schema({'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')})},
  {'name': 'aboutme_chat_createChannel', 'description': '创建新的聊天频道', 'inputSchema': _schema({'name': _prop('string', '频道名称'), 'description': _prop('string', '频道描述')}, ['name'])},
  {'name': 'aboutme_chat_updateChannel', 'description': '更新频道信息', 'inputSchema': _schema({'id': _prop('string', '频道 ID'), 'name': _prop('string', '频道名称'), 'description': _prop('string', '频道描述')}, ['id'])},
  {'name': 'aboutme_chat_deleteChannel', 'description': '删除频道', 'inputSchema': _schema({'id': _prop('string', '频道 ID')}, ['id'])},
  {'name': 'aboutme_chat_getMessages', 'description': '获取指定频道的消息列表', 'inputSchema': _schema({'channelId': _prop('string', '频道 ID'), 'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')}, ['channelId'])},
  {'name': 'aboutme_chat_sendMessage', 'description': '向频道发送消息', 'inputSchema': _schema({'channelId': _prop('string', '频道 ID'), 'content': _prop('string', '消息内容'), 'senderId': _prop('string', '发送者 ID'), 'senderName': _prop('string', '发送者名称')}, ['channelId', 'content', 'senderId', 'senderName'])},
  {'name': 'aboutme_chat_deleteMessage', 'description': '删除消息', 'inputSchema': _schema({'channelId': _prop('string', '频道 ID'), 'messageId': _prop('string', '消息 ID')}, ['channelId', 'messageId'])},
  {'name': 'aboutme_chat_searchMessages', 'description': '搜索消息', 'inputSchema': _schema({'field': _prop('string', '搜索字段（如 content）'), 'value': _prop('string', '搜索值'), 'channelId': _prop('string', '频道 ID（可选）'), 'fuzzy': _prop('boolean', '是否模糊搜索'), 'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')}, ['value'])},
  // Notes
  {'name': 'aboutme_notes_getNotes', 'description': '获取笔记列表', 'inputSchema': _schema({'folderId': _prop('string', '文件夹 ID (可选)'), 'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')})},
  {'name': 'aboutme_notes_createNote', 'description': '创建新笔记', 'inputSchema': _schema({'title': _prop('string', '笔记标题'), 'content': _prop('string', '笔记内容 (支持 Markdown)'), 'folderId': _prop('string', '文件夹 ID'), 'tags': _arrayProp('标签列表')}, ['title', 'content'])},
  {'name': 'aboutme_notes_updateNote', 'description': '更新笔记', 'inputSchema': _schema({'id': _prop('string', '笔记 ID'), 'title': _prop('string', '新标题'), 'content': _prop('string', '新内容'), 'tags': _arrayProp('新标签')}, ['id'])},
  {'name': 'aboutme_notes_deleteNote', 'description': '删除笔记', 'inputSchema': _schema({'id': _prop('string', '笔记 ID')}, ['id'])},
  {'name': 'aboutme_notes_searchNotes', 'description': '搜索笔记', 'inputSchema': _schema({'keyword': _prop('string', '搜索关键词'), 'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')}, ['keyword'])},
  // Activity
  {'name': 'aboutme_activity_getActivities', 'description': '获取活动记录列表', 'inputSchema': _schema({'date': _prop('string', '日期 (YYYY-MM-DD)，默认今天'), 'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')})},
  {'name': 'aboutme_activity_createActivity', 'description': '创建活动记录', 'inputSchema': _schema({'startTime': _prop('string', '开始时间 (ISO 8601)'), 'endTime': _prop('string', '结束时间 (ISO 8601)'), 'title': _prop('string', '活动标题'), 'tags': _arrayProp('标签'), 'description': _prop('string', '描述'), 'mood': _prop('number', '心情值 (1-5)')}, ['startTime', 'endTime', 'title'])},
  {'name': 'aboutme_activity_updateActivity', 'description': '更新活动记录', 'inputSchema': _schema({'id': _prop('string', '活动 ID'), 'startTime': _prop('string', '开始时间 (ISO 8601)'), 'endTime': _prop('string', '结束时间 (ISO 8601)'), 'title': _prop('string', '活动标题'), 'tags': _arrayProp('标签'), 'description': _prop('string', '描述'), 'mood': _prop('number', '心情值 (1-5)'), 'date': _prop('string', '日期 (YYYY-MM-DD)')}, ['id'])},
  {'name': 'aboutme_activity_deleteActivity', 'description': '删除活动记录', 'inputSchema': _schema({'id': _prop('string', '活动 ID'), 'date': _prop('string', '日期 (YYYY-MM-DD)')}, ['id'])},
  {'name': 'aboutme_activity_getTodayStats', 'description': '获取今日活动统计', 'inputSchema': _schema({})},
  // Goods
  {'name': 'aboutme_goods_getWarehouses', 'description': '获取仓库列表', 'inputSchema': _schema({'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')})},
  {'name': 'aboutme_goods_createWarehouse', 'description': '创建仓库', 'inputSchema': _schema({'name': _prop('string', '仓库名称'), 'iconData': _prop('number', '图标编码'), 'iconColor': _prop('number', '图标颜色')}, ['name'])},
  {'name': 'aboutme_goods_deleteWarehouse', 'description': '删除仓库', 'inputSchema': _schema({'id': _prop('string', '仓库 ID')}, ['id'])},
  {'name': 'aboutme_goods_getItems', 'description': '获取物品列表', 'inputSchema': _schema({'warehouseId': _prop('string', '仓库 ID (可选)'), 'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')})},
  {'name': 'aboutme_goods_createItem', 'description': '创建物品', 'inputSchema': _schema({'name': _prop('string', '物品名称'), 'warehouseId': _prop('string', '仓库 ID'), 'description': _prop('string', '描述'), 'quantity': _prop('number', '数量'), 'category': _prop('string', '分类'), 'tags': _arrayProp('标签')}, ['name', 'warehouseId'])},
  {'name': 'aboutme_goods_updateItem', 'description': '更新物品', 'inputSchema': _schema({'id': _prop('string', '物品 ID'), 'name': _prop('string', '物品名称'), 'description': _prop('string', '描述'), 'quantity': _prop('number', '数量'), 'category': _prop('string', '分类'), 'tags': _arrayProp('标签')}, ['id'])},
  {'name': 'aboutme_goods_deleteItem', 'description': '删除物品', 'inputSchema': _schema({'id': _prop('string', '物品 ID'), 'warehouseId': _prop('string', '仓库 ID（可选）')}, ['id'])},
  {'name': 'aboutme_goods_searchItems', 'description': '搜索物品', 'inputSchema': _schema({'keyword': _prop('string', '搜索关键词'), 'warehouseId': _prop('string', '仓库 ID (可选)')}, ['keyword'])},
  // Bill
  {'name': 'aboutme_bill_getAccounts', 'description': '获取账户列表', 'inputSchema': _schema({'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')})},
  {'name': 'aboutme_bill_createAccount', 'description': '创建账户', 'inputSchema': _schema({'name': _prop('string', '账户名称'), 'balance': _prop('number', '初始余额')}, ['name'])},
  {'name': 'aboutme_bill_deleteAccount', 'description': '删除账户', 'inputSchema': _schema({'id': _prop('string', '账户 ID')}, ['id'])},
  {'name': 'aboutme_bill_getBills', 'description': '获取账单列表', 'inputSchema': _schema({'accountId': _prop('string', '账户 ID'), 'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')}, ['accountId'])},
  {'name': 'aboutme_bill_createBill', 'description': '创建账单', 'inputSchema': _schema({'accountId': _prop('string', '账户 ID'), 'type': {'type': 'string', 'enum': ['income', 'expense', 'transfer'], 'description': '类型'}, 'amount': _prop('number', '金额'), 'category': _prop('string', '分类'), 'description': _prop('string', '描述'), 'date': _prop('string', '日期 (YYYY-MM-DD)')}, ['accountId', 'type', 'amount'])},
  {'name': 'aboutme_bill_updateBill', 'description': '更新账单', 'inputSchema': _schema({'id': _prop('string', '账单 ID'), 'type': {'type': 'string', 'enum': ['income', 'expense', 'transfer'], 'description': '类型'}, 'amount': _prop('number', '金额'), 'category': _prop('string', '分类'), 'description': _prop('string', '描述'), 'date': _prop('string', '日期 (YYYY-MM-DD)')}, ['id'])},
  {'name': 'aboutme_bill_deleteBill', 'description': '删除账单', 'inputSchema': _schema({'id': _prop('string', '账单 ID')}, ['id'])},
  {'name': 'aboutme_bill_getStats', 'description': '获取账单统计', 'inputSchema': _schema({'startDate': _prop('string', '开始日期'), 'endDate': _prop('string', '结束日期')})},
  // Todo
  {'name': 'aboutme_todo_getTasks', 'description': '获取任务列表', 'inputSchema': _schema({'completed': _prop('string', '完成状态筛选 (true/false)'), 'priority': _prop('string', '优先级筛选 (0-3)'), 'category': _prop('string', '分类筛选'), 'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')})},
  {'name': 'aboutme_todo_createTask', 'description': '创建任务', 'inputSchema': _schema({'title': _prop('string', '任务标题'), 'description': _prop('string', '任务描述'), 'dueDate': _prop('string', '截止日期 (YYYY-MM-DD)'), 'priority': _prop('number', '优先级 (0-3，3 最高)'), 'category': _prop('string', '分类'), 'tags': _arrayProp('标签')}, ['title'])},
  {'name': 'aboutme_todo_updateTask', 'description': '更新任务', 'inputSchema': _schema({'id': _prop('string', '任务 ID'), 'title': _prop('string', '新标题'), 'description': _prop('string', '新描述'), 'completed': _prop('boolean', '完成状态'), 'dueDate': _prop('string', '新截止日期'), 'priority': _prop('number', '新优先级')}, ['id'])},
  {'name': 'aboutme_todo_deleteTask', 'description': '删除任务', 'inputSchema': _schema({'id': _prop('string', '任务 ID')}, ['id'])},
  {'name': 'aboutme_todo_completeTask', 'description': '完成任务', 'inputSchema': _schema({'id': _prop('string', '任务 ID')}, ['id'])},
  {'name': 'aboutme_todo_getTodayTasks', 'description': '获取今日任务', 'inputSchema': _schema({})},
  {'name': 'aboutme_todo_getOverdueTasks', 'description': '获取过期任务', 'inputSchema': _schema({})},
  {'name': 'aboutme_todo_searchTasks', 'description': '搜索任务', 'inputSchema': _schema({'keyword': _prop('string', '搜索关键词')}, ['keyword'])},
  {'name': 'aboutme_todo_getStats', 'description': '获取任务统计', 'inputSchema': _schema({})},
  // Diary
  {'name': 'aboutme_diary_getEntries', 'description': '获取日记列表', 'inputSchema': _schema({'startDate': _prop('string', '开始日期 (YYYY-MM-DD)'), 'endDate': _prop('string', '结束日期 (YYYY-MM-DD)'), 'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')})},
  {'name': 'aboutme_diary_getEntry', 'description': '获取指定日期的日记', 'inputSchema': _schema({'date': _prop('string', '日期 (YYYY-MM-DD)')}, ['date'])},
  {'name': 'aboutme_diary_createEntry', 'description': '创建日记', 'inputSchema': _schema({'date': _prop('string', '日期 (YYYY-MM-DD)'), 'content': _prop('string', '日记内容 (支持 Markdown)'), 'mood': _prop('number', '心情 (1-5)'), 'weather': _prop('string', '天气'), 'tags': _arrayProp('标签')}, ['date', 'content'])},
  {'name': 'aboutme_diary_updateEntry', 'description': '更新日记', 'inputSchema': _schema({'date': _prop('string', '日期 (YYYY-MM-DD)'), 'content': _prop('string', '新内容'), 'mood': _prop('number', '新心情'), 'weather': _prop('string', '新天气'), 'tags': _arrayProp('新标签')}, ['date'])},
  {'name': 'aboutme_diary_deleteEntry', 'description': '删除日记', 'inputSchema': _schema({'date': _prop('string', '日期 (YYYY-MM-DD)')}, ['date'])},
  {'name': 'aboutme_diary_searchEntries', 'description': '搜索日记', 'inputSchema': _schema({'keyword': _prop('string', '搜索关键词'), 'startDate': _prop('string', '开始日期'), 'endDate': _prop('string', '结束日期'), 'mood': _prop('string', '心情筛选')})},
  {'name': 'aboutme_diary_getStats', 'description': '获取日记统计', 'inputSchema': _schema({})},
  // Checkin
  {'name': 'aboutme_checkin_getItems', 'description': '获取打卡项目列表', 'inputSchema': _schema({'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')})},
  {'name': 'aboutme_checkin_createItem', 'description': '创建打卡项目', 'inputSchema': _schema({'name': _prop('string', '项目名称'), 'icon': _prop('string', '图标'), 'color': _prop('string', '颜色'), 'group': _prop('string', '分组'), 'description': _prop('string', '描述')}, ['name'])},
  {'name': 'aboutme_checkin_updateItem', 'description': '更新打卡项目', 'inputSchema': _schema({'id': _prop('string', '项目 ID'), 'name': _prop('string', '项目名称'), 'icon': _prop('string', '图标'), 'color': _prop('string', '颜色'), 'group': _prop('string', '分组'), 'description': _prop('string', '描述')}, ['id'])},
  {'name': 'aboutme_checkin_deleteItem', 'description': '删除打卡项目', 'inputSchema': _schema({'id': _prop('string', '项目 ID')}, ['id'])},
  {'name': 'aboutme_checkin_addRecord', 'description': '添加打卡记录', 'inputSchema': _schema({'itemId': _prop('string', '打卡项目 ID'), 'date': _prop('string', '日期 (YYYY-MM-DD)'), 'note': _prop('string', '备注')}, ['itemId', 'date'])},
  {'name': 'aboutme_checkin_getStats', 'description': '获取打卡统计', 'inputSchema': _schema({})},
  // Day
  {'name': 'aboutme_day_getMemorialDays', 'description': '获取纪念日列表', 'inputSchema': _schema({'sortMode': _prop('string', '排序模式'), 'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')})},
  {'name': 'aboutme_day_createMemorialDay', 'description': '创建纪念日', 'inputSchema': _schema({'name': _prop('string', '纪念日名称'), 'date': _prop('string', '日期 (YYYY-MM-DD)'), 'type': _prop('string', '类型（倒计时/正计时）'), 'description': _prop('string', '描述'), 'color': _prop('string', '颜色')}, ['name', 'date'])},
  {'name': 'aboutme_day_updateMemorialDay', 'description': '更新纪念日', 'inputSchema': _schema({'id': _prop('string', '纪念日 ID'), 'name': _prop('string', '纪念日名称'), 'date': _prop('string', '日期 (YYYY-MM-DD)'), 'type': _prop('string', '类型（倒计时/正计时）'), 'description': _prop('string', '描述'), 'color': _prop('string', '颜色')}, ['id'])},
  {'name': 'aboutme_day_deleteMemorialDay', 'description': '删除纪念日', 'inputSchema': _schema({'id': _prop('string', '纪念日 ID')}, ['id'])},
  {'name': 'aboutme_day_searchMemorialDays', 'description': '搜索纪念日', 'inputSchema': _schema({'sortMode': _prop('string', '排序模式'), 'startDate': _prop('string', '开始日期'), 'endDate': _prop('string', '结束日期'), 'includeExpired': _prop('boolean', '包含已过期')})},
  {'name': 'aboutme_day_getStats', 'description': '获取纪念日统计', 'inputSchema': _schema({})},
  // Tracker
  {'name': 'aboutme_tracker_getGoals', 'description': '获取追踪目标列表', 'inputSchema': _schema({'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')})},
  {'name': 'aboutme_tracker_createGoal', 'description': '创建追踪目标', 'inputSchema': _schema({'name': _prop('string', '目标名称'), 'targetValue': _prop('number', '目标值'), 'unit': _prop('string', '单位'), 'group': _prop('string', '分组'), 'description': _prop('string', '描述')}, ['name', 'targetValue', 'unit'])},
  {'name': 'aboutme_tracker_updateGoal', 'description': '更新追踪目标', 'inputSchema': _schema({'id': _prop('string', '目标 ID'), 'name': _prop('string', '目标名称'), 'targetValue': _prop('number', '目标值'), 'unit': _prop('string', '单位'), 'group': _prop('string', '分组'), 'description': _prop('string', '描述')}, ['id'])},
  {'name': 'aboutme_tracker_deleteGoal', 'description': '删除追踪目标', 'inputSchema': _schema({'id': _prop('string', '目标 ID')}, ['id'])},
  {'name': 'aboutme_tracker_addRecord', 'description': '添加追踪记录', 'inputSchema': _schema({'goalId': _prop('string', '目标 ID'), 'value': _prop('number', '记录值'), 'date': _prop('string', '日期 (YYYY-MM-DD)'), 'note': _prop('string', '备注')}, ['goalId', 'value', 'date'])},
  {'name': 'aboutme_tracker_getStats', 'description': '获取追踪统计', 'inputSchema': _schema({})},
  // Contact
  {'name': 'aboutme_contact_getContacts', 'description': '获取联系人列表', 'inputSchema': _schema({'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')})},
  {'name': 'aboutme_contact_createContact', 'description': '创建联系人', 'inputSchema': _schema({'name': _prop('string', '姓名'), 'phone': _prop('string', '电话'), 'email': _prop('string', '邮箱'), 'tags': _arrayProp('标签'), 'notes': _prop('string', '备注')}, ['name'])},
  {'name': 'aboutme_contact_updateContact', 'description': '更新联系人', 'inputSchema': _schema({'id': _prop('string', '联系人 ID'), 'name': _prop('string', '姓名'), 'phone': _prop('string', '电话'), 'email': _prop('string', '邮箱'), 'tags': _arrayProp('标签'), 'notes': _prop('string', '备注')}, ['id'])},
  {'name': 'aboutme_contact_deleteContact', 'description': '删除联系人', 'inputSchema': _schema({'id': _prop('string', '联系人 ID')}, ['id'])},
  {'name': 'aboutme_contact_searchContacts', 'description': '搜索联系人', 'inputSchema': _schema({'keyword': _prop('string', '搜索关键词')}, ['keyword'])},
  {'name': 'aboutme_contact_getStats', 'description': '获取联系人统计', 'inputSchema': _schema({})},
  // Calendar
  {'name': 'aboutme_calendar_getEvents', 'description': '获取日历事件列表', 'inputSchema': _schema({'startDate': _prop('string', '开始日期 (YYYY-MM-DD)'), 'endDate': _prop('string', '结束日期 (YYYY-MM-DD)'), 'offset': _prop('number', '偏移量'), 'count': _prop('number', '数量限制')})},
  {'name': 'aboutme_calendar_createEvent', 'description': '创建日历事件', 'inputSchema': _schema({'title': _prop('string', '事件标题'), 'startTime': _prop('string', '开始时间 (ISO 8601)'), 'endTime': _prop('string', '结束时间 (ISO 8601)'), 'description': _prop('string', '描述'), 'location': _prop('string', '地点')}, ['title', 'startTime'])},
  {'name': 'aboutme_calendar_updateEvent', 'description': '更新日历事件', 'inputSchema': _schema({'id': _prop('string', '事件 ID'), 'title': _prop('string', '事件标题'), 'startTime': _prop('string', '开始时间 (ISO 8601)'), 'endTime': _prop('string', '结束时间 (ISO 8601)'), 'description': _prop('string', '描述'), 'location': _prop('string', '地点')}, ['id'])},
  {'name': 'aboutme_calendar_deleteEvent', 'description': '删除日历事件', 'inputSchema': _schema({'id': _prop('string', '事件 ID')}, ['id'])},
  {'name': 'aboutme_calendar_completeEvent', 'description': '完成日历事件', 'inputSchema': _schema({'id': _prop('string', '事件 ID')}, ['id'])},
  {'name': 'aboutme_calendar_searchEvents', 'description': '搜索日历事件', 'inputSchema': _schema({'keyword': _prop('string', '搜索关键词')}, ['keyword'])},
];

/// 调用工具：返回 content 文本；失败返回 (text, isError=true)。
Future<(String, bool)> dispatchTool(
  PluginInvoker invoker,
  PluginData data,
  String name,
  Map<String, dynamic> args,
) async {
  Future<Map<String, dynamic>> call(
    String method,
    String path, {
    Map<String, dynamic>? query,
    dynamic body,
  }) async => invoker.invoke(
      data, method, path,
      query: query, body: body);

  Map<String, dynamic> rest(Map<String, dynamic> args, List<String> extract) {
    final data = Map<String, dynamic>.from(args);
    for (final key in extract) {
      data.remove(key);
    }
    return data;
  }

  try {
    Map<String, dynamic> response;
    switch (name) {
      // ===== Chat =====
      case 'aboutme_chat_getChannels':
        response = await call('get', '/api/v1/plugins/chat/channels',
            query: _pick(args, ['offset', 'count']));
      case 'aboutme_chat_createChannel':
        response = await call('post', '/api/v1/plugins/chat/channels',
            body: args);
      case 'aboutme_chat_updateChannel':
        response = await call(
            'put', '/api/v1/plugins/chat/channels/${args['id']}',
            body: rest(args, ['id']));
      case 'aboutme_chat_deleteChannel':
        response = await call(
            'delete', '/api/v1/plugins/chat/channels/${args['id']}');
      case 'aboutme_chat_getMessages':
        response = await call(
            'get', '/api/v1/plugins/chat/channels/${args['channelId']}/messages',
            query: _pick(args, ['offset', 'count']));
      case 'aboutme_chat_sendMessage':
        response = await call(
            'post', '/api/v1/plugins/chat/channels/${args['channelId']}/messages',
            body: rest(args, ['channelId']));
      case 'aboutme_chat_deleteMessage':
        response = await call(
            'delete',
            '/api/v1/plugins/chat/channels/${args['channelId']}/messages/${args['messageId']}');
      case 'aboutme_chat_searchMessages':
        response = await call('get', '/api/v1/plugins/chat/find/message',
            query: _fieldQuery(args, 'value'));
      // ===== Notes =====
      case 'aboutme_notes_getNotes':
        response = await call('get', '/api/v1/plugins/notes/notes',
            query: _pick(args, ['folderId', 'offset', 'count']));
      case 'aboutme_notes_createNote':
        response = await call('post', '/api/v1/plugins/notes/notes', body: args);
      case 'aboutme_notes_updateNote':
        response = await call('put', '/api/v1/plugins/notes/notes/${args['id']}',
            body: rest(args, ['id']));
      case 'aboutme_notes_deleteNote':
        response =
            await call('delete', '/api/v1/plugins/notes/notes/${args['id']}');
      case 'aboutme_notes_searchNotes':
        response = await call('get', '/api/v1/plugins/notes/search',
            query: {'keyword': args['keyword'], ..._pick(args, ['offset', 'count'])});
      // ===== Activity =====
      case 'aboutme_activity_getActivities':
        response = await call('get', '/api/v1/plugins/activity/activities',
            query: _pick(args, ['date', 'offset', 'count']));
      case 'aboutme_activity_createActivity':
        response = await call(
            'post', '/api/v1/plugins/activity/activities',
            body: args);
      case 'aboutme_activity_updateActivity':
        response = await call(
            'put', '/api/v1/plugins/activity/activities/${args['id']}',
            body: rest(args, ['id']));
      case 'aboutme_activity_deleteActivity':
        response = await call(
            'delete',
            '/api/v1/plugins/activity/activities/${args['id']}',
            query: _pick(args, ['date']));
      case 'aboutme_activity_getTodayStats':
        response = await call('get', '/api/v1/plugins/activity/stats/today');
      // ===== Goods =====
      case 'aboutme_goods_getWarehouses':
        response = await call('get', '/api/v1/plugins/goods/warehouses',
            query: _pick(args, ['offset', 'count']));
      case 'aboutme_goods_createWarehouse':
        response = await call('post', '/api/v1/plugins/goods/warehouses', body: {
          'title': args['name'],
          if (args['iconData'] != null) 'iconData': args['iconData'],
          if (args['iconColor'] != null) 'iconColor': args['iconColor'],
        });
      case 'aboutme_goods_deleteWarehouse':
        response = await call(
            'delete', '/api/v1/plugins/goods/warehouses/${args['id']}');
      case 'aboutme_goods_getItems':
        response = await call('get', '/api/v1/plugins/goods/items',
            query: _pick(args, ['warehouseId', 'offset', 'count']));
      case 'aboutme_goods_createItem':
        response =
            await call('post', '/api/v1/plugins/goods/items', body: args);
      case 'aboutme_goods_updateItem':
        response = await call('put', '/api/v1/plugins/goods/items/${args['id']}',
            body: rest(args, ['id']));
      case 'aboutme_goods_deleteItem':
        response = await call('delete', '/api/v1/plugins/goods/items/${args['id']}',
            query: _pick(args, ['warehouseId']));
      case 'aboutme_goods_searchItems':
        response = await call('get', '/api/v1/plugins/goods/search',
            query: {'keyword': args['keyword'], ..._pick(args, ['warehouseId'])});
      // ===== Bill =====
      case 'aboutme_bill_getAccounts':
        response = await call('get', '/api/v1/plugins/bill/accounts',
            query: _pick(args, ['offset', 'count']));
      case 'aboutme_bill_createAccount':
        response = await call('post', '/api/v1/plugins/bill/accounts', body: {
          'name': args['name'],
          if (args['balance'] != null) 'balance': args['balance'],
        });
      case 'aboutme_bill_deleteAccount':
        response = await call(
            'delete', '/api/v1/plugins/bill/accounts/${args['id']}');
      case 'aboutme_bill_getBills':
        response = await call(
            'get', '/api/v1/plugins/bill/accounts/${args['accountId']}/bills',
            query: _pick(args, ['offset', 'count']));
      case 'aboutme_bill_createBill':
        response = await call(
            'post', '/api/v1/plugins/bill/accounts/${args['accountId']}/bills',
            body: rest(args, ['accountId']));
      case 'aboutme_bill_updateBill':
        response = await call('put', '/api/v1/plugins/bill/bills/${args['id']}',
            body: rest(args, ['id']));
      case 'aboutme_bill_deleteBill':
        response =
            await call('delete', '/api/v1/plugins/bill/bills/${args['id']}');
      case 'aboutme_bill_getStats':
        response = await call('get', '/api/v1/plugins/bill/stats',
            query: _pick(args, ['startDate', 'endDate']));
      // ===== Todo =====
      case 'aboutme_todo_getTasks':
        response = await call('get', '/api/v1/plugins/todo/tasks',
            query: _pick(args, ['completed', 'priority', 'category', 'offset', 'count']));
      case 'aboutme_todo_createTask':
        response = await call('post', '/api/v1/plugins/todo/tasks', body: args);
      case 'aboutme_todo_updateTask':
        response = await call('put', '/api/v1/plugins/todo/tasks/${args['id']}',
            body: rest(args, ['id']));
      case 'aboutme_todo_completeTask':
        response = await call(
            'post', '/api/v1/plugins/todo/tasks/${args['id']}/complete');
      case 'aboutme_todo_deleteTask':
        response = await call(
            'delete', '/api/v1/plugins/todo/tasks/${args['id']}');
      case 'aboutme_todo_getTodayTasks':
        response = await call('get', '/api/v1/plugins/todo/tasks/filter/today');
      case 'aboutme_todo_getOverdueTasks':
        response = await call('get', '/api/v1/plugins/todo/tasks/filter/overdue');
      case 'aboutme_todo_searchTasks':
        response = await call('get', '/api/v1/plugins/todo/search',
            query: {'keyword': args['keyword']});
      case 'aboutme_todo_getStats':
        response = await call('get', '/api/v1/plugins/todo/stats');
      // ===== Diary =====
      case 'aboutme_diary_getEntries':
        response = await call('get', '/api/v1/plugins/diary/entries',
            query: _pick(args, ['startDate', 'endDate', 'offset', 'count']));
      case 'aboutme_diary_getEntry':
        response = await call(
            'get', '/api/v1/plugins/diary/entries/${args['date']}');
      case 'aboutme_diary_createEntry':
        response = await call('post', '/api/v1/plugins/diary/entries', body: {
          ...args,
          // 与 nodejs 一致：mood 数字转字符串
          if (args['mood'] != null) 'mood': args['mood'].toString(),
        });
      case 'aboutme_diary_updateEntry':
        response = await call(
            'put', '/api/v1/plugins/diary/entries/${args['date']}',
            body: rest(args, ['date']));
      case 'aboutme_diary_deleteEntry':
        response = await call(
            'delete', '/api/v1/plugins/diary/entries/${args['date']}');
      case 'aboutme_diary_searchEntries':
        response = await call('get', '/api/v1/plugins/diary/search', query: args);
      case 'aboutme_diary_getStats':
        response = await call('get', '/api/v1/plugins/diary/stats');
      // ===== Checkin =====
      case 'aboutme_checkin_getItems':
        response = await call('get', '/api/v1/plugins/checkin/items',
            query: _pick(args, ['offset', 'count']));
      case 'aboutme_checkin_createItem':
        response = await call('post', '/api/v1/plugins/checkin/items', body: {
          ...args,
          // 与 nodejs 一致：icon/color 字符串转整数（含 #RRGGBB）
          if (args['icon'] != null)
            'icon': args['icon'] is String
                ? int.tryParse(args['icon'].toString()) ?? 57527
                : args['icon'],
          if (args['color'] != null)
            'color': args['color'] is String
                ? int.tryParse(
                        args['color'].toString().replaceFirst('#', ''),
                        radix: 16) ??
                    4280391411
                : args['color'],
        });
      case 'aboutme_checkin_updateItem':
        response = await call(
            'put', '/api/v1/plugins/checkin/items/${args['id']}',
            body: rest(args, ['id']));
      case 'aboutme_checkin_deleteItem':
        response = await call(
            'delete', '/api/v1/plugins/checkin/items/${args['id']}');
      case 'aboutme_checkin_addRecord':
        response = await call(
            'post', '/api/v1/plugins/checkin/items/${args['itemId']}/checkin',
            body: rest(args, ['itemId']));
      case 'aboutme_checkin_getStats':
        response = await call('get', '/api/v1/plugins/checkin/stats');
      // ===== Day =====
      case 'aboutme_day_getMemorialDays':
        response = await call('get', '/api/v1/plugins/day/days',
            query: _pick(args, ['sortMode', 'offset', 'count']));
      case 'aboutme_day_createMemorialDay':
        response = await call('post', '/api/v1/plugins/day/days', body: {
          // 与 nodejs 一致的参数映射与默认值
          'title': args['name'],
          'targetDate': args['date'],
          'notes': args['description'] != null ? [args['description']] : [],
          if (args['color'] != null)
            'backgroundColor':
                int.tryParse(args['color'].toString()) ?? 4280391411,
        });
      case 'aboutme_day_updateMemorialDay':
        response = await call('put', '/api/v1/plugins/day/days/${args['id']}',
            body: {
              // 与 create 一致的参数映射（底层字段为 title/targetDate/notes/backgroundColor）
              if (args['name'] != null) 'title': args['name'],
              if (args['date'] != null) 'targetDate': args['date'],
              if (args['description'] != null)
                'notes': [args['description']],
              if (args['color'] != null)
                'backgroundColor':
                    int.tryParse(args['color'].toString()) ?? 4280391411,
            });
      case 'aboutme_day_deleteMemorialDay':
        response =
            await call('delete', '/api/v1/plugins/day/days/${args['id']}');
      case 'aboutme_day_searchMemorialDays':
        response = await call('get', '/api/v1/plugins/day/search', query: args);
      case 'aboutme_day_getStats':
        response = await call('get', '/api/v1/plugins/day/stats');
      // ===== Tracker =====
      case 'aboutme_tracker_getGoals':
        response = await call('get', '/api/v1/plugins/tracker/goals',
            query: _pick(args, ['offset', 'count']));
      case 'aboutme_tracker_createGoal':
        response = await call('post', '/api/v1/plugins/tracker/goals', body: {
          ...rest(args, ['unit']),
          'unitType': args['unit'],
          // 与 nodejs 一致的默认值
          'icon': '57455',
          'iconColor': 4280391411,
          'progressColor': 4280391411,
          'dateSettings': {'type': 'daily'},
        });
      case 'aboutme_tracker_updateGoal':
        response = await call(
            'put', '/api/v1/plugins/tracker/goals/${args['id']}',
            body: {
              ...rest(args, ['id', 'unit']),
              // 与 create 一致：unit 映射为底层字段 unitType
              if (args['unit'] != null) 'unitType': args['unit'],
            });
      case 'aboutme_tracker_deleteGoal':
        response =
            await call('delete', '/api/v1/plugins/tracker/goals/${args['id']}');
      case 'aboutme_tracker_addRecord':
        response =
            await call('post', '/api/v1/plugins/tracker/records', body: args);
      case 'aboutme_tracker_getStats':
        response = await call('get', '/api/v1/plugins/tracker/stats');
      // ===== Contact =====
      case 'aboutme_contact_getContacts':
        response = await call('get', '/api/v1/plugins/contact/contacts',
            query: _pick(args, ['offset', 'count']));
      case 'aboutme_contact_createContact':
        response =
            await call('post', '/api/v1/plugins/contact/contacts', body: args);
      case 'aboutme_contact_updateContact':
        response = await call(
            'put', '/api/v1/plugins/contact/contacts/${args['id']}',
            body: rest(args, ['id']));
      case 'aboutme_contact_deleteContact':
        response = await call(
            'delete', '/api/v1/plugins/contact/contacts/${args['id']}');
      case 'aboutme_contact_searchContacts':
        response = await call('get', '/api/v1/plugins/contact/contacts/search',
            query: {'keyword': args['keyword']});
      case 'aboutme_contact_getStats':
        response = await call('get', '/api/v1/plugins/contact/stats/total-contacts');
      // ===== Calendar =====
      case 'aboutme_calendar_getEvents':
        response = await call('get', '/api/v1/plugins/calendar/events',
            query: _pick(args, ['startDate', 'endDate', 'offset', 'count']));
      case 'aboutme_calendar_createEvent':
        response = await call('post', '/api/v1/plugins/calendar/events', body: {
          ...args,
          // 与 nodejs 一致的默认值
          if (args['icon'] == null) 'icon': 58050,
          if (args['color'] == null) 'color': 4280391411,
        });
      case 'aboutme_calendar_updateEvent':
        response = await call(
            'put', '/api/v1/plugins/calendar/events/${args['id']}',
            body: rest(args, ['id']));
      case 'aboutme_calendar_deleteEvent':
        response = await call(
            'delete', '/api/v1/plugins/calendar/events/${args['id']}');
      case 'aboutme_calendar_completeEvent':
        response = await call(
            'post', '/api/v1/plugins/calendar/events/${args['id']}/complete');
      case 'aboutme_calendar_searchEvents':
        response = await call('get', '/api/v1/plugins/calendar/events/search',
            query: {'keyword': args['keyword']});
      default:
        throw Exception('未知工具: $name');
    }

    if (response['success'] == true) {
      return (const JsonEncoder.withIndent('  ').convert(response['data']), false);
    }
    throw Exception(response['error']?.toString() ?? '请求失败');
  } catch (error) {
    return ('错误: $error', true);
  }
}

Map<String, dynamic> _pick(Map<String, dynamic> args, List<String> keys) {
  final result = <String, dynamic>{};
  for (final key in keys) {
    final value = args[key];
    if (value != null) result[key] = value;
  }
  return result;
}

/// 搜索类工具的 field/value/fuzzy 查询参数。
Map<String, dynamic> _fieldQuery(Map<String, dynamic> args, String valueKey) {
  return {
    if (args['field'] != null) 'field': args['field'],
    if (args[valueKey] != null) valueKey: args[valueKey],
    if (args['channelId'] != null) 'channelId': args['channelId'],
    if (args['fuzzy'] != null) 'fuzzy': args['fuzzy'],
    ..._pick(args, ['offset', 'count']),
  };
}
