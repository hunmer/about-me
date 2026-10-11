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

  static AiThreadMessage fromJson(Map<String, dynamic> json) =>
      AiThreadMessage(
        id: json['id'] as String,
        role: json['role'] as String? ?? 'assistant',
        content: json['content'] as String? ?? '',
        type: json['type'] as String? ?? 'text',
        audioPath: json['audioPath'] as String?,
        audioDurationSec: json['audioDurationSec'] as int?,
        status: json['status'] as String? ?? 'done',
        date:
            DateTime.tryParse(json['date'] as String? ?? '') ??
            DateTime.now(),
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

  int get replyCount =>
      messages.where((m) => m.role == 'assistant' && m.status != 'thinking').length;

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
    agentIds:
        (json['agentIds'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
    messages:
        (json['messages'] as List<dynamic>? ?? [])
            .map(
              (m) => AiThreadMessage.fromJson(Map<String, dynamic>.from(m)),
            )
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
  final _loadedChannels = <String>{};

  /// 启动时全量加载（频道数有限，直接读入内存最简单可靠）
  Future<void> loadAll() async {
    try {
      for (final channel in _plugin.channelService.channels) {
        await _loadChannel(channel.id);
      }
    } catch (e) {
      debugPrint('[AiThread] 加载线程失败: $e');
    }
  }

  Future<void> _loadChannel(String channelId) async {
    if (_loadedChannels.contains(channelId)) return;
    _loadedChannels.add(channelId);
    try {
      final data = await AboutmeDataService.instance.readPath('chat/ai_threads/$channelId.json');
      final threadsJson = data['threads'] as Map<String, dynamic>? ?? {};
      threadsJson.forEach((rootId, value) {
        _threads[rootId] = AiThread.fromJson(
          Map<String, dynamic>.from(value as Map),
        );
      });
    } catch (e) {
      debugPrint('[AiThread] 加载频道 $channelId 线程失败: $e');
    }
  }

  AiThread? getThread(String rootMessageId) => _threads[rootMessageId];

  /// 获取或创建线程（同一线程追加 @ 到的 agent）
  Future<AiThread> ensureThread(
    String rootMessageId,
    String channelId,
    String agentId,
  ) async {
    await _loadChannel(channelId);
    var thread = _threads[rootMessageId];
    if (thread == null) {
      thread = AiThread(rootMessageId: rootMessageId, channelId: channelId);
      _threads[rootMessageId] = thread;
    }
    if (!thread.agentIds.contains(agentId)) {
      thread.agentIds.add(agentId);
    }
    await _persist(thread);
    _notify(rootMessageId);
    return thread;
  }

  /// 追加消息（流式生成的 thinking 占位可不持久化，崩溃后状态自然干净）
  Future<void> appendMessage(
    String rootMessageId,
    AiThreadMessage message, {
    bool persist = true,
  }) async {
    final thread = _threads[rootMessageId];
    if (thread == null) return;
    thread.messages.add(message);
    if (persist) await _persist(thread);
    _notify(rootMessageId);
  }

  /// 原地更新线程内消息（流式 token 高频调用，persist=false 只更新内存并广播）
  Future<void> updateMessage(
    String rootMessageId,
    String messageId, {
    String? content,
    String? status,
    bool persist = true,
  }) async {
    final thread = _threads[rootMessageId];
    final msg = thread?.messages.where((m) => m.id == messageId).firstOrNull;
    if (msg == null) return;
    if (content != null) msg.content = content;
    if (status != null) msg.status = status;
    if (persist) await _persist(thread!);
    _notify(rootMessageId);
  }

  Future<void> removeMessage(String rootMessageId, String messageId) async {
    final thread = _threads[rootMessageId];
    if (thread == null) return;
    thread.messages.removeWhere((m) => m.id == messageId);
    await _persist(thread);
    _notify(rootMessageId);
  }

  /// 根消息被删除时级联清理线程
  Future<void> removeThread(String rootMessageId) async {
    final thread = _threads.remove(rootMessageId);
    if (thread == null) return;
    await _deleteRoot(rootMessageId, thread.channelId);
    _notify(rootMessageId);
  }

  Future<void> clearChannel(String channelId) async {
    final removed = _threads.values
        .where((t) => t.channelId == channelId)
        .map((t) => t.rootMessageId)
        .toList();
    if (removed.isEmpty) return;
    _threads.removeWhere((_, t) => t.channelId == channelId);
    try {
      await AboutmeDataService.instance.writePath('chat/ai_threads/$channelId.json', {
        'threads': {},
      });
    } catch (e) {
      debugPrint('[AiThread] 清空频道线程失败: $e');
    }
    for (final rootId in removed) {
      _notify(rootId);
    }
  }

  Future<void> _persist(AiThread thread) async {
    try {
      final data = await AboutmeDataService.instance.readPath(
        'chat/ai_threads/${thread.channelId}.json',
      );
      final threadsJson =
          Map<String, dynamic>.from(data['threads'] as Map? ?? {});
      threadsJson[thread.rootMessageId] = thread.toJson();
      await AboutmeDataService.instance.writePath(
        'chat/ai_threads/${thread.channelId}.json',
        {'threads': threadsJson},
      );
    } catch (e) {
      debugPrint('[AiThread] 持久化线程失败: $e');
    }
  }

  Future<void> _deleteRoot(String rootMessageId, String channelId) async {
    try {
      final data = await AboutmeDataService.instance.readPath('chat/ai_threads/$channelId.json');
      final threadsJson =
          Map<String, dynamic>.from(data['threads'] as Map? ?? {});
      threadsJson.remove(rootMessageId);
      await AboutmeDataService.instance.writePath('chat/ai_threads/$channelId.json', {
        'threads': threadsJson,
      });
    } catch (e) {
      debugPrint('[AiThread] 删除线程失败: $e');
    }
  }

  void _notify(String rootMessageId) {
    EventManager.instance.broadcast(eventUpdated, Value<String>(rootMessageId));
  }
}
