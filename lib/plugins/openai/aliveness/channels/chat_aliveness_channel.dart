import 'dart:async';
import 'dart:math';

import 'package:agentlib/openai_compat.dart';
import 'package:flutter/foundation.dart';

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/services/ai_thread_service.dart';
import 'package:aboutme/plugins/openai/aliveness/aliveness_orchestrator.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/plugins/openai/aliveness/services/voice_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';

/// chat 频道版活人感通道：
/// AI 回复不插入频道消息列表，而是收敛到根消息（@AI 的用户消息）的
/// [AiThread] 中，频道内以【有 xx 条回复】入口呈现，点击打开底部 drawer 续聊。
/// 入口 [handleChatAlivenessMessage] 负责已读标记与互动频道记录，
/// 其余流程统一交给 [AlivenessOrchestrator]。
class ChatAlivenessSession implements AlivenessSessionChannel {
  ChatAlivenessSession({
    required this.agent,
    required this.channelId,
    required this.rootMessageId,
    this.contextCount = 20,
    this.absoluteFilePath,
    this.hasImage = false,
  });

  final AIAgent agent;
  final String channelId;
  final String rootMessageId; // @AI 的用户消息 id（线程根）
  final int contextCount;
  final String? absoluteFilePath;
  final bool hasImage;
  bool _cancelRequested = false;

  final AiThreadService _threads = AiThreadService.instance;

  AiThreadMessage? _placeholder; // "正在想"占位（仅内存，崩溃后自然消失）

  AlivenessConfig get _config =>
      agent.alivenessConfig ?? const AlivenessConfig(enabled: true);

  ChatPlugin get _plugin =>
      PluginManager.instance.getPlugin('chat')! as ChatPlugin;

  @override
  String get scope => 'chat';

  @override
  Future<void> onBufferStart() async {
    await _threads.ensureThread(rootMessageId, channelId, agent.id);
    _placeholder = AiThreadMessage(
      id: 'ai_alive_${agent.id}_${DateTime.now().millisecondsSinceEpoch}',
      role: 'assistant',
      content: '',
      status: 'thinking',
      date: DateTime.now(),
      agentId: agent.id,
      agentName: agent.name,
    );
    await _threads.appendMessage(rootMessageId, _placeholder!, persist: false);
  }

  @override
  Future<void> onNoReply() async {
    final placeholder = _placeholder;
    if (placeholder != null) {
      await _threads.removeMessage(rootMessageId, placeholder.id);
    }
    // 已读不回且线程内没有任何 AI 回复时，连同线程一起清理，不留空入口
    final thread = _threads.getThread(rootMessageId);
    if (thread != null && thread.messages.isEmpty) {
      await _threads.removeThread(rootMessageId);
    }
  }

  @override
  Future<void> onDelay(int seconds) async {
    // thinking 状态由入口行展示，无需额外处理
  }

  @override
  Future<String?> generate(AlivenessGenerationInput input) async {
    final placeholder = _placeholder;
    if (placeholder == null) return null;

    final contextMessages = await _buildContext(input);
    final contentBuffer = StringBuffer();
    _cancelRequested = false;
    await RequestService.streamResponseWithRetry(
      agent: agent,
      prompt: null,
      vision: hasImage,
      filePath: absoluteFilePath,
      contextMessages: contextMessages,
      onToken: (token) async {
        contentBuffer.write(token);
        // 语音呈现时流式文本随后会被删除，保持占位原样避免闪现
        if (input.useVoice) return;
        await _threads.updateMessage(
          rootMessageId,
          placeholder.id,
          content: RequestService.processThinkingContent(
            contentBuffer.toString(),
          ),
          persist: false,
        );
      },
      onError: (error) async {
        await _threads.updateMessage(
          rootMessageId,
          placeholder.id,
          content: '抱歉，生成回复时出现错误：$error',
          status: 'error',
        );
      },
      onComplete: () {},
      shouldCancel: () => _cancelRequested,
      maxRetries: 3,
      retryDelay: 1000,
    );
    return RequestService.processThinkingContent(contentBuffer.toString());
  }

