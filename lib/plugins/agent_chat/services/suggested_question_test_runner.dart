import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/suggested_question.dart';
import '../models/tool_call_step.dart';

/// 批量测试只依赖会话操作，调度可在不调用真实模型/工具的情况下验证。
abstract interface class SuggestedQuestionTestSession {
  Conversation get conversation;
  List<ChatMessage> get messages;
  Future<void> send(String question, bool Function() shouldCancel);
  Future<void> persist();
  void cancel();
  void dispose();
}

class SuggestedQuestionTestRunner extends ChangeNotifier {
  SuggestedQuestionTestRunner({
    required List<SuggestedQuestion> questions,
    required this.createSession,
    required this.writeReport,
  }) : questions = List.unmodifiable(questions);

  final List<SuggestedQuestion> questions;
  final Future<SuggestedQuestionTestSession> Function(int sessionNumber)
  createSession;
  final Future<void> Function(String path, Map<String, dynamic> report)
  writeReport;
  final String runId = const Uuid().v4();
  final DateTime startedAt = DateTime.now();
  final List<Map<String, dynamic>> results = [];
  final List<String> conversationIds = [];
  final Map<String, Map<String, dynamic>> failedConversations = {};

  SuggestedQuestionTestSession? _session;
  bool _started = false;
  bool isRunning = false;
  bool stopRequested = false;
  DateTime? finishedAt;
  String? fatalError;
  String? saveError;

  String get reportPath => 'agent_chat/test_runs/$runId.json';
  int get completedCount =>
      results.where((r) => r['status'] != 'cancelled').length;
  int get failedCount => results
      .where(
        (r) =>
            (r['toolErrors'] as List).isNotEmpty ||
            r['requestError'] != null ||
            r['persistenceError'] != null,
      )
      .length;

  void stop() {
    if (!isRunning || stopRequested) return;
    stopRequested = true;
    _session?.cancel();
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'runId': runId,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
    'status': fatalError != null
        ? 'failed'
        : stopRequested
        ? 'stopped'
        : finishedAt == null
        ? 'running'
        : 'completed',
    'total': questions.length,
    'completed': completedCount,
    'failed': failedCount,
    'fatalError': fatalError,
    'questions': questions.map((q) => q.toJson()).toList(),
    'conversationIds': conversationIds,
    'results': results,
    'failedConversations': failedConversations.values.toList(),
  };

  Future<void> save() async {
    try {
      // 深拷贝防止写入期间下一题继续修改结果集合。
      await writeReport(
        reportPath,
        jsonDecode(jsonEncode(toJson())) as Map<String, dynamic>,
      );
      saveError = null;
    } catch (error) {
      saveError = error.toString();
      rethrow;
    }
  }

  Future<void> run() async {
    if (_started) return;
    _started = true;
    isRunning = true;
    notifyListeners();
    try {
      // 先确认报告可以保存；每题结束后检查点写入同一个文件。
      await save();
      for (final question in questions) {
        if (stopRequested) break;
        if (_session == null) {
          _session = await createSession(conversationIds.length + 1);
          conversationIds.add(_session!.conversation.id);
        }
        if (stopRequested) break;
        final session = _session!;
        final beforeIds = session.messages.map((m) => m.id).toSet();
        final questionStartedAt = DateTime.now();
        String? requestError;
        String? persistenceError;
        try {
          await session.send(question.question, () => stopRequested);
        } catch (error) {
          if (!stopRequested) requestError = error.toString();
        }
        try {
          // 包括取消时已生成的内容和工具状态，保存完成后才允许换会话。
          await session.persist();
        } catch (error) {
          persistenceError = error.toString();
        }
        final newMessages = session.messages
            .where((m) => !beforeIds.contains(m.id))
            .toList();
        final toolErrors = <Map<String, dynamic>>[];
        var toolCallCount = 0;
        for (final message in newMessages) {
          requestError ??= message.metadata?['requestError'] as String?;
          final steps = message.toolCall?.steps ?? const <ToolCallStep>[];
          toolCallCount += steps.length;
          for (var index = 0; index < steps.length; index++) {
            final step = steps[index];
            if (step.status == ToolCallStatus.failed ||
                (step.error?.isNotEmpty ?? false)) {
              toolErrors.add({
                'messageId': message.id,
                'stepIndex': index,
                ...step.toJson(),
              });
            }
          }
        }
        final failed =
            toolErrors.isNotEmpty ||
            requestError != null ||
            persistenceError != null;
        results.add({
          'index': results.length + 1,
          ...question.toJson(),
          'conversationId': session.conversation.id,
          'startedAt': questionStartedAt.toIso8601String(),
          'finishedAt': DateTime.now().toIso8601String(),
          'status': stopRequested
              ? 'cancelled'
              : failed
              ? 'failed'
              : 'passed',
          'messageIds': newMessages.map((m) => m.id).toList(),
          'toolCallCount': toolCallCount,
          'toolErrors': toolErrors,
          'requestError': requestError,
          'persistenceError': persistenceError,
        });
        if (failed || persistenceError != null) {
          // 报告内也保留完整上下文，便于外部 agent 离线检查与保存失败时恢复。
          failedConversations[session.conversation.id] =
              jsonDecode(
                    jsonEncode({
                      'conversation': session.conversation.toJson(),
                      'messages': session.messages
                          .map((m) => m.toJson())
                          .toList(),
                    }),
                  )
                  as Map<String, dynamic>;
        }
        notifyListeners();
        if (persistenceError != null) {
          throw StateError('会话保存失败，已停止后续问题：$persistenceError');
        }
        await save();
        if (failed) {
          session.dispose();
          _session = null;
        }
      }
    } catch (error) {
      fatalError = error.toString();
    } finally {
      _session?.dispose();
      _session = null;
      finishedAt = DateTime.now();
      try {
        await save();
      } catch (_) {
        // 对话框展示保存失败，仍允许复制完整报告和重试保存。
      }
      isRunning = false;
      notifyListeners();
    }
  }

  String buildReviewPrompt() {
    final buffer = StringBuffer()
      ..writeln('请检查 Aboutme 的以下 Agent 测试会话，定位并修复工具调用问题。')
      ..writeln('报告数据路径：$reportPath')
      ..writeln('通过当前配置的 Aboutme 数据服务（本地 app_data 或远程 API/MCP）读取报告；')
      ..writeln(
        '会话列表：agent_chat/conversations.json；消息：agent_chat/messages/<conversationId>.json。',
      )
      ..writeln('报告包含失败工具的参数、结果、错误、messageId，以及失败会话完整上下文。')
      ..writeln('请逐一检查失败步骤，区分工具实现、参数/schema、权限/配置和模型调用问题；')
      ..writeln('修复对应代码并做最小回归验证，说明原因和修改文件。保留原始测试会话与报告。')
      ..writeln(
        '状态：${fatalError != null
            ? '异常结束'
            : stopRequested
            ? '手动中止'
            : '全部完成'}；'
        '已完成 $completedCount/${questions.length}，有问题的题目 $failedCount。',
      );
    if (fatalError != null) buffer.writeln('执行异常：$fatalError');
    if (saveError != null) buffer.writeln('报告尚未保存：$saveError');
    if (failedCount == 0 && fatalError == null) {
      buffer.writeln('本次未记录到工具调用或请求错误，无需修复。');
    }
    buffer.writeln('\n报告 JSON（可直接检查，也可用作文件恢复副本）：');
    buffer.writeln(const JsonEncoder.withIndent('  ').convert(toJson()));
    return buffer.toString();
  }
}
