import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';

/// 行为执行器：把生成完成的内容按真人节奏发出去（PRD 5.1.1 分条发送）。
/// 第一条写入占位消息（流式期间用户看到的即是第一条的实时预览），
/// 其余条目在随机延迟后依次作为新消息发出。
class BehaviorExecutor {
  BehaviorExecutor._();
  static final BehaviorExecutor instance = BehaviorExecutor._();

  final _random = Random();

  ChatPlugin get _plugin =>
      PluginManager.instance.getPlugin('chat')! as ChatPlugin;

  /// 按换行与句末标点把完整回复切为 1~maxBubbles 条。
  /// 过短的碎片向后合并，避免"嗯"+"。"这类拆得过碎。
  List<String> splitIntoBubbles(String content, int maxBubbles) {
    final normalized = content.trim();
    if (normalized.isEmpty) return [normalized];

    // 先按换行粗分
    final lines = normalized
        .split(RegExp(r'\n+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 行内再按句末标点细分
    final sentences = <String>[];
    for (final line in lines) {
      final parts = line
          .split(RegExp(r'(?<=[。！？!?~…])\s*'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      sentences.addAll(parts.isEmpty ? [line] : parts);
    }
    if (sentences.isEmpty) return [normalized];

    // 目标条数 = min(maxBubbles, 句子数)，再均衡合并
    var target = min(maxBubbles, sentences.length);
    if (target < 1) target = 1;

    final bubbles = <String>[sentences.first];
    var remaining = sentences.length - 1;
    var slots = target - 1;
    for (var i = 1; i < sentences.length; i++) {
      // 剩余句子足够填满槽位时新开一条，否则并入当前条（均匀分布）
      if (slots > 0 && remaining >= slots) {
        bubbles.add(sentences[i]);
        slots--;
      } else {
        bubbles[bubbles.length - 1] = '${bubbles.last}${sentences[i]}';
      }
      remaining--;
    }
    return bubbles;
  }

  /// 依次发送多条：第一条更新 [typingMessage]，其余新建消息并带随机延迟。
  Future<void> sendBubbles({
    required String channelId,
    required User aiUser,
    required Message typingMessage,
    required List<String> bubbles,
    required String agentId,
    required AlivenessConfig config,
  }) async {
    if (bubbles.isEmpty) return;
    debugPrint('[Aliveness][分条] 共 ${bubbles.length} 条 | '
        '1."${bubbles.first.length > 25 ? "${bubbles.first.substring(0, 25)}…" : bubbles.first}"');

    // 第一条：替换占位消息内容
    typingMessage.content = bubbles.first;
    typingMessage.metadata?.remove('isThinking');
    typingMessage.metadata?['isCompleted'] = true;
    typingMessage.metadata?['completedAt'] =
        DateTime.now().millisecondsSinceEpoch;
    await _plugin.channelService.saveMessage(typingMessage);
    _plugin.refresh();
    EventManager.instance.broadcast(
      'chat_message_updated',
      Value<Message>(typingMessage),
    );

    // 后续条目：延迟逐条发出，模拟连续打字
    for (var i = 1; i < bubbles.length; i++) {
      final delayMs = config.bubbleDelayMinMs +
          _random.nextInt(
            (config.bubbleDelayMaxMs - config.bubbleDelayMinMs)
                    .clamp(1, 10000) +
                1,
          );
      debugPrint('[Aliveness][分条] 第${i + 1}条 延迟${delayMs}ms | '
          '"${bubbles[i].length > 25 ? "${bubbles[i].substring(0, 25)}…" : bubbles[i]}"');
      await Future.delayed(Duration(milliseconds: delayMs));

      final message = await Message.create(
        id:
            'ai_alive_${agentId}_${DateTime.now().millisecondsSinceEpoch}_$i',
        content: bubbles[i],
        channelId: channelId,
        user: aiUser,
        replyToId: typingMessage.replyToId,
        type: MessageType.received,
        metadata: {
          'isAI': true,
          'agentId': agentId,
          'isCompleted': true,
          'completedAt': DateTime.now().millisecondsSinceEpoch,
        },
      );
      await _plugin.channelService.addMessage(channelId, message);
      _plugin.refresh();
      EventManager.instance.broadcast(
        'chat_message_updated',
        Value<Message>(message),
      );
    }
  }
}
