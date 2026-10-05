import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:agentlib/openai_compat.dart';

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/openai/aliveness/aliveness_orchestrator.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/plugins/openai/aliveness/services/voice_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';
import 'package:aboutme/utils/image_utils.dart';

/// chat 频道版活人感通道：
/// 占位消息（"正在想…"）→ 流式生成实时更新占位 → 分条逐条发出 / 语音替代。
/// 入口 [handleChatAlivenessMessage] 负责已读标记与互动频道记录，
/// 其余流程统一交给 [AlivenessOrchestrator]。
class ChatAlivenessSession implements AlivenessSessionChannel {
  ChatAlivenessSession({
    required this.agent,
    required this.channelId,
    required this.replyToId,
    this.contextCount = 20,
    this.absoluteFilePath,
    this.hasImage = false,
  });

  final AIAgent agent;
  final String channelId;
  final String replyToId;
  final int contextCount;
  final String? absoluteFilePath;
  final bool hasImage;

  final _random = Random();
  Message? typingMessage;

  ChatPlugin get _plugin =>
      PluginManager.instance.getPlugin('chat')! as ChatPlugin;

  AlivenessConfig get _config =>
      agent.alivenessConfig ?? const AlivenessConfig(enabled: true);

  @override
  String get scope => 'chat';

  @override
  Future<void> onBufferStart() async {
    final aiUser = User(
      id: agent.id,
      username: agent.name,
      iconPath: await ImageUtils.getAbsolutePath(agent.avatarUrl),
    );
    typingMessage = await Message.create(
      id: 'ai_alive_${agent.id}_${DateTime.now().millisecondsSinceEpoch}',
      content: '正在想…',
      channelId: channelId,
      user: aiUser,
      replyToId: replyToId,
      type: MessageType.received,
      metadata: {
        'isAI': true,
        'agentId': agent.id,
        'isThinking': true,
        'buffering': true,
      },
    );
    await _plugin.channelService.addMessage(channelId, typingMessage!);
    _plugin.refresh();
    EventManager.instance.broadcast(
      'chat_message_updated',
      Value<Message>(typingMessage!),
    );
  }

  @override
  Future<void> onNoReply() async {
    final placeholder = typingMessage;
    if (placeholder == null) return;
    await _plugin.channelService.deleteMessage(placeholder);
    _plugin.refresh();
  }

  @override
  Future<void> onDelay(int seconds) async {
    // 占位内容保持"正在想…"即可，无需额外处理
  }

