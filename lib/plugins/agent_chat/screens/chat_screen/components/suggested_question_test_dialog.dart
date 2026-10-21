import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/controllers/chat_controller.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/services/message_detail_service.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/agent_chat/services/suggested_question_test_runner.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_template_service.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'suggested_questions_dialog.dart';

Future<void> showSuggestedQuestionTestDialog(
  BuildContext context,
  ChatController source,
) async {
  final selected = await showSuggestedQuestionBatchPicker(
    context,
    source.conversationService.storage,
  );
  if (!context.mounted || selected == null || selected.isEmpty) return;

  final service = source.conversationService;
  final config =
      service.getConversation(source.conversation.id) ?? source.conversation;
  final moments = MomentsService.instance;
  final previousConversationId = moments.currentConversationId;
  final previousAgentId = moments.currentAgentId;
  final previousMessages = moments.currentMessageService;
  late final SuggestedQuestionTestRunner runner;
  runner = SuggestedQuestionTestRunner(
    questions: selected,
    writeReport: (path, report) =>
        AboutmeDataService.instance.writePath(path, report),
    createSession: (index) async {
      final conversation = await service.createConversation(
        title: '工具测试 ${runner.startedAt.toLocal()} #$index',
        agentId: config.agentId ?? source.currentAgent?.id,
        groups: ['建议问题测试'],
        contextMessageCount: config.contextMessageCount,
      );
      // 首页会话是隐藏且 7 天过期的临时会话；测试只复制工具设置。
      final configured = conversation.copyWith(
        agentChain: config.agentChain,
        toolAgentConfig: config.toolAgentConfig,
        metadata: {
          if (config.metadata?['selectedTools'] != null)
            'selectedTools': config.metadata!['selectedTools'],
          'testRunId': runner.runId,
        },
      );
      await service.updateConversation(configured);
      final storage = service.storage;
      final messages = MessageService(storage: storage);
      final controller = ChatController(
        conversation: configured,
        messageService: messages,
        conversationService: service,
        messageDetailService: MessageDetailService(storage: storage),
        templateService: ToolTemplateService(storage),
        getSettings: source.getSettings,
      );
      try {
        await controller.initialize();
        controller.setUseJsTools(source.useJsTools);
        return _ControllerQuestionSession(controller);
      } catch (_) {
        controller.dispose();
        messages.dispose();
        rethrow;
      }
    },
  );
  final execution = runner.run();
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          DSThemeBridge(child: _SuggestedQuestionTestDialog(runner: runner)),
    );
  } finally {
    // 运行时禁止返回；若外层路由被强制移除，也先停止并等待保存完成。
    runner.stop();
    await execution;
    moments.currentConversationId = previousConversationId;
    moments.currentAgentId = previousAgentId;
    moments.currentMessageService = previousMessages;
    runner.dispose();
  }
}

class _ControllerQuestionSession implements SuggestedQuestionTestSession {
  _ControllerQuestionSession(this.controller);
  final ChatController controller;

  @override
  Conversation get conversation => controller.conversation;
  @override
  List<ChatMessage> get messages => controller.messageService.currentMessages;
  @override
  Future<void> send(String question, bool Function() shouldCancel) async {
    controller.setInputText(question);
    await controller.sendMessage(
      bypassAliveness: true,
      shouldCancel: shouldCancel,
    );
  }

  @override
  Future<void> persist() =>
      controller.messageService.persistConversation(conversation.id);
  @override
  void cancel() => controller.cancelSending();
  @override
  void dispose() {
    controller.dispose();
    controller.messageService.dispose();
  }
}

class _SuggestedQuestionTestDialog extends StatefulWidget {
  const _SuggestedQuestionTestDialog({required this.runner});
  final SuggestedQuestionTestRunner runner;
  @override
  State<_SuggestedQuestionTestDialog> createState() =>
      _SuggestedQuestionTestDialogState();
}

