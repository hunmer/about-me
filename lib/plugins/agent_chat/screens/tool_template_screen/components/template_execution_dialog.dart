import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_service.dart';
import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/services/toast_service.dart';

const _uuid = Uuid();

/// 工具模板执行对话框
///
/// 执行模板的所有步骤并显示结果
class TemplateExecutionDialog extends StatefulWidget {
  final String templateName;
  final List<ToolCallStep> steps;

  const TemplateExecutionDialog({
    super.key,
    required this.templateName,
    required this.steps,
  });

  @override
  State<TemplateExecutionDialog> createState() =>
      _TemplateExecutionDialogState();
}

class _TemplateExecutionDialogState extends State<TemplateExecutionDialog> {
  bool _isExecuting = false;
  bool _isCompleted = false;
  int _currentStepIndex = -1;
  final List<Map<String, dynamic>> _results = [];
  int? _expandedStepIndex; // 当前展开的步骤索引

  @override
  void initState() {
    super.initState();
    _executeSteps();
  }

  Future<void> _executeSteps() async {
    setState(() {
      _isExecuting = true;
      _results.clear();
    });

    // 生成唯一的工具调用ID
    final toolCallId = _uuid.v4();

    // 初始化工具调用上下文（用于步骤间结果传递）
    final jsBridge = JSBridgeManager.instance;
    jsBridge.initToolCallContext(toolCallId);

    try {
      for (var i = 0; i < widget.steps.length; i++) {
        if (!mounted) return;

        setState(() {
          _currentStepIndex = i;
          widget.steps[i].status = ToolCallStatus.running;
        });

        final step = widget.steps[i];

        try {
          // 设置当前执行上下文（供 JavaScript 中的 setResult/getResult 使用）
          jsBridge.setCurrentExecution(toolCallId, i);

          final result = await ToolService.executeToolStep(step);

          // 自动将步骤结果保存到上下文（供后续步骤通过索引获取）
          jsBridge.setToolCallResult('step_$i', result);

          if (!mounted) return;

          setState(() {
            widget.steps[i].status = ToolCallStatus.success;
            widget.steps[i].result = result;
            _results.add({
              'stepIndex': i,
              'title': step.title,
              'success': true,
              'result': result,
            });
            _expandedStepIndex = i; // 自动展开最后完成的步骤
          });
        } catch (e) {
          if (!mounted) return;

          setState(() {
            widget.steps[i].status = ToolCallStatus.failed;
            widget.steps[i].error = e.toString();
            _results.add({
              'stepIndex': i,
              'title': step.title,
              'success': false,
              'error': e.toString(),
            });
            _expandedStepIndex = i; // 自动展开最后完成的步骤（包括失败的）
          });
          // 步骤失败后继续执行后续步骤（测试模式下）
        }
      }

      if (mounted) {
        setState(() {
          _isExecuting = false;
          _isCompleted = true;
          _currentStepIndex = -1;
        });
      }
    } finally {
      // 清除工具调用上下文
      jsBridge.clearToolCallContext(toolCallId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return JellyBox(
      radius: theme.radii.xxl,
      padding: EdgeInsets.all(theme.spacing.xl),
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DsIcon(DsIconKind.play, color: theme.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '执行: ${widget.templateName}',
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          if (_isExecuting) ...[
            DSLinearProgress(
              value:
                  _currentStepIndex >= 0
                      ? (_currentStepIndex + 1) / widget.steps.length
                      : 0,
              height: 10,
            ),
            const SizedBox(height: 8),
            Text(
              '正在执行步骤 ${_currentStepIndex + 1}/${widget.steps.length}',
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
            const SizedBox(height: 16),
          ],

          // 步骤列表和结果
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.steps.length,
              itemBuilder: (context, index) {
                return _buildStepItem(index);
              },
            ),
          ),
          SizedBox(height: theme.spacing.md),
          Row(
            children: [
              // 复制所有结果
              if (_isCompleted)
                Expanded(
                  child: DSButton(
                    label: 'agent_chat_copyResult'.tr,
                    icon: DsIconKind.copy,
                    variant: DSButtonVariant.outline,
                    onPressed: _copyAllResults,
                  ),
                ),
              if (_isCompleted) SizedBox(width: theme.spacing.md),
              // 关闭按钮
              Expanded(
                child: DSButton(
                  label: _isCompleted ? '关闭' : '取消',
                  onPressed: _isExecuting ? null : () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建步骤项
  Widget _buildStepItem(int index) {
    final step = widget.steps[index];
    final theme = DSThemeBridge.resolve(context);
    final result = _results.firstWhere(
      (r) => r['stepIndex'] == index,
      orElse: () => {},
    );

    // ExpansionTile 结构性组件刻意保留 Material，配色令牌化
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: theme.radii.md,
        border: Border.all(color: theme.textSub.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        key: ValueKey(
          'step_${index}_${_expandedStepIndex == index}',
        ), // 使用key强制重建
        initiallyExpanded: _expandedStepIndex == index, // 仅展开最后完成的步骤
        onExpansionChanged: (expanded) {
          if (expanded) {
            // 用户手动展开时更新状态
            setState(() {
              _expandedStepIndex = index;
            });
          } else if (_expandedStepIndex == index) {
            // 用户手动折叠当前展开的步骤
            setState(() {
              _expandedStepIndex = null;
            });
          }
        },
        leading: _buildStatusIcon(step.status),
        title: Text(
          step.title.isNotEmpty ? step.title : '步骤 ${index + 1}',
          style: DsTypography.body.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.text,
          ),
        ),
        subtitle: Text(
          step.desc,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DsTypography.caption.copyWith(color: theme.textSub),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 代码预览
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.surfaceAlt.withValues(alpha: 0.6),
                    borderRadius: theme.radii.sm,
                  ),
                  child: Text(
                    step.data,
                    style: DsTypography.caption.copyWith(
                      fontFamily: 'monospace',
                      color: theme.text,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // 执行结果
                if (result.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      DsIcon(
                        result['success'] ? DsIconKind.check : DsIconKind.close,
                        size: 16,
                        color: result['success'] ? theme.success : theme.danger,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        result['success'] ? '执行成功' : '执行失败',
                        style: DsTypography.caption.copyWith(
                          fontWeight: FontWeight.w500,
                          color:
                              result['success'] ? theme.success : theme.danger,
                        ),
                      ),
                      const Spacer(),
                      Pressable(
                        onPressed: () => _copyStepResult(index),
                        semanticLabel: '复制结果',
                        builder:
                            (context, states) => DsIcon(
                              DsIconKind.copy,
                              size: 16,
                              color: theme.textSub,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          result['success']
                              ? theme.success.mixWhite(0.92)
                              : theme.danger.mixWhite(0.92),
                      borderRadius: theme.radii.sm,
                      border: Border.all(
                        color:
                            result['success']
                                ? theme.success.withValues(alpha: 0.5)
                                : theme.danger.withValues(alpha: 0.5),
                      ),
                    ),
                    child: SelectableText(
                      result['success']
                          ? _formatResult(result['result'])
                          : result['error'],
                      style: DsTypography.caption.copyWith(
                        fontFamily: 'monospace',
                        color: theme.text,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建状态图标
  Widget _buildStatusIcon(ToolCallStatus status) {
    final theme = DSThemeBridge.resolve(context);
    switch (status) {
      case ToolCallStatus.pending:
        return DsIcon(DsIconKind.clock, size: 22, color: theme.textSub);
      case ToolCallStatus.running:
        return const SizedBox(
          width: 24,
          height: 24,
          child: Center(child: DSThemeBridge(child: DSLoadingDots(size: 7))),
        );
      case ToolCallStatus.success:
        return DsIcon(DsIconKind.check, size: 22, color: theme.success);
      case ToolCallStatus.failed:
        return DsIcon(DsIconKind.close, size: 22, color: theme.danger);
    }
  }

  /// 格式化结果
  String _formatResult(String result) {
    try {
      final decoded = jsonDecode(result);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (e) {
      return result;
    }
  }

  /// 复制单个步骤结果
  void _copyStepResult(int index) {
    final result = _results.firstWhere(
      (r) => r['stepIndex'] == index,
      orElse: () => {},
    );

    if (result.isEmpty) return;

    final text =
        result['success'] ? _formatResult(result['result']) : result['error'];

    Clipboard.setData(ClipboardData(text: text));

    toastService.showToast('已复制到剪贴板');
  }

  /// 复制所有结果
  void _copyAllResults() {
    final buffer = StringBuffer();
    buffer.writeln('执行结果: ${widget.templateName}');
    buffer.writeln('=' * 40);

    for (final result in _results) {
      buffer.writeln();
      buffer.writeln('步骤 ${result['stepIndex'] + 1}: ${result['title']}');
      buffer.writeln('-' * 40);

      if (result['success']) {
        buffer.writeln('状态: 成功');
        buffer.writeln('结果:');
        buffer.writeln(_formatResult(result['result']));
      } else {
        buffer.writeln('状态: 失败');
        buffer.writeln('错误: ${result['error']}');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    toastService.showToast('已复制所有结果到剪贴板');
  }
}
