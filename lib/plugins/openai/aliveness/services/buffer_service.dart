import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/utils/image_utils.dart';

/// 缓冲中的会话：等待 flush 的一次"思考窗口"
class AlivenessBuffer {
  final String agentId;
  final String channelId;
  final List<Message> messages = [];
  Message? typingMessage;
  Timer? timer;

  AlivenessBuffer({required this.agentId, required this.channelId});
}

/// 消息缓冲与累积器（PRD 5.1.6）：
/// 用户消息先"已读"并入队，缓冲期内继续收消息则重置计时，
/// 到期后一次性把整段缓冲交给回调统一决策与生成。
class BufferService {
  BufferService._();
  static final BufferService instance = BufferService._();

  final Map<String, AlivenessBuffer> _buffers = {};
  final _random = Random();

  ChatPlugin get _plugin =>
      PluginManager.instance.getPlugin('chat')! as ChatPlugin;

  /// 缓冲时长：亲密度低 → 短等待（体验优先）；亲密度高且惰性高 → 允许更长思考
  int _bufferSeconds(AlivenessConfig config, double intimacy) {
    final range = (config.bufferMaxSec - config.bufferMinSec).clamp(0, 600);
    final t = (intimacy * 0.6 + config.laziness * 0.4).clamp(0.0, 1.0);
    final jitter = _random.nextDouble() * 0.15;
    return (config.bufferMinSec + range * ((t * 0.8 + jitter).clamp(0.0, 1.0)))
        .round();
  }

  /// 入队一条用户消息。首次入队创建占位消息，后续入队只重置计时。
  Future<void> enqueue({
    required String agentId,
    required String agentName,
    required String? agentAvatar,
    required Message userMessage,
    required AlivenessConfig config,
    required double intimacy,
    required Future<void> Function(AlivenessBuffer buffer) onFlush,
  }) async {
    final channelId = userMessage.channelId as String;
    final key = '${agentId}_$channelId';

    // 1) 标记已读（打破"消息发出即被完美处理"的机械感，PRD 5.1.4）
    await _markRead(userMessage, agentId);

    // 记录该 agent 上次互动频道（主动消息的目标频道）
    unawaited(_recordLastChannel(agentId, channelId));

    var buffer = _buffers[key];
    final isNew = buffer == null;
    buffer ??= AlivenessBuffer(agentId: agentId, channelId: channelId);
    _buffers[key] = buffer;
    buffer.messages.add(userMessage);
    debugPrint('[Aliveness][缓冲] ${isNew ? "开始新缓冲" : "并入缓冲并重置计时"} | '
        'agent=$agentId 频道=$channelId 累计=${buffer.messages.length}条 '
        '内容="${_truncate(userMessage.content)}"');

    if (isNew) {
      // 2) 创建"正在想…"占位消息（保持在场感，避免界面无响应）
      final aiUser = User(
        id: agentId,
        username: agentName,
        iconPath: await ImageUtils.getAbsolutePath(agentAvatar),
      );
      buffer.typingMessage = await Message.create(
        id:
            'ai_alive_${agentId}_${DateTime.now().millisecondsSinceEpoch}',
        content: '正在想…',
        channelId: channelId,
        user: aiUser,
        replyToId: userMessage.id,
        type: MessageType.received,
        metadata: {
          'isAI': true,
          'agentId': agentId,
          'isThinking': true,
          'buffering': true,
        },
      );
      await _plugin.channelService.addMessage(channelId, buffer.typingMessage!);
      _plugin.refresh();
      EventManager.instance.broadcast(
        'chat_message_updated',
        Value<Message>(buffer.typingMessage!),
      );
    }

    // 3) 启动/重置缓冲计时器
    buffer.timer?.cancel();
    final seconds = _bufferSeconds(config, intimacy);
    debugPrint('[Aliveness][缓冲] 本次等待 ${seconds}s 后统一回复 '
        '(亲密度=${intimacy.toStringAsFixed(2)} 惰性=${config.laziness})');
    buffer.timer = Timer(Duration(seconds: seconds), () {
      final b = _buffers.remove(key);
      b?.timer?.cancel();
      if (b != null) {
        debugPrint('[Aliveness][缓冲] 计时结束，进入决策生成 | '
            'agent=$agentId 共${b.messages.length}条消息');
        onFlush(b);
      }
    });
  }

  String _truncate(String text, [int len = 30]) =>
      text.length <= len ? text : '${text.substring(0, len)}…';

  /// 记录 agent 上次互动频道与时间（供主动消息定位目标频道）
  Future<void> _recordLastChannel(String agentId, String channelId) async {
    try {
      final store = AlivenessStore.instance;
      final stats = await store.loadStats(agentId);
      stats['lastChannelId'] = channelId;
      stats['lastChannelSeenAt'] = DateTime.now().toIso8601String();
      await store.saveStats(agentId, stats);
    } catch (_) {
      // 统计失败不影响主流程
    }
  }

  Future<void> _markRead(Message message, String agentId) async {    message.metadata ??= {};
    final readBy = List<String>.from(
      (message.metadata!['readBy'] as List<dynamic>? ?? []).map((e) => e.toString()),
    );
    if (!readBy.contains(agentId)) readBy.add(agentId);
    message.metadata!['readBy'] = readBy;
    message.metadata!['readAt'] = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[Aliveness][已读] $agentId 已读消息 ${message.id}');
    await _plugin.channelService.saveMessage(message);
    EventManager.instance.broadcast('chat_message_updated', Value<Message>(message));
  }

  /// 应用退出/插件 dispose 时清理所有计时器
  void dispose() {
    for (final buffer in _buffers.values) {
      buffer.timer?.cancel();
    }
    _buffers.clear();
  }
}
