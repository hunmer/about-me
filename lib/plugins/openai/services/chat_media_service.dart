import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentlib/openai_compat.dart';
import 'package:aboutme/plugins/agent_chat/services/native_tool_agent_service.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'request_service.dart';

/// 频道与活人感共用的图片上下文：主会话仅传路径或已保存的描述。
class ChatMediaService {
  static List<String> imagePaths(Message message) {
    final info =
        (message.metadata?['fileInfo'] ?? message.metadata?['file']) as Map?;
    if (info == null) return [];
    final paths = <String>{};
    final images = info['images'];
    if (images is List) paths.addAll(images.whereType<String>());
    final path = info['path'];
    if (path is String &&
        (info['type'] == 'image' ||
            RegExp(
              r'\.(png|jpe?g|gif|webp|bmp)$',
              caseSensitive: false,
            ).hasMatch(path))) {
      paths.add(path);
    }
    return paths.where((path) => path.isNotEmpty).toList();
  }

  static String contextText(Message message, {bool allowRead = false}) {
    final descriptions =
        message.metadata?['imageDescriptions'] as Map? ?? const {};
    return [
      message.content,
      for (final path in imagePaths(message))
        if (descriptions[path] is String &&
            (descriptions[path] as String).isNotEmpty)
          '[图片描述]\n${descriptions[path]}'
        else if (allowRead)
          '[图片附件，请调用 read_image 读取]\n$path',
    ].join('\n');
  }

  static Future<void> streamResponse({
    required AIAgent agent,
    required List<Message> messages,
    required List<ChatCompletionMessage> contextMessages,
    required FutureOr<void> Function(String) onToken,
    required FutureOr<void> Function(String) onError,
    required FutureOr<void> Function() onComplete,
    String? prompt,
    String? channelId,
    bool Function()? shouldCancel,
    int maxRetries = 3,
    int retryDelay = 1000,
  }) async {
    final sources = <String, Message>{};
    for (final message in messages) {
      final descriptions =
          message.metadata?['imageDescriptions'] as Map? ?? const {};
      for (final path in imagePaths(message)) {
        if (!descriptions.containsKey(path)) {
          sources.putIfAbsent(path, () => message);
        }
      }
    }
    final nativeSupported = NativeToolAgentService.instance.supports(
      agent,
      true,
    );
    if (sources.isEmpty && !nativeSupported) {
      await RequestService.streamResponseWithRetry(
        agent: agent,
        prompt: prompt,
        contextMessages: contextMessages,
        onToken: onToken,
        onError: onError,
        onComplete: onComplete,
        shouldCancel: shouldCancel,
        maxRetries: maxRetries,
        retryDelay: retryDelay,
      );
      return;
    }
    final resolvedSources = <String, MapEntry<String, Message>>{};
    for (final entry in sources.entries) {
      final absolute = await ImageUtils.getAbsolutePath(entry.key);
      resolvedSources[absolute] = entry;
    }
    try {
      var emitted = '';
      Future<void> updates = Future<void>.value();
      final questionMessages = <String, Message>{};
      final targetChannelId =
          channelId ??
          messages.map((m) => m.channelId).whereType<String>().firstOrNull;
      await NativeToolAgentService.instance.runToolLoop(
        agent: agent,
        systemPrompt: await RequestService.getEffectiveSystemPrompt(agent),
        contextMessages: contextMessages,
        files: resolvedSources.keys.map(File.new).toList(),
        isCancelling: shouldCancel,
        conversationId: targetChannelId,
        questionsInChat: targetChannelId != null,
        imageOnlyTools: !nativeSupported,
        alivenessOnlyTools: !agent.enableFunctionCalling,
        onToolSteps: targetChannelId == null
            ? null
            : (steps) async {
                // 独立的频道提问消息适用于 @、自动回复和活人感线程，
                // 不依赖正文是否已经开始流式生成。
                for (final step in steps.where(
                  (s) => s.method == 'askuserquestions',
                )) {
                  final data = jsonDecode(step.data) as Map<String, dynamic>;
                  final requestId = data['requestId'] as String?;
                  if (requestId == null) continue; // 参数校验失败，无可交互的请求
                  final existing = questionMessages[requestId];
                  final questionMessage =
                      existing ??
                      Message(
                        id: 'question_$requestId',
                        content: step.desc,
                        user: User(id: agent.id, username: agent.name),
                        type: MessageType.received,
                        channelId: targetChannelId,
                        replyToId: messages.firstOrNull?.id,
                      );
                  questionMessage.metadata = {
                    'isAI': true,
                    'agentId': agent.id,
                    'askUserQuestions': step.toJson(),
                  };
                  questionMessage.content = step.result == null
                      ? step.desc
                      : '${step.desc}\n[提问结果]\n${step.result}';
                  final channelService = ChatPlugin.instance.channelService;
                  if (existing == null) {
                    if (!await channelService.saveMessage(questionMessage)) {
                      throw StateError('提问消息无法保存到频道');
                    }
                    questionMessages[requestId] = questionMessage;
                  }
                  await channelService.updateMessage(questionMessage);
                }
              },
        onUpdateMessage: (text, _) {
          final delta = text.startsWith(emitted)
              ? text.substring(emitted.length)
              : text;
          emitted = text;
          if (delta.isNotEmpty) updates = updates.then((_) => onToken(delta));
        },
        onImageDescription: (path, description) async {
          final source = resolvedSources[path];
          if (source == null) return;
          final message = source.value;
          message.metadata = {
            ...?message.metadata,
            'imageDescriptions': {
              ...?message.metadata?['imageDescriptions'] as Map?,
              source.key: description,
            },
          };
          await ChatPlugin.instance.channelService.saveMessage(message);
        },
      );
      await updates;
      await onComplete();
    } catch (error) {
      await onError(error.toString());
    }
  }
}
