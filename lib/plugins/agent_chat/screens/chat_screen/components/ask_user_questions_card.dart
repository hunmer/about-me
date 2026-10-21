import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/agent_chat/services/ask_user_questions_service.dart';

/// 聊天与全局弹窗共用同一份表单和回答协议。
class AskUserQuestionsCard extends StatefulWidget {
  const AskUserQuestionsCard({super.key, required this.step});

  final ToolCallStep step;

  @override
  State<AskUserQuestionsCard> createState() => _AskUserQuestionsCardState();
}

class _AskUserQuestionsCardState extends State<AskUserQuestionsCard> {
  late final data = jsonDecode(widget.step.data) as Map<String, dynamic>;
  late final questions = UserQuestion.parse(data);
  late final request = AskUserQuestionsService.instance.find(
    data['requestId'] as String,
  );
  late final selected = List.generate(questions.length, (_) => <String>{});
  late final controllers = List.generate(
    questions.length,
    (_) => TextEditingController(),
  );

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get canSubmit => questions.asMap().entries.every(
    (entry) =>
        selected[entry.key].isNotEmpty ||
        controllers[entry.key].text.trim().isNotEmpty,
  );

  @override
  Widget build(BuildContext context) {
    if (request == null) return _buildCard(context);
    return AnimatedBuilder(
      animation: request!,
      builder: (context, _) => _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final pending = request?.isPending == true;
    final result =
        request?.result ??
        (widget.step.result == null ? null : jsonDecode(widget.step.result!));
    final answers = result is Map ? result['answers'] as List? : null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('需要你回答', style: Theme.of(context).textTheme.titleSmall),
            for (var i = 0; i < questions.length; i++) ...[
              const SizedBox(height: 12),
              Text(
                '${questions[i].header.isEmpty ? '' : '${questions[i].header} · '}'
                '${questions[i].question}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (pending) ...[
                for (final option in questions[i].options)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(option['label']!),
                    subtitle: option['description']!.isEmpty
                        ? null
                        : Text(option['description']!),
                    value: selected[i].contains(option['label']),
                    onChanged: (value) => setState(() {
                      if (!questions[i].multiSelect) {
                        selected[i].clear();
                      }
                      if (value == true) {
                        selected[i].add(option['label']!);
                      } else {
                        selected[i].remove(option['label']);
                      }
                    }),
                  ),
                TextField(
                  controller: controllers[i],
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: questions[i].options.isEmpty
                        ? '输入回答'
                        : '其他回答或补充说明',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ] else if (answers != null && i < answers.length)
                Text(
                  [
                    ...((answers[i] as Map)['selected'] as List? ?? []).map(
                      (e) => '$e',
                    ),
                    if (((answers[i] as Map)['text'] as String? ?? '')
                        .isNotEmpty)
                      (answers[i] as Map)['text'] as String,
                  ].join('；'),
                ),
            ],
            const SizedBox(height: 12),
            if (pending)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => request!.cancel(),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: canSubmit
                        ? () => request!.answer([
                            for (var i = 0; i < questions.length; i++)
                              {
                                'id': questions[i].id,
                                'question': questions[i].question,
                                'selected': selected[i].toList(),
                                'text': controllers[i].text.trim(),
                              },
                          ])
                        : null,
                    child: const Text('提交回答'),
                  ),
                ],
              )
            else
              Text(
                result is Map && result['status'] == 'answered'
                    ? '已回答'
                    : result is Map && result['status'] == 'cancelled'
                    ? (result['reason'] as String? ?? '已取消')
                    : '本次提问已结束',
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showGlobalUserQuestions(
  UserQuestionsRequest request,
  ToolCallStep step,
) async {
  if (!request.isPending) return;
  final context = Get.overlayContext ?? Get.context;
  if (context == null || !context.mounted) {
    throw StateError('全局界面不可用，无法向用户提问');
  }
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: AskUserQuestionsCard(key: ValueKey(request.id), step: step),
        ),
      ),
    ),
  );
  // 回答或停止生成时只关闭本次提问，避免 pop 掉其他弹窗。
  void closeOnComplete() {
    if (!request.isPending && route.isActive) navigator.removeRoute(route);
  }

  request.addListener(closeOnComplete);
  try {
    await navigator.push(route);
  } finally {
    request.removeListener(closeOnComplete);
    request.cancel();
  }
}
