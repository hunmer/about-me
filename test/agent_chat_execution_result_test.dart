import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aboutme/plugins/agent_chat/controllers/managers/agent_chain_executor.dart';
import 'package:aboutme/plugins/agent_chat/controllers/managers/ai_request_handler.dart';
import 'package:aboutme/plugins/agent_chat/controllers/managers/shared/manager_context.dart';
import 'package:aboutme/plugins/agent_chat/models/agent_chain_node.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/services/conversation_service.dart';
import 'package:aboutme/plugins/agent_chat/services/message_detail_service.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/agent_chat/services/token_counter_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Messages implements MessageService {
  final messages = <ChatMessage>[];
  final saved = <String>{};
  Completer<void>? saveGate;
  bool failSave = false;
  void Function(ChatMessage)? onCompleted;

  @override
  List<ChatMessage> get currentMessages => messages;

  @override
  ChatMessage? getMessage(String conversationId, String messageId) =>
      messages.where((m) => m.id == messageId).firstOrNull;

  @override
  List<ChatMessage> getChainMessages(
    String conversationId,
    String executionId,
  ) => messages.where((m) => m.chainExecutionId == executionId).toList();

  @override
  Future<void> addMessage(ChatMessage message) async => messages.add(message);

  @override
  Future<void> updateMessage(ChatMessage message) async {
    if (failSave) throw StateError('disk unavailable');
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) messages[index] = message;
    await saveGate?.future;
    saved.add(message.id);
  }

  @override
  Future<void> updateAIMessageContent(
    String conversationId,
    String messageId,
    String content,
    int tokenCount,
  ) async {
    // 异步写入用于检验调用方确实等待流回调的写入队列。
    await Future<void>.delayed(Duration.zero);
    final message = getMessage(conversationId, messageId)!;
    final index = messages.indexWhere((m) => m.id == messageId);
    messages[index] = message.copyWith(
      content: content,
      tokenCount: tokenCount,
    );
  }

  @override
  Future<void> updateAIMessageThinking(
    String conversationId,
    String messageId,
    String thinkingContent,
  ) async {
    await Future<void>.delayed(Duration.zero);
    final message = getMessage(conversationId, messageId)!;
    final index = messages.indexWhere((m) => m.id == messageId);
    messages[index] = message.copyWith(thinkingContent: thinkingContent);
  }

  @override
  Future<void> completeAIMessage(
    String conversationId,
    String messageId,
  ) async {
    final message = getMessage(conversationId, messageId)!;
    await updateMessage(
      message.copyWith(
        isGenerating: false,
        tokenCount: TokenCounterService.estimateTokenCount(message.content),
      ),
    );
    onCompleted?.call(getMessage(conversationId, messageId)!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Conversations implements ConversationService {
  _Conversations(this.conversation);
  final Conversation? conversation;
  @override
  Conversation? getConversation(String id) => conversation;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Details implements MessageDetailService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AIAgent _agent(String id, int port) => AIAgent(
  id: id,
  name: id,
  description: '',
  tags: const [],
  serviceProviderId: 'test',
  baseUrl: 'http://127.0.0.1:$port/v1',
  headers: const {},
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  model: 'test',
  enableFunctionCalling: false,
);

Conversation _conversation({List<AgentChainNode>? nodes}) => Conversation(
  id: 'conversation',
  title: 'test',
  agentChain: nodes,
  createdAt: DateTime(2026),
  lastMessageAt: DateTime(2026),
);

ManagerContext _context(_Messages messages, Conversation? conversation) =>
    ManagerContext(
      conversationId: 'conversation',
      messageService: messages,
      conversationService: _Conversations(conversation),
      messageDetailService: _Details(),
    );

Future<HttpServer> _server(Future<void> Function(HttpRequest) respond) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen(respond);
  return server;
}

Future<void> _reply(HttpRequest request, String text) async {
  await request.drain<void>();
  request.response.headers.contentType = ContentType('text', 'event-stream');
  request.response.write(
    'data: ${jsonEncode({
      'choices': [
        {
          'delta': {'content': text},
        },
      ],
    })}\n\ndata: [DONE]\n\n',
  );
  await request.response.close();
}

