import 'package:aboutme_data_sdk/io.dart';

import '../types.dart';
import '../utils.dart';

// Chat 插件专用处理器（移植自 nodejs handlers/chat.ts）。
//
// 数据格式：
// - channels.json: 频道 ID 列表 {"channels": ["id1", "id2", ...]}
// - channel/{id}.json: 频道详情 {"channel": {...}}
// - messages/{channelId}.json: 频道消息 {"messages": [...]}

PluginHandlers createChatHandlers(PluginDataStore store) {
  Future<List<String>> readChannelIds(
    String userId,
    String encryptionKey,
  ) async {
    final data = await store.readPluginData(
      userId,
      'chat',
      'channels.json',
      encryptionKey,
    );
    if (data is! Map) return [];
    return List<String>.from(
      (data['channels'] as List<dynamic>? ?? []).map((e) => e.toString()),
    );
  }

  Future<void> saveChannelIds(
    String userId,
    String encryptionKey,
    List<String> channelIds,
  ) {
    return store.writePluginData(
      userId,
      'chat',
      'channels.json',
      {'channels': channelIds},
      encryptionKey,
    );
  }

  Future<Map<String, dynamic>?> readChannel(
    String userId,
    String encryptionKey,
    String channelId,
  ) async {
    final data = await store.readPluginData(
      userId,
      'chat',
      'channel/$channelId.json',
      encryptionKey,
    );
    if (data is! Map) return null;
    final channel = data['channel'];
    return channel is Map<String, dynamic> ? channel : null;
  }

  Future<void> saveChannel(
    String userId,
    String encryptionKey,
    String channelId,
    Map<String, dynamic> channel,
  ) {
    return store.writePluginData(
      userId,
      'chat',
      'channel/$channelId.json',
      {'channel': channel},
      encryptionKey,
    );
  }

  Future<List<Map<String, dynamic>>> readMessages(
    String userId,
    String encryptionKey,
    String channelId,
  ) async {
    final data = await store.readPluginData(
      userId,
      'chat',
      'messages/$channelId.json',
      encryptionKey,
    );
    if (data is! Map) return [];
    final messages = data['messages'];
    if (messages is! List) return [];
    return List<Map<String, dynamic>>.from(messages);
  }

  Future<void> saveMessages(
    String userId,
    String encryptionKey,
    String channelId,
    List<Map<String, dynamic>> messages,
  ) {
    return store.writePluginData(
      userId,
      'chat',
      'messages/$channelId.json',
      {'messages': messages},
      encryptionKey,
    );
  }

  return {
    'getList': (userId, encryptionKey, params) async {
      try {
        final channelIds = await readChannelIds(userId, encryptionKey);
        final channels = <Map<String, dynamic>>[];
        for (final channelId in channelIds) {
          final channel = await readChannel(userId, encryptionKey, channelId);
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
    'getById': (userId, encryptionKey, params) async {
      try {
        final channel = await readChannel(
          userId,
          encryptionKey,
          params['id'].toString(),
        );
        if (channel == null) {
          return const PluginResult.failure('频道不存在', 'NOT_FOUND');
        }
        return PluginResult.success(channel);
      } catch (e) {
        return PluginResult.failure('获取频道失败: $e');
      }
    },
    'create': (userId, encryptionKey, params) async {
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

        await saveChannel(userId, encryptionKey, channelId, newChannel);
        await saveMessages(userId, encryptionKey, channelId, []);

        final channelIds = await readChannelIds(userId, encryptionKey);
        if (!channelIds.contains(channelId)) {
          channelIds.add(channelId);
          await saveChannelIds(userId, encryptionKey, channelIds);
        }
        return PluginResult.success(newChannel);
      } catch (e) {
        return PluginResult.failure('创建频道失败: $e');
      }
    },
    'update': (userId, encryptionKey, params) async {
      try {
        final channelId = params['id'].toString();
        final channel = await readChannel(userId, encryptionKey, channelId);
        if (channel == null) {
          return const PluginResult.failure('频道不存在', 'NOT_FOUND');
        }
        final updatedChannel = {
          ...channel,
          ...params,
          'updatedAt': jsIsoDateTime(DateTime.now()),
        };
        await saveChannel(userId, encryptionKey, channelId, updatedChannel);
        return PluginResult.success(updatedChannel);
      } catch (e) {
        return PluginResult.failure('更新频道失败: $e');
      }
    },
    'delete': (userId, encryptionKey, params) async {
      try {
        final channelId = params['id'].toString();
        await store.deletePluginFile(
          userId,
          'chat',
          'channel/$channelId.json',
        );
        await store.deletePluginFile(
          userId,
          'chat',
          'messages/$channelId.json',
        );
        final channelIds = await readChannelIds(userId, encryptionKey);
        await saveChannelIds(
          userId,
          encryptionKey,
          channelIds.where((id) => id != channelId).toList(),
        );
        return PluginResult.success({'id': channelId});
      } catch (e) {
        return PluginResult.failure('删除频道失败: $e');
      }
    },
    'getMessages': (userId, encryptionKey, params) async {
      try {
        final messages = await readMessages(
          userId,
          encryptionKey,
          params['channelId'].toString(),
        );
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
    'sendMessage': (userId, encryptionKey, params) async {
      try {
        final channelId = params['channelId'].toString();
        final messages = await readMessages(userId, encryptionKey, channelId);
        final now = jsIsoDateTime(DateTime.now());
        final newMessage = {
          ...params,
          'id': generateUUID(),
          'channelId': channelId,
          'createdAt': now,
          'updatedAt': now,
        };
        messages.add(newMessage);
        await saveMessages(userId, encryptionKey, channelId, messages);

        final channel = await readChannel(userId, encryptionKey, channelId);
        if (channel != null) {
          channel['lastMessageTime'] = now;
          await saveChannel(userId, encryptionKey, channelId, channel);
        }
        return PluginResult.success(newMessage);
      } catch (e) {
        return PluginResult.failure('发送消息失败: $e');
      }
    },
    'deleteMessage': (userId, encryptionKey, params) async {
      try {
        final channelId = params['channelId'].toString();
        final messageId = params['messageId'].toString();
        final messages = await readMessages(userId, encryptionKey, channelId);
        final index = messages.indexWhere((m) => m['id'] == messageId);
        if (index == -1) {
          return const PluginResult.failure('消息不存在', 'NOT_FOUND');
        }
        messages.removeAt(index);
        await saveMessages(userId, encryptionKey, channelId, messages);
        return PluginResult.success({'id': messageId});
      } catch (e) {
        return PluginResult.failure('删除消息失败: $e');
      }
    },
    'findChannel': (userId, encryptionKey, params) async {
      try {
        final channelIds = await readChannelIds(userId, encryptionKey);
        var channels = <Map<String, dynamic>>[];
        for (final channelId in channelIds) {
          final channel = await readChannel(userId, encryptionKey, channelId);
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
    'findMessage': (userId, encryptionKey, params) async {
      try {
        var messages = <Map<String, dynamic>>[];
        final channelId = params['channelId'];
        if (channelId != null && channelId.toString().isNotEmpty) {
          messages = await readMessages(
            userId,
            encryptionKey,
            channelId.toString(),
          );
        } else {
          final channelIds = await readChannelIds(userId, encryptionKey);
          for (final chId in channelIds) {
            messages = [
              ...messages,
              ...await readMessages(userId, encryptionKey, chId),
            ];
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