class _SuggestedQuestionTestDialogState
    extends State<_SuggestedQuestionTestDialog> {
  String? _reviewPrompt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.runner.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() => _reviewPrompt = null);
  }

  @override
  void dispose() {
    widget.runner.removeListener(_changed);
    super.dispose();
  }

  Future<void> _retrySave() async {
    setState(() => _saving = true);
    try {
      await widget.runner.save();
      toastService.showToast('报告已保存');
    } catch (error) {
      toastService.showToast('保存失败：$error', type: ToastType.error);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _reviewPrompt = null;
        });
      }
    }
  }

  Widget _buildResultHistory(
    SuggestedQuestionTestRunner runner,
    AppThemeData theme,
  ) {
    if (runner.results.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('已回答问题', style: DsTypography.label.copyWith(color: theme.textSub)),
        const SizedBox(height: 8),
        for (var i = 0; i < runner.results.length; i++)
          _buildResultRow(runner.results[i], i, theme),
      ],
    );
  }

  Widget _buildResultRow(
    Map<String, dynamic> result,
    int index,
    AppThemeData theme,
  ) {
    final toolErrors = result['toolErrors'];
    final hasError =
        result['status'] == 'failed' ||
        (toolErrors is List && toolErrors.isNotEmpty) ||
        result['requestError'] != null ||
        result['persistenceError'] != null;
    final cancelled = result['status'] == 'cancelled';
    final status = cancelled
        ? '已中止'
        : hasError
        ? '失败'
        : '通过';
    final statusColor = cancelled
        ? theme.warning
        : hasError
        ? theme.danger
        : theme.success;
    String? errorText;
    if (result['requestError'] != null) {
      errorText = result['requestError'].toString();
    } else if (result['persistenceError'] != null) {
      errorText = result['persistenceError'].toString();
    } else if (toolErrors is List && toolErrors.isNotEmpty) {
      final firstError = toolErrors.first;
      if (firstError is Map && firstError['error'] != null) {
        errorText = firstError['error'].toString();
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: hasError
            ? theme.danger.withValues(alpha: 0.08)
            : theme.surfaceAlt,
        border: Border(left: BorderSide(color: statusColor, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              cancelled
                  ? Icons.pause_circle_outline
                  : hasError
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              size: 18,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. ${result['categoryName'] ?? result['category'] ?? '问题'}',
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
                const SizedBox(height: 2),
                Text(
                  result['question']?.toString() ?? '',
                  style: DsTypography.body.copyWith(color: theme.text),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    errorText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.caption.copyWith(color: theme.danger),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: DsTypography.caption.copyWith(color: statusColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final runner = widget.runner;
    final running = runner.isRunning;
    final index = runner.questions.isEmpty
        ? 0
        : runner.results.length.clamp(0, runner.questions.length - 1);
    final question = runner.questions.isEmpty ? null : runner.questions[index];
    final theme = DSThemeBridge.resolve(context);
    if (!running) {
      _reviewPrompt ??= runner.buildReviewPrompt();
    }
    return PopScope(
      canPop: !running,
      child: AlertDialog(
        title: Text(
          running
              ? '建议问题测试'
              : runner.fatalError != null
              ? '测试异常结束'
              : runner.stopRequested
              ? '测试已中止'
              : '测试完成',
        ),
        content: SizedBox(
          width: 640,
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (running) ...[
                  LinearProgressIndicator(
                    value: runner.questions.isEmpty
                        ? 0
                        : runner.completedCount / runner.questions.length,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '已完成 ${runner.completedCount}/${runner.questions.length}，'
                    '发现问题 ${runner.failedCount} 题',
                  ),
                  const SizedBox(height: 12),
                ],
                _buildResultHistory(runner, theme),
                if (running && question != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '正在执行 · ${question.categoryName} · 第 ${index + 1} 题',
                    style: DsTypography.label.copyWith(color: theme.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(question.question),
                  if (runner.stopRequested) ...[
                    const SizedBox(height: 12),
                    const Text('正在停止并保存当前会话…'),
                  ],
                ],
                if (!running) ...[
                  if (runner.results.isNotEmpty) const SizedBox(height: 8),
                  SelectableText(_reviewPrompt!),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (running)
            DSButton(
              label: runner.stopRequested ? '正在中止…' : '中止',
              onPressed: runner.stopRequested ? null : runner.stop,
              variant: DSButtonVariant.outline,
            )
          else ...[
            if (runner.saveError != null)
              DSButton(
                label: _saving ? '保存中…' : '重试保存',
                onPressed: _saving ? null : _retrySave,
                variant: DSButtonVariant.outline,
              ),
            DSButton(
              label: '一键复制检查文本',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _reviewPrompt!));
                toastService.showToast('检查文本已复制');
              },
            ),
            DSButton(
              label: '关闭',
              onPressed: () => Navigator.pop(context),
              variant: DSButtonVariant.outline,
            ),
          ],
        ],
      ),
    );
  }
}