void main() {
  test('缺会话、空链和缺失节点均明确失败', () async {
    final conversation = _conversation();
    for (final missingConversation in [true, false]) {
      final result = await AgentChainExecutor(
        context: _context(
          _Messages(),
          missingConversation ? null : conversation,
        ),
        conversation: conversation,
        getAgentChain: () => [],
        isCancelling: () => false,
      ).executeChain(userInput: 'test', files: []);
      expect(result.status, AgentChatExecutionStatus.failed);
      expect(result.isSuccess, isFalse);
      expect(result.error, isNotEmpty);
    }
    final chain = _conversation(
      nodes: [AgentChainNode(agentId: 'missing', order: 0)],
    );
    final result = await AgentChainExecutor(
      context: _context(_Messages(), chain),
      conversation: chain,
      getAgentChain: () => [_agent('other', 1)],
      isCancelling: () => false,
    ).executeChain(userInput: 'test', files: []);
    expect(result.status, AgentChatExecutionStatus.failed);
    expect(result.error, contains('missing'));
  });

  test('成功等待最终落盘，返回本轮最后消息与 token', () async {
    var requests = 0;
    final server = await _server(
      (request) => _reply(request, 'reply ${++requests}'),
    );
    final messages = _Messages()..saveGate = Completer<void>();
    final conversation = _conversation(
      nodes: [
        AgentChainNode(agentId: 'one', order: 0),
        AgentChainNode(agentId: 'two', order: 1),
      ],
    );
    var finished = false;
    final future =
        AgentChainExecutor(
          context: _context(messages, conversation),
          conversation: conversation,
          getAgentChain: () => [
            _agent('one', server.port),
            _agent('two', server.port),
          ],
          isCancelling: () => false,
        ).executeChain(userInput: 'test', files: []).then((result) {
          finished = true;
          return result;
        });
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(finished, isFalse);
    messages.saveGate!.complete();
    final result = await future.timeout(const Duration(seconds: 5));
    expect(result.isSuccess, isTrue);
    expect(result.content, 'reply 2');
    expect(result.messageId, messages.messages.last.id);
    expect(
      result.tokenCount,
      TokenCounterService.estimateTokenCount('reply 2'),
    );
    expect(messages.saved, contains(result.messageId));
    expect(messages.messages.every((m) => !m.isGenerating), isTrue);
  });

  test('buildResult 优先本轮 finalSummary，不取其他轮消息', () async {
    final server = await _server((request) => _reply(request, 'plain'));
    final messages = _Messages();
    messages.onCompleted = (message) {
      messages.messages.addAll([
        ChatMessage.ai(
          conversationId: 'conversation',
          content: 'summary',
          chainExecutionId: message.chainExecutionId,
          isFinalSummary: true,
          tokenCount: 7,
        ),
        ChatMessage.ai(
          conversationId: 'conversation',
          content: 'later',
          chainExecutionId: message.chainExecutionId,
        ),
        ChatMessage.ai(
          conversationId: 'conversation',
          content: 'old summary',
          chainExecutionId: 'other',
          isFinalSummary: true,
        ),
      ]);
    };
    final conversation = _conversation();
    final result = await AgentChainExecutor(
      context: _context(messages, conversation),
      conversation: conversation,
      getAgentChain: () => [_agent('one', server.port)],
      isCancelling: () => false,
    ).executeChain(userInput: 'test', files: []);
    expect(result.isSuccess, isTrue);
    expect(result.content, 'summary');
    expect(result.tokenCount, 7);
  });

  test('请求错误不会吞掉后继续链', () async {
    var requests = 0;
    final server = await _server((request) async {
      requests++;
      await request.drain<void>();
      request.response.statusCode = 400;
      request.response.write('{"error":{"message":"broken"}}');
      await request.response.close();
    });
    final messages = _Messages();
    final conversation = _conversation(
      nodes: [
        AgentChainNode(agentId: 'one', order: 0),
        AgentChainNode(agentId: 'two', order: 1),
      ],
    );
    final result = await AgentChainExecutor(
      context: _context(messages, conversation),
      conversation: conversation,
      getAgentChain: () => [
        _agent('one', server.port),
        _agent('two', server.port),
      ],
      isCancelling: () => false,
    ).executeChain(userInput: 'test', files: []);
    expect(result.status, AgentChatExecutionStatus.failed);
    expect(result.error, contains('broken'));
    expect(messages.messages, hasLength(1));
    expect(messages.messages.single.isGenerating, isFalse);
    expect(messages.saved, contains(result.messageId));
    expect(requests, 10);
  });

  test('handler 缺 Agent 返回 failed 并等待保存', () async {
    final messages = _Messages();
    final message = ChatMessage.ai(
      conversationId: 'conversation',
      content: '',
      isGenerating: true,
    );
    messages.messages.add(message);
    final conversation = _conversation();
    final handler = AIRequestHandler(
      context: _context(messages, conversation),
      conversation: conversation,
      getCurrentAgent: () => null,
      getToolAgent: (_) async => null,
      isCancelling: () => false,
    );
    final result = await handler.request(
      aiMessageId: message.id,
      userInput: 'test',
    );
    expect(result.status, AgentChatExecutionStatus.failed);
    expect(result.error, contains('Agent'));
    expect(result.messageId, message.id);
    expect(messages.saved, contains(message.id));
  });

  for (final useHandler in [false, true]) {
    for (final failSave in [false, true]) {
      test('最终保存决定成功或失败 handler=$useHandler failSave=$failSave', () async {
        final server = await _server(
          (request) => _reply(request, 'saved reply'),
        );
        final messages = _Messages()..failSave = failSave;
        final conversation = _conversation();
        final context = _context(messages, conversation);
        final AgentChatExecutionResult result;
        if (useHandler) {
          final message = ChatMessage.ai(
            conversationId: 'conversation',
            content: '',
            isGenerating: true,
          );
          messages.messages.add(message);
          result = await AIRequestHandler(
            context: context,
            conversation: conversation,
            getCurrentAgent: () => _agent('one', server.port),
            getToolAgent: (_) async => null,
            isCancelling: () => false,
          ).request(aiMessageId: message.id, userInput: 'test');
        } else {
          result = await AgentChainExecutor(
            context: context,
            conversation: conversation,
            getAgentChain: () => [_agent('one', server.port)],
            isCancelling: () => false,
          ).executeChain(userInput: 'test', files: []);
        }
        expect(result.isSuccess, !failSave);
        if (failSave) {
          expect(result.status, AgentChatExecutionStatus.failed);
          expect(result.error, contains('disk unavailable'));
        } else {
          expect(result.content, 'saved reply');
          expect(result.tokenCount, greaterThan(0));
          expect(messages.saved, contains(result.messageId));
        }
      });
    }
  }

  for (final useHandler in [false, true]) {
    test('取消保留已有正文且结束等待 handler=$useHandler', () async {
      var cancelling = false;
      final server = await _server((request) async {
        await request.drain<void>();
        request.response.bufferOutput = false;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"content":"partial reply"}}]}\n\n',
        );
        await request.response.flush();
        // 持续打开流，依赖取消定时器终结。
      });
      final messages = _Messages();
      final conversation = _conversation();
      final context = _context(messages, conversation);
      Timer? timer;
      timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
        if (messages.messages.any((m) => m.content == 'partial reply')) {
          cancelling = true;
          timer?.cancel();
        }
      });
      addTearDown(() => timer?.cancel());
      final AgentChatExecutionResult result;
      if (useHandler) {
        final message = ChatMessage.ai(
          conversationId: 'conversation',
          content: '',
          isGenerating: true,
        );
        messages.messages.add(message);
        result =
            await AIRequestHandler(
                  context: context,
                  conversation: conversation,
                  getCurrentAgent: () => _agent('one', server.port),
                  getToolAgent: (_) async => null,
                  isCancelling: () => cancelling,
                )
                .request(aiMessageId: message.id, userInput: 'test')
                .timeout(const Duration(seconds: 5));
      } else {
        result =
            await AgentChainExecutor(
                  context: context,
                  conversation: conversation,
                  getAgentChain: () => [_agent('one', server.port)],
                  isCancelling: () => cancelling,
                )
                .executeChain(userInput: 'test', files: [])
                .timeout(const Duration(seconds: 5));
      }
      expect(result.status, AgentChatExecutionStatus.cancelled);
      expect(result.isCancelled, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.content, 'partial reply');
      expect(result.tokenCount, greaterThan(0));
      expect(messages.messages.single.isGenerating, isFalse);
      expect(
        messages.messages.single.metadata?['requestError'],
        contains('已取消发送'),
      );
      expect(messages.saved, contains(result.messageId));
    });
  }

  test('请求开始前取消只通知一次 onError，不发请求', () async {
    final errors = <String>[];
    var completed = 0;
    await RequestService.streamResponseWithRetry(
      agent: _agent('one', 1),
      prompt: 'test',
      shouldCancel: () => true,
      onToken: (_) => fail('unexpected token'),
      onError: errors.add,
      onComplete: () => completed++,
    );
    expect(errors, ['已取消发送']);
    expect(completed, 0);
  });

  test('重试间隔取消有唯一终态，停止后续请求', () async {
    var requests = 0;
    var cancelling = false;
    final errors = <String>[];
    final server = await _server((request) async {
      requests++;
      await request.drain<void>();
      request.response.statusCode = 400;
      await request.response.close();
      Timer(const Duration(milliseconds: 20), () => cancelling = true);
    });
    await RequestService.streamResponseWithRetry(
      agent: _agent('one', server.port),
      prompt: 'test',
      shouldCancel: () => cancelling,
      retryDelay: 100,
      onToken: (_) {},
      onError: errors.add,
      onComplete: () => fail('unexpected success'),
    );
    expect(errors, ['已取消发送']);
    expect(requests, 1);
  });

  test('空响应重试耗尽后只有失败终态', () async {
    var requests = 0;
    final server = await _server((request) {
      requests++;
      return _reply(request, '');
    });
    final errors = <String>[];
    await RequestService.streamResponseWithRetry(
      agent: _agent('one', server.port),
      prompt: 'test',
      maxRetries: 2,
      retryDelay: 0,
      onToken: (_) {},
      onError: errors.add,
      onComplete: () => fail('unexpected success'),
    );
    expect(requests, 2);
    expect(errors, hasLength(1));
    expect(errors.single, contains('为空'));
  });
}