  @override
  Future<String?> generate(AlivenessGenerationInput input) async {
    final placeholder = typingMessage;
    if (placeholder == null) return null;

    final contextMessages = await _buildContext(input);
    final contentBuffer = StringBuffer();
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
        placeholder.content = RequestService.processThinkingContent(
          contentBuffer.toString(),
        );
        await _plugin.channelService.saveMessage(placeholder);
        _plugin.refresh();
      },
      onError: (error) async {
        placeholder.content = '抱歉，生成回复时出现错误：$error';
        placeholder.metadata?.addAll({'isError': true, 'isCompleted': true});
        await _plugin.channelService.saveMessage(placeholder);
        _plugin.refresh();
      },
      onComplete: () {},
      maxRetries: 3,
      retryDelay: 1000,
    );
    return RequestService.processThinkingContent(contentBuffer.toString());
  }

  @override
  Future<bool> sendVoice(String text) async {
    // 替代模式：删除占位后只发语音消息，不再追加文本气泡
    await onNoReply();
    return VoiceService.instance.sendVoiceMessage(
      agentId: agent.id,
      channelId: channelId,
      aiUser: typingMessage?.user ?? await _buildAiUser(),
      text: text,
      ttsServiceId:
          _config.ttsServiceId ?? await _globalVoiceServiceId(),
      replyToId: replyToId,
    );
  }

  @override
  Future<void> sendBubbles(List<String> bubbles) async {
    final placeholder = typingMessage;
    if (placeholder == null || bubbles.isEmpty) return;
    final aiUser = placeholder.user;
    debugPrint('[Aliveness][分条] 共 ${bubbles.length} 条 | '
        '1."${bubbles.first.length > 25 ? "${bubbles.first.substring(0, 25)}…" : bubbles.first}"');

    // 第一条：替换占位消息内容
    placeholder.content = bubbles.first;
    placeholder.metadata?.remove('isThinking');
    placeholder.metadata?['isCompleted'] = true;
    placeholder.metadata?['completedAt'] = DateTime.now().millisecondsSinceEpoch;
    await _plugin.channelService.saveMessage(placeholder);
    _plugin.refresh();
    EventManager.instance.broadcast(
      'chat_message_updated',
      Value<Message>(placeholder),
    );

    // 后续条目：延迟逐条发出，模拟连续打字
    for (var i = 1; i < bubbles.length; i++) {
      final delayMs = _config.bubbleDelayMinMs +
          _random.nextInt(
            (_config.bubbleDelayMaxMs - _config.bubbleDelayMinMs).clamp(1, 10000) +
                1,
          );
      debugPrint('[Aliveness][分条] 第${i + 1}条 延迟${delayMs}ms | '
          '"${bubbles[i].length > 25 ? "${bubbles[i].substring(0, 25)}…" : bubbles[i]}"');
      await Future.delayed(Duration(milliseconds: delayMs));

      final message = await Message.create(
        id: 'ai_alive_${agent.id}_${DateTime.now().millisecondsSinceEpoch}_$i',
        content: bubbles[i],
        channelId: channelId,
        user: aiUser,
        replyToId: placeholder.replyToId,
        type: MessageType.received,
        metadata: {
          'isAI': true,
          'agentId': agent.id,
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

  @override
  void reveal() {
    _plugin.refresh();
  }

  @override
  Future<void> onError(Object error) async {
    final placeholder = typingMessage;
    if (placeholder == null) return;
    placeholder.metadata?.addAll({'isError': true, 'isCompleted': true});
    await _plugin.channelService.saveMessage(placeholder);
    _plugin.refresh();
  }

  /// 上下文组装：system（含活人感注入段）+ 频道历史 + 本次缓冲消息
  Future<List<ChatCompletionMessage>> _buildContext(
    AlivenessGenerationInput input,
  ) async {
    final basePrompt = await RequestService.getEffectiveSystemPrompt(agent);
    final systemContent = '$basePrompt\n\n${input.systemSuffix}';

    final messages = <ChatCompletionMessage>[
      ChatCompletionMessage.system(content: systemContent),
    ];

    // 频道历史（排除本次缓冲消息与占位/错误消息）
    final buffered = input.bufferedHandles.whereType<Message>().toList();
    final recent = _plugin.channelService.getRecentMessages(
      channelId,
      contextCount + buffered.length,
    );
    final bufferedIds = buffered.map((m) => m.id).toSet();
    final placeholderId = typingMessage?.id;
    for (final msg in recent) {
      if (bufferedIds.contains(msg.id)) continue;
      if (msg.id == placeholderId) continue;
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

    // 本次缓冲的用户消息（保证不被历史窗口挤掉）
    for (final msg in buffered) {
      messages.add(
        ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(msg.content),
        ),
      );
    }
    return messages;
  }

  Future<User> _buildAiUser() async => User(
    id: agent.id,
    username: agent.name,
    iconPath: await ImageUtils.getAbsolutePath(agent.avatarUrl),
  );

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
      replyToId: message.id,
      contextCount:
          (message.metadata?['contextCount'] as int?) ?? 20,
      absoluteFilePath: absoluteFilePath,
      hasImage: hasImage,
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
    (message.metadata!['readBy'] as List<dynamic>? ?? [])
        .map((e) => e.toString()),
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
