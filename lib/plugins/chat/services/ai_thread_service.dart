import 'dart:async';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'chat_data_service.dart';
import 'package:flutter/foundation.dart';

import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';

/// AI 线程内单条消息（用户追问 / AI 回复）
class AiThreadMessage {
  final String id;
  final String role; // 'user' | 'assistant'
  String content;
  final String type; // 'text' | 'audio'
  String? audioPath;
  int? audioDurationSec;
  String status; // 'thinking' | 'done' | 'error'
  DateTime date;
  final String? agentId;
  final String? agentName;

  AiThreadMessage({
    required this.id,
    required this.role,
    required this.content,
    this.type = 'text',
    this.audioPath,
    this.audioDurationSec,
    this.status = 'done',
    required this.date,
    this.agentId,
    this.agentName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'type': type,
    'audioPath': audioPath,
    'audioDurationSec': audioDurationSec,
    'status': status,
    'date': date.toIso8601String(),
    'agentId': agentId,
    'agentName': agentName,
  };

  static AiThreadMessage fromJson(Map<String, dynamic> json) => AiThreadMessage(
    id: json['id'] as String,
    role: json['role'] as String? ?? 'assistant',
    content: json['content'] as String? ?? '',
    type: json['type'] as String? ?? 'text',
    audioPath: json['audioPath'] as String?,
    audioDurationSec: json['audioDurationSec'] as int?,
    status: json['status'] as String? ?? 'done',
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    agentId: json['agentId'] as String?,
    agentName: json['agentName'] as String?,
  );
}

/// 以频道内一条用户消息为根的 AI 回复线程：
/// @AI 的回复与后续追问都收敛在线程内，不再插入频道消息列表。
class AiThread {
  final String rootMessageId;
  final String channelId;
  final List<String> agentIds;
  final List<AiThreadMessage> messages;

  AiThread({
    required this.rootMessageId,
    required this.channelId,
    List<String>? agentIds,
    List<AiThreadMessage>? messages,
  }) : agentIds = agentIds ?? [],
       messages = messages ?? [];

  int get replyCount => messages
      .where((m) => m.role == 'assistant' && m.status != 'thinking')
      .length;

  bool get isThinking => messages.any((m) => m.status == 'thinking');