  @override
  Future<void> cancelGeneration() async {
    _cancelRequested = true;
  }

  @override
  Future<bool> sendVoice(String text) async {
    // 替代模式：删除占位后线程内只保留语音消息
    await onNoReply();
    final voice = await VoiceService.instance.synthesize(
      text,
      ttsServiceId: _config.ttsServiceId ?? await _globalVoiceServiceId(),
    );
    if (voice == null) return false;
    await _threads.appendMessage(
      rootMessageId,
      AiThreadMessage(
        id: 'ai_voice_${agent.id}_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: '',
        type: 'audio',
        audioPath: voice.storagePath,
        audioDurationSec: voice.duration.inSeconds,
        status: 'done',
        date: DateTime.now(),
        agentId: agent.id,
        agentName: agent.name,
      ),
    );
    debugPrint('[Aliveness][语音] chat 线程语音消息已写入');
    return true;
  }

  @override
  Future<void> sendBubbles(List<String> bubbles) async {
    final placeholder = _placeholder;
    if (placeholder == null || bubbles.isEmpty) return;
    debugPrint(
      '[Aliveness][分条] 共 ${bubbles.length} 条 | '
      '1."${bubbles.first.length > 25 ? "${bubbles.first.substring(0, 25)}…" : bubbles.first}"',
    );

    // 第一条：落定占位消息
    await _threads.updateMessage(
      rootMessageId,
      placeholder.id,
      content: bubbles.first,
      status: 'done',
    );

    // 后续条目：延迟逐条发出，模拟连续打字
    final random = Random();
    for (var i = 1; i < bubbles.length; i++) {
      final delayMs =
          _config.bubbleDelayMinMs +
          random.nextInt(
            (_config.bubbleDelayMaxMs - _config.bubbleDelayMinMs).clamp(
                  1,
                  10000,
                ) +
                1,
          );
      debugPrint(
        '[Aliveness][分条] 第${i + 1}条 延迟${delayMs}ms | '
        '"${bubbles[i].length > 25 ? "${bubbles[i].substring(0, 25)}…" : bubbles[i]}"',
      );
      await Future.delayed(Duration(milliseconds: delayMs));

      await _threads.appendMessage(
        rootMessageId,
        AiThreadMessage(
          id: 'ai_alive_${agent.id}_${DateTime.now().millisecondsSinceEpoch}_$i',
          role: 'assistant',
          content: bubbles[i],
          status: 'done',
          date: DateTime.now(),
          agentId: agent.id,
          agentName: agent.name,
        ),
      );
    }
  }

  @override
  void reveal() {
    // 线程事件已实时广播，无需额外刷新
  }

  @override
  Future<void> onError(Object error) async {
    final placeholder = _placeholder;
    if (placeholder == null) return;
    await _threads.updateMessage(
      rootMessageId,
      placeholder.id,
      status: 'error',
    );
  }

  /// 上下文组装：system（含活人感注入段）+ 频道历史 + 线程多轮 + 本次缓冲消息
  Future<List<ChatCompletionMessage>> _buildContext(
    AlivenessGenerationInput input,
  ) async {
    final basePrompt = await RequestService.getEffectiveSystemPrompt(agent);
    final systemContent = '$basePrompt\n\n${input.systemSuffix}';

    final messages = <ChatCompletionMessage>[
      ChatCompletionMessage.system(content: systemContent),
    ];

    final thread = _threads.getThread(rootMessageId);
    final threadMessageIds = thread?.messages
        .where((m) => m.role == 'user')
        .map((m) => m.content)
        .toSet();

    // 频道历史（排除根消息/本次缓冲/异常消息）
    final buffered = input.bufferedHandles.whereType<Message>().toList();
    final recent = _plugin.channelService.getRecentMessages(
      channelId,
      contextCount + buffered.length,
    );
    final bufferedIds = buffered.map((m) => m.id).toSet();
    for (final msg in recent) {
      if (msg.id == rootMessageId) continue;
      if (bufferedIds.contains(msg.id)) continue;
      if (msg.metadata?['isThinking'] == true) continue;
      if (msg.metadata?['isError'] == true) continue;
      if (msg.content.contains('抱歉，生成回复时出现错误')) continue;
      if (msg.content.trim().isEmpty) continue;

      if (msg.metadata?['isAI'] == true) {
        messages.add(ChatCompletionMessage.assistant(content: msg.content));
      } else {
        messages.add(
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(msg.content),
          ),
        );
      }
    }

