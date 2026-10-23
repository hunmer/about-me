import 'dart:convert';
import 'package:shared_models/shared_models.dart';
import '../../storage_errors.dart';
import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';
import '../templates/chat_examples.dart';
import 'chat_support.dart';
import 'chat_stickers.dart';
import '../asset_references.dart';

PluginHandlers createChatHandlers(PluginData data) {
  Never corrupt(String detail) =>
      throw StorageException(StorageErrorKind.invalidData, detail);
  Future<Map<String, dynamic>?> object(String file) async {
    final value = await data.read('chat', file);
    if (value == null) return null;
    if (value is! Map<String, dynamic>) corrupt('聊天文件必须是对象: $file');
    return value;
  }

  Future<List<String>> channelIds() async {
    final value = await object('channels.json');
    if (value == null) return [];
    if (value['channels'] is! List ||
        (value['channels'] as List).any((id) => id is! String))
      corrupt('频道索引格式错误');
    return List<String>.from(value['channels'] as List);
  }

  Future<void> saveIds(List<String> ids) async => data.write(
    'chat',
    'channels.json',
    {...?await object('channels.json'), 'channels': ids},
  );
  Future<Map<String, dynamic>?> channel(String id) async {
    final value = await object('channel/$id.json');
    if (value == null) return null;
    if (value['channel'] is! Map<String, dynamic>) corrupt('频道详情格式错误: $id');
    return ChatCodec.channel(value['channel'] as Map<String, dynamic>);
  }

  Future<void> saveChannel(String id, Map<String, dynamic> value) async =>
      data.write('chat', 'channel/$id.json', {
        ...?await object('channel/$id.json'),
        'channel': value,
      });
  Future<List<Map<String, dynamic>>> messages(String id) async {
    final value = await object('messages/$id.json');
    if (value == null) return [];
    if (value['messages'] is! List) corrupt('消息集合格式错误: $id');
    return (value['messages'] as List).map((item) {
      if (item is! Map<String, dynamic> ||
          item['id'] is! String ||
          item['content'] is! String ||
          DateTime.tryParse(
                (item['date'] ?? item['createdAt'])?.toString() ?? '',
              ) ==
              null) {
        corrupt('消息字段损坏: $id');
      }
      return ChatCodec.message(item, channelId: id);
    }).toList();
  }

  Future<void> saveMessages(
    String id,
    List<Map<String, dynamic>> value,
  ) async {
    Map<String, Set<String>> references(List<Map<String, dynamic>> items) {
      final result = <String, Set<String>>{};
      for (final item in items) {
        for (final assetId in assetIdsIn([item['metadata'], item['attachments'], item['fileInfo']])) {
          result.putIfAbsent(assetId, () => {}).add('chat:message:$id:${item['id']}');
        }
      }
      return result;
    }
    await updateAssetReferences(data, references(await messages(id)), references(value));
    await data.write('chat', 'messages/$id.json', {
      ...?await object('messages/$id.json'), 'messages': value,
    });
  }
  int compareMessage(Map<String, dynamic> a, Map<String, dynamic> b) {
    final byTime = DateTime.parse(
      a['date'] as String,
    ).compareTo(DateTime.parse(b['date'] as String));
    return byTime != 0
        ? byTime
        : (a['id'] as String).compareTo(b['id'] as String);
  }

  Future<void> summary(
    String id,
    Map<String, dynamic> value,
    List<Map<String, dynamic>> items,
  ) async {
    final sorted = [...items]..sort(compareMessage);
    final last = sorted.isEmpty ? null : sorted.last;
    await saveChannel(id, {
      ...value,
      'lastMessage': last,
      'lastMessageTime': last?['date'] ?? value['createdAt'],
      'messageCount': items.length,
      'updatedAt': jsIsoDateTime(DateTime.now()),
    });
  }

  Future<List<Map<String, dynamic>>> channels() async {
    final result = <Map<String, dynamic>>[];
    for (final id in await channelIds()) {
      final value = await channel(id);
      if (value == null) corrupt('频道索引引用不存在的频道: $id');
      result.add(value);
    }
    result.sort((a, b) {
      final pinned = (b['isPinned'] == true ? 1 : 0).compareTo(
        a['isPinned'] == true ? 1 : 0,
      );
      if (pinned != 0) return pinned;
      final priority = toNum(b['priority']).compareTo(toNum(a['priority']));
      if (priority != 0) return priority;
      final time = (b['lastMessageTime'] ?? '').toString().compareTo(
        (a['lastMessageTime'] ?? '').toString(),
      );
      return time != 0
          ? time
          : a['id'].toString().compareTo(b['id'].toString());
    });
    return result;
  }

  PluginResult missing(String label) =>
      PluginResult.failure('$label不存在', 'NOT_FOUND');
  Future<PluginResult> update(PluginData _, Map<String, dynamic> params) async {
    final id = params['id'].toString();
    final old = await channel(id);
    if (old == null) return missing('频道');
    final patch = Map<String, dynamic>.from(params)
      ..remove('createdAt')
      ..remove('lastMessageTime')
      ..remove('messageCount')
      ..remove('lastMessage');
    if (patch.containsKey('name') && !patch.containsKey('title'))
      patch['title'] = patch['name'];
    if (patch['metadata'] is Map && old['metadata'] is Map) {
      patch['metadata'] = {
        ...old['metadata'] as Map,
        ...patch['metadata'] as Map,
      };
    }
    final next = ChatCodec.channel({
      ...old,
      ...patch,
      'updatedAt': jsIsoDateTime(DateTime.now()),
    });
    await saveChannel(id, next);
    return PluginResult.success(next);
  }

  return {
    ...createChatSupportHandlers(data),
    ...createChatStickerHandlers(data),
    'seedExamples': (_, params) async {
      if (params['templateVersion'] != 1 ||
          params['groups'] is! List ||
          (params['groups'] as List).any((group) => group != 'channels')) {
        return const PluginResult.failure('不支持的示例模板', 'INVALID_PARAMS');
      }
      final marker = await object('seed_examples.json') ?? {};
      if ((params['groups'] as List).isEmpty) return PluginResult.success({'created': []});
      if (marker['channels:1'] == true)
        return PluginResult.success({'created': [], 'skipped': true});
      final templates = getSampleChannelsData();
      final sampleMessages = getSampleMessagesData();
      final ids = await channelIds();
      final created = <String>[];
      for (final raw in templates['channels'] as List) {
        final value = ChatCodec.channel(Map<String, dynamic>.from(raw as Map));
        final id = value['id'] as String;
        if (await channel(id) != null) continue;
        final items = (sampleMessages[id] ?? [])
            .map((message) => ChatCodec.message(message, channelId: id))
            .toList();
        await saveChannel(id, value);
        await saveMessages(id, items);
        await summary(id, value, items);
        if (!ids.contains(id)) ids.add(id);
        created.add(id);
      }
      await saveIds(ids);
      await data.write('chat', 'seed_examples.json', {
        ...marker,
        'channels:1': true,
      });
      return PluginResult.success({'created': created});
    },
    'getList': (_, params) async => PluginResult.success(
      createPaginatedResult(
        await channels(),
        offset: params['offset'] as int?,
        count: params['count'] as int?,
      ),
    ),
    'getStats': (_, params) async {
      final today = params['date']?.toString() ?? DateTime.now().toIso8601String().substring(0, 10);
      final offset = params['timezoneOffsetMinutes'] ?? 0;
      if (offset is! int || offset.abs() > 1440) throw const FormatException('无效时区偏移');
      var count = 0;
      var total = 0;
      for (final id in await channelIds()) {
        final items = await messages(id);
        total += items.length;
        count += items.where((item) => DateTime.parse(item['date'] as String).toUtc().add(Duration(minutes: offset)).toIso8601String().startsWith(today)).length;
      }
      return PluginResult.success({'todayMessageCount': count, 'totalMessageCount': total});
    },
    'reorderChannels': (_, params) async {
      final ids = params['ids'];
      if (ids is! List || ids.any((id) => id is! String) || ids.length != ids.toSet().length || ids.length > 1000) {
        return const PluginResult.failure('频道排序必须为不重复的 ID 列表', 'INVALID_PARAMS');
      }
      for (var index = 0; index < ids.length; index++) {
        final id = ids[index] as String;
        final current = await channel(id);
        if (current == null) return missing('频道');
        await saveChannel(id, {...current, 'priority': ids.length - index});
      }
      return PluginResult.success({'ids': ids});
    },
    'getById': (_, params) async {
      final value = await channel(params['id'].toString());
      return value == null ? missing('频道') : PluginResult.success(value);
    },
    'create': (_, params) async {
      final id = params['id']?.toString() ?? generateUUID();
      if (id.isEmpty)
        return const PluginResult.failure('频道 ID 不能为空', 'INVALID_PARAMS');
      if (await channel(id) != null)
        return const PluginResult.failure('频道已存在', 'CONFLICT');
      final now = jsIsoDateTime(DateTime.now());
      final value = ChatCodec.channel({
        ...params,
        'id': id,
        'createdAt': now,
        'updatedAt': now,
        'lastMessageTime': now,
        'messageCount': 0,
      });
      await saveChannel(id, value);
      await saveMessages(id, []);
      await saveIds([...await channelIds(), id]);
      return PluginResult.success(value);
    },
    'update': update,
    'patch': update,
    'delete': (_, params) async {
      final id = params['id'].toString();
      if (await channel(id) == null) return missing('频道');
      await saveMessages(id, []);
      await data.delete('chat', 'channel/$id.json');
      await data.delete('chat', 'messages/$id.json');
      await data.delete('chat', 'ai_threads/$id.json');
      await saveIds(
        (await channelIds()).where((value) => value != id).toList(),
      );
      return PluginResult.success({'id': id});
    },
    'getMessages': (_, params) async {
      final id = params['channelId'].toString();
      if (await channel(id) == null) return missing('频道');
      final items = await messages(id)
        ..sort(compareMessage);
      if (!params.containsKey('limit') && !params.containsKey('before')) {
        return PluginResult.success(
          createPaginatedResult(
            items,
            offset: params['offset'] as int?,
            count: params['count'] as int?,
          ),
        );
      }
      final total = items.length;
      final before = params['before'];
      if (before != null) {
        if (before is! String) throw const FormatException('无效消息游标');
        final cursor = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(before))),
        );
        if (cursor is! List ||
            cursor.length != 2 ||
            cursor[0] is! String ||
            cursor[1] is! String ||
            DateTime.tryParse(cursor[0] as String) == null)
          throw const FormatException('无效消息游标');
        final marker = {'date': cursor[0], 'id': cursor[1]};
        items.removeWhere((item) => compareMessage(item, marker) >= 0);
      }
      final limit = (params['limit'] as int? ?? 50).clamp(1, 1000);
      final hasMore = items.length > limit;
      final page = items
          .skip((items.length - limit).clamp(0, items.length))
          .toList();
      final next = hasMore && page.isNotEmpty
          ? base64Url.encode(
              utf8.encode(jsonEncode([page.first['date'], page.first['id']])),
            )
          : null;
      return PluginResult.success({
        'data': page,
        'total': total,
        'count': page.length,
        'hasMore': hasMore,
        'nextCursor': next,
      });
    },
    'sendMessage': (_, params) async {
      final id = params['channelId'].toString();
      final value = await channel(id);
      if (value == null) return missing('频道');
      if (value['isArchived'] == true)
        return const PluginResult.failure('封存频道禁止发送消息', 'INVALID_PARAMS');
      if (params['content'] is! String)
        return const PluginResult.failure('content 必须是字符串', 'INVALID_PARAMS');
      final items = await messages(id);
      final messageId = params['id']?.toString() ?? generateUUID();
      if (items.any((item) => item['id'] == messageId))
        return const PluginResult.failure('消息 ID 已存在', 'CONFLICT');
      final now = jsIsoDateTime(DateTime.now());
      final message = ChatCodec.message({
        ...params,
        'id': messageId,
        'channelId': id,
        'date': now,
        'createdAt': now,
        'updatedAt': now,
      });
      items.add(message);
      await saveMessages(id, items);
      await summary(id, {...value, 'draft': null}, items);
      return PluginResult.success(message);
    },
    'updateMessage': (_, params) async {
      final id = params['channelId'].toString();
      final value = await channel(id);
      if (value == null) return missing('频道');
      final items = await messages(id);
      final index = items.indexWhere(
        (item) => item['id'] == params['messageId'],
      );
      if (index < 0) return missing('消息');
      final patch = Map<String, dynamic>.from(params)
        ..remove('messageId')
        ..remove('id')
        ..remove('date')
        ..remove('createdAt')
        ..remove('user');
      if (patch.containsKey('content') && patch['content'] is! String)
        return const PluginResult.failure('content 必须是字符串', 'INVALID_PARAMS');
      final next = {
        ...items[index],
        ...patch,
        if (patch['metadata'] is Map && items[index]['metadata'] is Map)
          'metadata': {
            ...items[index]['metadata'] as Map,
            ...patch['metadata'] as Map,
          },
        'editedAt': jsIsoDateTime(DateTime.now()),
        'updatedAt': jsIsoDateTime(DateTime.now()),
      };
      items[index] = next;
      await saveMessages(id, items);
      await summary(id, value, items);
      return PluginResult.success(next);
    },
    'deleteMessage': (_, params) async {
      final id = params['channelId'].toString();
      final value = await channel(id);
      if (value == null) return missing('频道');
      final items = await messages(id);
      final length = items.length;
      items.removeWhere((item) => item['id'] == params['messageId']);
      if (items.length == length) return missing('消息');
      await saveMessages(id, items);
      await removeChatThreads(data, id, [params['messageId'].toString()]);
      await summary(id, value, items);
      return PluginResult.success({'id': params['messageId']});
    },
    'deleteMessages': (_, params) async {
      final id = params['channelId'].toString();
      final value = await channel(id);
      if (value == null) return missing('频道');
      final ids = params['messageIds'];
      if (ids is! List || ids.any((id) => id is! String) || ids.length > 1000) {
        return const PluginResult.failure(
          'messageIds 必须是不超过 1000 项的字符串数组',
          'INVALID_PARAMS',
        );
      }
      final items = await messages(id);
      items.removeWhere((item) => ids.contains(item['id']));
      await saveMessages(id, items);
      await removeChatThreads(data, id, ids.cast<String>());
      await summary(id, value, items);
      return PluginResult.success({'deleted': ids});
    },
    'clearMessages': (_, params) async {
      final id = params['channelId'].toString();
      final value = await channel(id);
      if (value == null) return missing('频道');
      await saveMessages(id, []);
      await data.delete('chat', 'ai_threads/$id.json');
      await summary(id, value, []);
      return PluginResult.success({'channelId': id});
    },
    'findChannel': (_, params) async {
      final items = _filter(await channels(), params);
      return PluginResult.success({'data': items, 'total': items.length});
    },
    'findMessage': (_, params) async {
      final ids = params['channelId'] != null
          ? [params['channelId'].toString()]
          : await channelIds();
      final items = <Map<String, dynamic>>[];
      for (final id in ids) {
        items.addAll(await messages(id));
      }
      final found = _filter(items, params)..sort(compareMessage);
      return PluginResult.success({'data': found, 'total': found.length});
    },
  };
}

List<Map<String, dynamic>> _filter(
  List<Map<String, dynamic>> items,
  Map<String, dynamic> params,
) {
  final field = params['field']?.toString();
  final value = params['value'];
  if (field == null || value == null) return items;
  return items
      .where(
        (item) => params['fuzzy'] == true
            ? (item[field] ?? '').toString().toLowerCase().contains(
                value.toString().toLowerCase(),
              )
            : item[field] == value,
      )
      .toList();
}
