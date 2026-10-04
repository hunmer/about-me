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

  /// 按换行拆为多条消息（提示词已要求 AI 用换行分隔多条消息）。
  /// 保护：清理 markdown 列表符号；过短行（语气词/单字）并入前一条，
  /// 避免 AI 把一句话拆成碎行导致消息破碎。超 [maxBubbles] 行时合并尾部；
  /// 完全没有换行时按句末标点兜底拆分。
  List<String> splitIntoBubbles(String content, int maxBubbles) {
    final normalized = content.trim();
    if (normalized.isEmpty) return [normalized];

    var target = maxBubbles.clamp(1, 5);

    // 优先：每行一条（AI 主动分条），并清理行首列表符号
    var lines = normalized
        .split(RegExp(r'\n+'))
        .map((l) => l.trim())
        .map((l) => l.replaceFirst(RegExp(r'^([-*•]|\d+[.、)])\s*'), ''))
        .where((l) => l.isNotEmpty)
        .toList();

    // 兜底：完全没有换行时按句末标点拆
    if (lines.length <= 1) {
      lines = normalized
          .split(RegExp(r'(?<=[。！？!?~…])\s*'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
    }
    if (lines.length <= 1) return [normalized];

    // 短行保护：单字语气碎片（"嗯""哈"）并入前一条，正常短句仍独立成条
    final merged = <String>[lines.first];
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].length < 2) {
        merged[merged.length - 1] = '${merged.last}${lines[i]}';
      } else {
        merged.add(lines[i]);
      }
    }
    lines = merged;

    // 超过目标条数：尾部行并入最后一条，不丢内容
    if (lines.length > target) {
      final head = lines.sublist(0, target - 1);
      head.add(lines.sublist(target - 1).join(''));
      return head;
    }
    return lines;
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
