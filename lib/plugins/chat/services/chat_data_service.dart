import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/core/event/event.dart' as aboutme_event;
import 'package:aboutme/core/services/plugin_widget_sync_helper.dart';
import 'package:aboutme/plugins/chat/services/widget_service.dart';

/// UI 模型适配器。所有权威读取与变更均由 SDK 执行。
class ChatDataService {
  ChatDataService(this._plugin);
  final ChatPlugin _plugin;
  final List<Channel> _channels = [];
  final _channelSnapshots = <String, Map<String, dynamic>>{};
  final _messageSnapshots = <String, Map<String, dynamic>>{};
  StreamSubscription<QuerySnapshot>? _channelSubscription;
  StreamSubscription<QuerySnapshot>? _statsSubscription;
  String? _statsDay;
  int _todayMessageCount = 0;
  String? _currentChannelId;
  bool _disposed = false;
  int _channelGeneration = 0;

  AboutmeData get _data => AboutmeDataService.instance.data;
  List<Channel> get channels => _channels;
  Channel? get currentChannel => channelById(_currentChannelId);
  Channel? channelById(String? id) =>
      _channels.where((c) => c.id == id).firstOrNull;

  static dynamic resultData(Map<String, dynamic> result) {
    if (result['success'] != true) throw QueryFailure(result);
    return result['data'];
  }

  Future<dynamic> _call(
    String action, [
    Map<String, dynamic> params = const {},
  ]) async {
    final response = await _data.call('chat', action, params);
    final value = resultData(response);
    return value is Map && value.containsKey('id')
        ? {...value, '_sdkVersion': response['version']}
        : value;
  }

