import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';

// Chat 插件专用处理器（移植自 nodejs handlers/chat.ts）。
//
// 数据格式：
// - channels.json: 频道 ID 列表 {"channels": ["id1", "id2", ...]}
// - channel/{id}.json: 频道详情 {"channel": {...}}
// - messages/{channelId}.json: 频道消息 {"messages": [...]}

PluginHandlers createChatHandlers(PluginData data) {
  Future<List<String>> readChannelIds() async {
    final content = await data.read('chat', 'channels.json');
    if (content is! Map) return [];
    return List<String>.from(
      (content['channels'] as List<dynamic>? ?? []).map((e) => e.toString()),
    );
  }

  Future<void> saveChannelIds(List<String> channelIds) {
    return data.write('chat', 'channels.json', {'channels': channelIds});
  }

  Future<Map<String, dynamic>?> readChannel(String channelId) async {
    final content = await data.read('chat', 'channel/$channelId.json');
    if (content is! Map) return null;
    final channel = content['channel'];
    return channel is Map<String, dynamic> ? channel : null;
  }

  Future<void> saveChannel(String channelId, Map<String, dynamic> channel) {
    return data.write('chat', 'channel/$channelId.json', {'channel': channel});
  }

  Future<List<Map<String, dynamic>>> readMessages(String channelId) async {
    final content = await data.read('chat', 'messages/$channelId.json');
    if (content is! Map) return [];
    final messages = content['messages'];
    if (messages is! List) return [];
    return List<Map<String, dynamic>>.from(messages);
  }

  Future<void> saveMessages(
    String channelId,
    List<Map<String, dynamic>> messages,
  ) {
    return data.write(
      'chat',
      'messages/$channelId.json',
      {'messages': messages},
    );
  }

  return {
    'getList': (data, params) async {
      try {
        final channelIds = await readChannelIds();
        final channels = <Map<String, dynamic>>[];
        for (final channelId in channelIds) {
          final channel = await readChannel(channelId);
          if (channel != null) channels.add(channel);
        }
        return PluginResult.success(
          createPaginatedResult(
            channels,
            offset: params['offset'] as int?,
            count: params['count'] as int?,
          ),
        );
      } catch (e) {
        return PluginResult.failure('获取频道失败: $e');
      }
    },
    'getById': (data, params) async {
      try {
        final channel = await readChannel(params['id'].toString());
        if (channel == null) {
          return const PluginResult.failure('频道不存在', 'NOT_FOUND');
        }
        return PluginResult.success(channel);
      } catch (e) {
        return PluginResult.failure('获取频道失败: $e');
      }
    },
    'create': (data, params) async {
      try {
        final channelId =
            (params['id'] as String?)?.isNotEmpty == true
            ? params['id'] as String
            : generateUUID();
        final now = jsIsoDateTime(DateTime.now());
        final newChannel = {
          ...params,
          'id': channelId,
          'createdAt': now,
          'updatedAt': now,
        };

        await saveChannel(channelId, newChannel);
        await saveMessages(channelId, []);

        final channelIds = await readChannelIds();
        if (!channelIds.contains(channelId)) {
          channelIds.add(channelId);
          await saveChannelIds(channelIds);
        }
        return PluginResult.success(newChannel);
      } catch (e) {
        return PluginResult.failure('创建频道失败: $e');
      }
    },
    'update': (data, params) async {
      try {
        final channelId = params['id'].toString();
        final channel = await readChannel(channelId);
        if (channel == null) {
          return const PluginResult.failure('频道不存在', 'NOT_FOUND');
        }
        final updatedChannel = {
          ...channel,
          ...params,
          'updatedAt': jsIsoDateTime(DateTime.now()),
        };
        await saveChannel(channelId, updatedChannel);
        return PluginResult.success(updatedChannel);
      } catch (e) {
        return PluginResult.failure('更新频道失败: $e');
      }
    },
    'delete': (data, params) async {
      try {
        final channelId = params['id'].toString();
        await data.delete('chat', 'channel/$channelId.json');
        await data.delete('chat', 'messages/$channelId.json');
        final channelIds = await readChannelIds();
        await saveChannelIds(channelIds.where((id) => id != channelId).toList());
        return PluginResult.success({'id': channelId});
      } catch (e) {
        return PluginResult.failure('删除频道失败: $e');
      }
    },
    'getMessages': (data, params) async {
      try {
        final messages = await readMessages(params['channelId'].toString());
        return PluginResult.success(
          createPaginatedResult(
            messages,
            offset: params['offset'] as int?,
            count: params['count'] as int?,
          ),
        );
      } catch (e) {
        return PluginResult.failure('读取消息失败: $e');
      }
    },
    'sendMessage': (data, params) async {
      try {
        final channelId = params['channelId'].toString();
        final messages = await readMessages(channelId);
        final now = jsIsoDateTime(DateTime.now());
        final newMessage = {
          ...params,
          'id': generateUUID(),
          'channelId': channelId,
          'createdAt': now,
          'updatedAt': now,
        };
        messages.add(newMessage);
        await saveMessages(channelId, messages);

        final channel = await readChannel(channelId);
        if (channel != null) {
          channel['lastMessageTime'] = now;
          await saveChannel(channelId, channel);
        }
        return PluginResult.success(newMessage);
      } catch (e) {
        return PluginResult.failure('发送消息失败: $e');
      }
    },
    'deleteMessage': (data, params) async {
      try {
        final channelId = params['channelId'].toString();
        final messageId = params['messageId'].toString();
        final messages = await readMessages(channelId);
        final index = messages.indexWhere((m) => m['id'] == messageId);
        if (index == -1) {
          return const PluginResult.failure('消息不存在', 'NOT_FOUND');
        }
        messages.removeAt(index);
        await saveMessages(channelId, messages);
        return PluginResult.success({'id': messageId});
      } catch (e) {
        return PluginResult.failure('删除消息失败: $e');
      }
    },
    'findChannel': (data, params) async {
      try {
        final channelIds = await readChannelIds();
        var channels = <Map<String, dynamic>>[];
        for (final channelId in channelIds) {
          final channel = await readChannel(channelId);
          if (channel != null) channels.add(channel);
        }
        channels = _filterByField(channels, params);
        return PluginResult.success({
          'data': channels,
          'total': channels.length,
        });
      } catch (e) {
        return PluginResult.failure('查找频道失败: $e');
      }
    },
    'findMessage': (data, params) async {
      try {
        var messages = <Map<String, dynamic>>[];
        final channelId = params['channelId'];
        if (channelId != null && channelId.toString().isNotEmpty) {
          messages = await readMessages(channelId.toString());
        } else {
          final channelIds = await readChannelIds();
          for (final chId in channelIds) {
            messages = [...messages, ...await readMessages(chId)];
          }
        }
        messages = _filterByField(messages, params);
        return PluginResult.success({
          'data': messages,
          'total': messages.length,
        });
      } catch (e) {
        return PluginResult.failure('查找消息失败: $e');
      }
    },
  };
}

/// 按 field/value 过滤，fuzzy=true 时为包含匹配。
List<Map<String, dynamic>> _filterByField(
  List<Map<String, dynamic>> items,
  Map<String, dynamic> params,
) {
  final field = params['field']?.toString();
  final value = params['value'];
  if (field == null || field.isEmpty || value == null) return items;
  final fuzzy = params['fuzzy'] == true || params['fuzzy'].toString() == 'true';
  if (fuzzy) {
    return items
        .where(
          (item) => (item[field]?.toString() ?? '')
              .toLowerCase()
              .contains(value.toString().toLowerCase()),
        )
        .toList();
  }
  return items.where((item) => item[field] == value).toList();
}