    // 线程内的多轮对话（根消息追问历史；drawer 追问已在此，避免重复）
    if (thread != null) {
      for (final msg in thread.messages) {
        if (msg.status == 'thinking') continue;
        if (msg.role == 'assistant') {
          if (msg.type == 'audio' || msg.content.trim().isEmpty) continue;
          messages.add(ChatCompletionMessage.assistant(content: msg.content));
        } else {
          messages.add(
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string(msg.content),
            ),
          );
        }
      }
    }

    // 本次缓冲的用户消息（频道 @ 场景；drawer 追问无 handle，已在线程历史中）
    for (final msg in buffered) {
      if (threadMessageIds?.contains(msg.content) == true) continue;
      messages.add(
        ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(msg.content),
        ),
      );
    }
    return messages;
  }

  /// 语音消息使用的 TTS 服务（全局配置，未配置则用 TTS 默认服务）
  Future<String?> _globalVoiceServiceId() async {
    try {
      final settings = await AlivenessStore.instance.loadSettings();
      return settings['voiceServiceId'] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// chat 频道活人感入口：已读标记 + 记录互动频道 + 进入通用编排。
/// 仅当 agent.alivenessConfig.enabled 时由 ChatEventHandler 调用。
Future<void> handleChatAlivenessMessage(
  AIAgent agent,
  Message message, {
  String? absoluteFilePath,
  bool hasImage = false,
}) async {
  final channelId = message.channelId as String;

  // 1) 标记已读（打破"消息发出即被完美处理"的机械感）
  await _markRead(message, agent.id);

  // 2) 记录该 agent 上次互动频道（主动消息的目标频道）
  unawaited(_recordLastChannel(agent.id, channelId));

  // 3) 进入通用缓冲编排
  await AlivenessOrchestrator.instance.submit(
    agent: agent,
    targetId: channelId,
    text: message.content,
    messageHandle: message,
    createSession: () => ChatAlivenessSession(
      agent: agent,
      channelId: channelId,
      rootMessageId: message.id,
      contextCount: (message.metadata?['contextCount'] as int?) ?? 20,
      absoluteFilePath: absoluteFilePath,
      hasImage: hasImage,
    ),
  );
}

/// AI 回复线程内的追问入口（底部 drawer 输入）：
/// 追问消息已写入线程，这里只负责把它送入同一套活人感编排。
Future<void> submitAiThreadMessage({
  required AIAgent agent,
  required String channelId,
  required String rootMessageId,
  required String text,
}) async {
  await AlivenessOrchestrator.instance.submit(
    agent: agent,
    targetId: channelId,
    text: text,
    createSession: () => ChatAlivenessSession(
      agent: agent,
      channelId: channelId,
      rootMessageId: rootMessageId,
    ),
  );
}

/// chat 版活人感清理（插件 dispose 时调用）
void disposeChatAliveness() {
  AlivenessOrchestrator.instance.dispose();
}

Future<void> _markRead(Message message, String agentId) async {
  message.metadata ??= {};
  final readBy = List<String>.from(
    (message.metadata!['readBy'] as List<dynamic>? ?? []).map(
      (e) => e.toString(),
    ),
  );
  if (!readBy.contains(agentId)) readBy.add(agentId);
  message.metadata!['readBy'] = readBy;
  message.metadata!['readAt'] = DateTime.now().millisecondsSinceEpoch;
  debugPrint('[Aliveness][已读] $agentId 已读消息 ${message.id}');
  final plugin = PluginManager.instance.getPlugin('chat')! as ChatPlugin;
  await plugin.channelService.saveMessage(message);
  EventManager.instance.broadcast(
    'chat_message_updated',
    Value<Message>(message),
  );
}

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