  Future<void> initialize() async {
    await reloadChannels();
    _listenStats();
    _channelSubscription = _data.watch('chat', 'getList').listen((snapshot) {
      if (snapshot.status == QueryStatus.data && snapshot.result != null) {
        unawaited(
          _applyChannels(snapshot.result!).catchError((Object error) {
            debugPrint('[Chat] 频道订阅失败: $error');
          }),
        );
      } else if (snapshot.error != null) {
        debugPrint('[Chat] 频道查询失败: ${snapshot.error}');
      }
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _channelGeneration++;
    await _channelSubscription?.cancel();
    await _statsSubscription?.cancel();
  }

  Future<void> loadSampleData() async {
    await _call('seedExamples', {
      'groups': ['channels'],
      'templateVersion': 1,
    });
    await reloadChannels();
  }

  Future<void> _applyChannels(Map<String, dynamic> response) async {
    final generation = ++_channelGeneration;
    final page = resultData(response) as Map;
    final loaded = <Channel>[];
    final snapshots = <String, Map<String, dynamic>>{};
    for (final raw in page['data'] as List) {
      final json = {
        ...Map<String, dynamic>.from(raw as Map),
        '_sdkVersion': response['version'],
      };
      final old = channelById(json['id'] as String);
      final last = json['lastMessage'];
      final value = Channel.fromJson(json, messages: old?.messages ?? []);
      value.lastMessage = last is Map
          ? await Message.fromJson(Map<String, dynamic>.from(last))
          : null;
      loaded.add(value);
      value.sdkSnapshot = _copy(value.toJson());
      snapshots[value.id] = value.sdkSnapshot!;
    }
    if (_disposed || generation != _channelGeneration) return;
    _channelSnapshots
      ..clear()
      ..addAll(snapshots);
    _channels
      ..clear()
      ..addAll(loaded..sort(Channel.compare));
    _plugin.refresh();
  }

  Future<void> reloadChannels() async =>
      _applyChannels(await _data.get('chat', 'getList'));

  Future<Channel?> getChannel(String id) async {
    final response = await _data.get('chat', 'getById', {'id': id});
    if (response['code'] == 'NOT_FOUND') return null;
    return _acceptChannel({
      ...Map<String, dynamic>.from(resultData(response) as Map),
      '_sdkVersion': response['version'],
    });
  }

  Channel _acceptChannel(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final value = Channel.fromJson(
      json,
      messages: channelById(id)?.messages ?? [],
    );
    value.sdkSnapshot = _copy(value.toJson());
    _channelSnapshots[id] = value.sdkSnapshot!;
    final index = _channels.indexWhere((c) => c.id == id);
    if (index < 0) {
      _channels.add(value);
    } else {
      _channels[index] = value;
    }
    _channels.sort(Channel.compare);
    return value;
  }

  void setCurrentChannel(Channel? channel) {
    _currentChannelId = channel?.id;
    _plugin.refresh();
  }

  Future<void> createChannel(Channel channel) async {
    final json = await _call('create', {
      ...channel.toJson(),
      'clientMutationId': 'channel:${channel.id}',
    });
    _acceptChannel(Map<String, dynamic>.from(json as Map));
    _plugin.refresh();
    aboutme_event.EventManager.instance.broadcast(
      'chat_channel_added',
      aboutme_event.EventArgs('chat_channel_added'),
    );
  }

  Future<Channel> patchChannel(
    String id,
    Map<String, dynamic> patch, {
    int? expectedVersion,
  }) async {
    final json = await _call('patch', {
      ...patch,
      'id': id,
      if (expectedVersion != null) 'expectedVersion': expectedVersion,
    });
    final value = _acceptChannel(Map<String, dynamic>.from(json as Map));
    _plugin.refresh();
    await PluginWidgetSyncHelper.instance.syncChat();
    return value;
  }

  /// 兼容可编辑 UI 模型，只发送相对已读取快照发生变化的字段。
  Future<void> saveChannel(Channel channel) async {
    final previous = channel.sdkSnapshot ?? _channelSnapshots[channel.id];
    if (previous == null) throw StateError('保存频道前必须先查询: ${channel.id}');
    final patch = _diff(previous, channel.toJson())
      ..remove('lastMessageTime')
      ..remove('id');
    if (patch.isNotEmpty) {
      await patchChannel(
        channel.id,
        patch,
        expectedVersion: channel.sdkVersion,
      );
    }
  }

  Future<void> deleteChannel(String channelId) async {
    await _call('delete', {'id': channelId});
    _channels.removeWhere((c) => c.id == channelId);
    _channelSnapshots.remove(channelId);
    if (_currentChannelId == channelId) _currentChannelId = null;
    _plugin.refresh();
    await PluginWidgetSyncHelper.instance.syncChat();
  }

  Future<void> deleteChannelMessages(String channelId) async {
    await _call('clearMessages', {'channelId': channelId});
    channelById(channelId)?.messages.clear();
    await reloadChannels();
  }

  Future<void> updateChannelColor(String id, Color color) async =>
      patchChannel(id, {
        'backgroundColor':
            '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
      });
  Future<Channel> updateChannelMetadata(
    String id,
    Map<String, dynamic> metadata,
  ) => patchChannel(id, {'metadata': metadata});
  Future<Channel> updateChannelBackground(String id, String path) =>
      patchChannel(id, {'backgroundPath': path.replaceAll('\\', '/')});
  Future<void> updateChannelFixedSymbol(String id, String? symbol) async =>
      patchChannel(id, {'fixedSymbol': symbol});
  Future<void> saveDraft(String id, String draft) async =>
      patchChannel(id, {'draft': draft.trim().isEmpty ? null : draft});
  Future<void> saveChannels() async {
    for (final channel in [..._channels]) {
      await saveChannel(channel);
    }
  }
  Future<void> reorderChannels(List<String> ids) async {
    await _call('reorderChannels', {'ids': ids});
    await reloadChannels();
  }

  Future<String?> loadDraft(String id) async => (await getChannel(id))?.draft;

  Future<Message> _acceptMessage(Map<String, dynamic> json) async {
    final value = await Message.fromJson(json);
    value.sdkSnapshot = _copy(await value.toJson());
    value.sdkVersion = json['_sdkVersion'] as int?;
    _messageSnapshots[value.id] = value.sdkSnapshot!;
    final channel = channelById(value.channelId);
    if (channel != null) {
      final index = channel.messages.indexWhere((m) => m.id == value.id);
      if (index < 0) {
        channel.messages.add(value);
      } else {
        channel.messages[index] = value;
      }
      if (channel.lastMessage == null ||
          !value.date.isBefore(channel.lastMessage!.date)) {
        channel.lastMessage = value;
      }
    }
    return value;
  }

  Future<bool> saveMessage(Message message) async {
    final channelId = message.channelId;
    if (channelId == null) throw ArgumentError('消息缺少 channelId');
    final found =
        await _call('findMessage', {
              'channelId': channelId,
              'field': 'id',
              'value': message.id,
            })
            as Map;
    if ((found['data'] as List).isEmpty) {
      await addMessage(channelId, message);
    } else {
      await updateMessage(message);
    }
    return true;
  }

  Future<Message> addMessage(String channelId, Message message) async {
    final json = await _call('sendMessage', {
      ...await message.toJson(),
      'user': message.user.toJson(),
      'channelId': channelId,
      'clientMutationId': 'message:${message.id}',
    });
    final saved = await _acceptMessage(Map<String, dynamic>.from(json as Map));
    _plugin.refresh();
    aboutme_event.EventManager.instance.broadcast(
      'chat_message_updated',
      aboutme_event.Value<Message>(saved, 'chat_message_updated'),
    );
    return saved;
  }

  Future<bool> deleteMessageById(String channelId, String messageId) async {
    await _call('deleteMessage', {
      'channelId': channelId,
      'messageId': messageId,
    });
    channelById(channelId)?.messages.removeWhere((m) => m.id == messageId);
    _messageSnapshots.remove(messageId);
    await reloadChannels();
    return true;
  }

  Future<bool> deleteMessage(Message message) async {
    if (message.channelId == null) throw ArgumentError('消息缺少 channelId');
    return deleteMessageById(message.channelId!, message.id);
  }

  Future<void> deleteMessages(String channelId, List<String> ids) async {
    await _call('deleteMessages', {'channelId': channelId, 'messageIds': ids});
    channelById(channelId)?.messages.removeWhere((m) => ids.contains(m.id));
    for (final id in ids) {
      _messageSnapshots.remove(id);
    }
    await reloadChannels();
  }

  Future<void> updateMessage(Message message, {bool persist = true}) async {
    if (!persist) {
      final items = channelById(message.channelId)?.messages;
      final index = items?.indexWhere((m) => m.id == message.id) ?? -1;
      if (index >= 0) items![index] = message;
      _plugin.refresh();
      return;
    }
    if (message.channelId == null) throw ArgumentError('消息缺少 channelId');
    final json = await message.toJson();
    final before = message.sdkSnapshot ?? _messageSnapshots[message.id];
    // 未加载的消息必须明确调用局部更新，不能凭新模型默认值覆盖已有字段。
    if (before == null) throw StateError('编辑消息前必须先查询: ${message.id}');
    final patch = _diff(before, json)
      ..remove('id')
      ..remove('date')
      ..remove('user');
    if (patch.isEmpty) return;
    final saved = await _call('updateMessage', {
      ...patch,
      'channelId': message.channelId,
      'messageId': message.id,
      if (message.sdkVersion != null) 'expectedVersion': message.sdkVersion,
    });
    final committed = await _acceptMessage(
      Map<String, dynamic>.from(saved as Map),
    );
    aboutme_event.EventManager.instance.broadcast(
      'chat_message_updated',
      aboutme_event.Value<Message>(committed, 'chat_message_updated'),
    );
    _plugin.refresh();
    await ChatWidgetService.updateWidget();
  }

  Future<List<Message>> _decode(List values, {int? version}) async =>
      Future.wait(
        values.map(
          (raw) => _acceptMessage({
            ...Map<String, dynamic>.from(raw as Map),
            '_sdkVersion': version,
          }),
        ),
      );

  /// 页面订阅最新页，历史页通过稳定游标读取。一次失效重新查询当前窗口。
  Stream<List<Message>> watchMessages(
    String channelId, {
    int pages = 1,
    String? throughMessageId,
  }) => Stream.multi((controller) {
    var generation = 0;
    var closed = false;
    final subscription = _data
        .watch('chat', 'getMessages', {'channelId': channelId, 'limit': 50})
        .listen((snapshot) async {
          final current = ++generation;
          if (snapshot.status != QueryStatus.data || snapshot.result == null) {
            if (snapshot.error != null) controller.addError(snapshot.error!);
            return;
          }
          try {
            var page = resultData(snapshot.result!) as Map;
            final rows = <dynamic>[...page['data'] as List];
            var pageCount = 1;
            while (page['nextCursor'] != null &&
                (pageCount < pages ||
                    (throughMessageId != null &&
                        !rows.any((m) => m['id'] == throughMessageId)))) {
              page =
                  resultData(
                        await _data.get('chat', 'getMessages', {
                          'channelId': channelId,
                          'limit': 50,
                          'before': page['nextCursor'],
                        }),
                      )
                      as Map;
              rows.addAll(page['data'] as List);
              pageCount++;
              if (closed || current != generation) return;
            }
            if (closed || current != generation) return;
            final decoded = await _decode(
              rows,
              version: snapshot.result!['version'] as int?,
            );
            if (closed || current != generation) return;
            final unique =
                {
                  for (final message in decoded) message.id: message,
                }.values.toList()..sort((a, b) {
                  final time = b.date.compareTo(a.date);
                  return time != 0 ? time : b.id.compareTo(a.id);
                });
            channelById(channelId)?.messages
              ?..clear()
              ..addAll(unique.reversed);
            controller.add(unique);
          } catch (error, stack) {
            if (!closed && current == generation) {
              controller.addError(error, stack);
            }
          }
        });
    controller.onCancel = () async {
      closed = true;
      generation++;
      await subscription.cancel();
    };
  });

  Future<List<Message>?> getChannelMessages(String channelId) async {
    final response = await _data.get('chat', 'getMessages', {
      'channelId': channelId,
    });
    if (response['code'] == 'NOT_FOUND') return null;
    final decoded = await _decode(
      (resultData(response) as Map)['data'] as List,
      version: response['version'] as int?,
    );
    final channel = channelById(channelId);
    channel?.messages
      ?..clear()
      ..addAll(decoded);
    return decoded;
  }

  Message? getMessageById(String messageId) => _channels
      .expand((c) => c.messages)
      .where((m) => m.id == messageId)
      .firstOrNull;
  Future<List<Message>> getAllMessages() async {
    final response = await _data.get('chat', 'findMessage');
    return _decode((resultData(response) as Map)['data'] as List, version: response['version'] as int?);
  }
  Stream<List<Message>> watchAllMessages() => _data.watch('chat', 'findMessage')
      .where((snapshot) => snapshot.status == QueryStatus.data || snapshot.status == QueryStatus.error)
      .asyncMap((snapshot) {
        if (snapshot.error != null) throw snapshot.error!;
        return _decode((resultData(snapshot.result!) as Map)['data'] as List, version: snapshot.result!['version'] as int?);
      });
  List<Message> getMessagesBefore(
    String messageId,
    int count, {
    String? channelId,
  }) {
    final items = channelById(channelId)?.messages ?? <Message>[];
    final index = items.indexWhere((m) => m.id == messageId);
    return index < 0 ? [] : items.sublist(max(0, index - count), index);
  }

  Future<List<Message>> getRecentMessages(String channelId, int count) async {
    if (count <= 0) return [];
    final response = await _data.get('chat', 'getMessages', {
      'channelId': channelId,
      'limit': count,
    });
    return _decode(
      (resultData(response) as Map)['data'] as List,
      version: response['version'] as int?,
    );
  }

  Future<Message?> loadReplyMessage(String? id) async {
    if (id == null) return null;
    final response = await _data.get('chat', 'findMessage', {'field': 'id', 'value': id});
    final found = (resultData(response) as Map)['data'] as List;
    return found.isEmpty ? null : _acceptMessage({...Map<String, dynamic>.from(found.first as Map), '_sdkVersion': response['version']});
  }
  void _listenStats() {
    final day = DateTime.now().toIso8601String().substring(0, 10);
    if (_disposed || _statsDay == day) return;
    _statsDay = day;
    _statsSubscription?.cancel();
    _statsSubscription = _data.watch('chat', 'getStats', {'date': day, 'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes}).listen((snapshot) {
      if (snapshot.status == QueryStatus.data && snapshot.result != null) {
        _todayMessageCount = (resultData(snapshot.result!) as Map)['todayMessageCount'] as int;
        _plugin.refresh();
      } else if (snapshot.error != null) { debugPrint('[Chat] 统计查询失败: ${snapshot.error}'); }
    });
  }
  int getTodayMessageCount() { _listenStats(); return _todayMessageCount; }
  int getTotalMessageCount() =>
      _channels.fold(0, (count, c) => count + c.messageCount);

  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  static Map<String, dynamic> _diff(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) => {
    for (final entry in after.entries)
      if (jsonEncode(before[entry.key]) != jsonEncode(entry.value))
        entry.key:
            entry.key == 'metadata' &&
                before[entry.key] is Map &&
                entry.value is Map
            ? _diff(
                Map<String, dynamic>.from(before[entry.key] as Map),
                Map<String, dynamic>.from(entry.value as Map),
              )
            : entry.value,
  };
}