  Map<String, dynamic> toJson() => {
    'rootMessageId': rootMessageId,
    'channelId': channelId,
    'agentIds': agentIds,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  static AiThread fromJson(Map<String, dynamic> json) => AiThread(
    rootMessageId: json['rootMessageId'] as String,
    channelId: json['channelId'] as String,
    agentIds: (json['agentIds'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList(),
    messages: (json['messages'] as List<dynamic>? ?? [])
        .map((m) => AiThreadMessage.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
  );
}

/// AI 回复线程服务：内存缓存 + 按频道持久化 + 事件广播。
/// 线程数据与频道消息分离存储（`chat/ai_threads/频道ID.json`），
/// 变化时广播 [AiThreadService.eventUpdated] 供入口行与 drawer 刷新。
class AiThreadService {
  AiThreadService._();
  static final AiThreadService instance = AiThreadService._();

  static const eventUpdated = 'chat_ai_thread_updated';

  ChatPlugin get _plugin =>
      PluginManager.instance.getPlugin('chat')! as ChatPlugin;

  final _threads = <String, AiThread>{};
  final _subscriptions = <String, StreamSubscription<QuerySnapshot>>{};
  final _persistedMessages = <String>{};
  final _channelVersions = <String, int>{};
  int _epoch = 0;

  Future<dynamic> _call(String action, Map<String, dynamic> params) async {
    final epoch = _epoch;
    final response = await AboutmeDataService.instance.call(
      'chat',
      action,
      params,
    );
    if (epoch != _epoch) throw StateError('线程服务已销毁');
    final value = ChatDataService.resultData(response);
    return value is Map
        ? {...value, '_sdkVersion': response['version']}
        : value;
  }

  Future<void> loadAll() async {
    for (final channel in _plugin.channelService.channels) {
      await loadChannel(channel.id);
    }
  }

  Future<void> loadChannel(String channelId) async {
    final epoch = _epoch;
    final response = await AboutmeDataService.instance.get(
      'chat',
      'getThreads',
      {'channelId': channelId},
    );
    if (epoch != _epoch) return;
    _applyChannel(channelId, {
      ...Map<String, dynamic>.from(ChatDataService.resultData(response) as Map),
      '_sdkVersion': response['version'],
    });
    _subscriptions.putIfAbsent(
      channelId,
      () => AboutmeDataService.instance.data
          .watch('chat', 'getThreads', {'channelId': channelId})
          .listen((snapshot) {
            if (snapshot.status == QueryStatus.data &&
                snapshot.result != null) {
              _applyChannel(channelId, {
                ...Map<String, dynamic>.from(
                  ChatDataService.resultData(snapshot.result!) as Map,
                ),
                '_sdkVersion': snapshot.result!['version'],
              });
            } else if (snapshot.error != null) {
              debugPrint('[AiThread] 查询失败: ${snapshot.error}');
            }
          }),
    );
  }

  void _applyChannel(String id, Map<String, dynamic> value) {
    final version = value['_sdkVersion'] as int?;
    if (version != null && version < (_channelVersions[id] ?? -1)) return;
    if (version != null) _channelVersions[id] = version;
    final previous = _threads.values
        .where((t) => t.channelId == id)
        .map((t) => t.rootMessageId)
        .toSet();
    final incoming = value['threads'] as Map? ?? {};
    for (final entry in incoming.entries) {
      _accept({
        ...Map<String, dynamic>.from(entry.value as Map),
        '_sdkVersion': version,
      });
      previous.remove(entry.key);
    }
    for (final root in previous) {
      final removed = _threads.remove(root);
      _persistedMessages.removeAll(removed?.messages.map((m) => m.id) ?? []);
      _notify(root);
    }
  }

  AiThread _accept(Map<String, dynamic> json) {
    final next = AiThread.fromJson(json);
    final version = json['_sdkVersion'] as int?;
    if (version != null && version < (_channelVersions[next.channelId] ?? -1)) {
      return _threads[next.rootMessageId] ?? next;
    }
    if (version != null) _channelVersions[next.channelId] = version;
    final pending =
        _threads[next.rootMessageId]?.messages
            .where((m) => !_persistedMessages.contains(m.id))
            .toList() ??
        [];
    _persistedMessages.addAll(next.messages.map((m) => m.id));
    next.messages.addAll(
      pending.where((m) => !next.messages.any((saved) => saved.id == m.id)),
    );
    _threads[next.rootMessageId] = next;
    _notify(next.rootMessageId);
    return next;
  }

  AiThread? getThread(String rootMessageId) => _threads[rootMessageId];

  Future<AiThread> ensureThread(
    String rootMessageId,
    String channelId,
    String agentId,
  ) async {
    final value = await _call('ensureThread', {
      'channelId': channelId,
      'rootMessageId': rootMessageId,
      'agentId': agentId,
    });
    final thread = _accept(Map<String, dynamic>.from(value as Map));
    if (!_subscriptions.containsKey(channelId)) await loadChannel(channelId);
    return _threads[rootMessageId] ?? thread;
  }

  Future<void> appendMessage(
    String rootMessageId,
    AiThreadMessage message, {
    bool persist = true,
  }) async {
    final thread = _threads[rootMessageId];
    if (thread == null) throw StateError('线程不存在: $rootMessageId');
    if (!persist) {
      thread.messages.add(message);
      _notify(rootMessageId);
      return;
    }
    final value = await _call('appendThreadMessage', {
      'channelId': thread.channelId,
      'rootMessageId': rootMessageId,
      'message': message.toJson(),
      'clientMutationId': 'thread-message:${message.id}',
    });
    _accept(Map<String, dynamic>.from(value as Map));
  }

  Future<void> updateMessage(
    String rootMessageId,
    String messageId, {
    String? content,
    String? status,
    bool persist = true,
  }) async {
    final thread = _threads[rootMessageId];
    final msg = thread?.messages.where((m) => m.id == messageId).firstOrNull;
    if (thread == null || msg == null) throw StateError('线程消息不存在: $messageId');
    if (!persist) {
      if (content != null) msg.content = content;
      if (status != null) msg.status = status;
      _notify(rootMessageId);
      return;
    }
    final patch = <String, dynamic>{
      if (content != null) 'content': content,
      if (status != null) 'status': status,
    };
    if (!_persistedMessages.contains(messageId)) {
      final json = {...msg.toJson(), ...patch};
      final value = await _call('appendThreadMessage', {
        'channelId': thread.channelId,
        'rootMessageId': rootMessageId,
        'message': json,
        'clientMutationId': 'thread-message:$messageId',
      });
      _accept(Map<String, dynamic>.from(value as Map));
    } else {
      final value = await _call('updateThreadMessage', {
        'channelId': thread.channelId,
        'rootMessageId': rootMessageId,
        'messageId': messageId,
        'patch': patch,
      });
      _accept(Map<String, dynamic>.from(value as Map));
    }
  }

  Future<void> removeMessage(String rootMessageId, String messageId) async {
    final thread = _threads[rootMessageId];
    if (thread == null) return;
    if (_persistedMessages.contains(messageId)) {
      final value = await _call('deleteThreadMessage', {
        'channelId': thread.channelId,
        'rootMessageId': rootMessageId,
        'messageId': messageId,
      });
      _accept(Map<String, dynamic>.from(value as Map));
    }
    _threads[rootMessageId]?.messages.removeWhere((m) => m.id == messageId);
    _persistedMessages.remove(messageId);
    _notify(rootMessageId);
  }

  Future<void> removeThread(String rootMessageId) async {
    final thread = _threads[rootMessageId];
    if (thread == null) return;
    await _call('deleteThread', {
      'channelId': thread.channelId,
      'rootMessageId': rootMessageId,
    });
    _threads.remove(rootMessageId);
    _persistedMessages.removeAll(thread.messages.map((m) => m.id));
    _notify(rootMessageId);
  }

  /// 频道消息清空命令已经在同一事务中级联清理线程。
  Future<void> clearChannel(String channelId) async {
    await loadChannel(channelId);
  }

  Future<void> dispose() async {
    _epoch++;
    for (final sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();
    _threads.clear();
    _persistedMessages.clear();
    _channelVersions.clear();
  }

  void _notify(String rootMessageId) {
    EventManager.instance.broadcast(eventUpdated, Value<String>(rootMessageId));
  }
}
