import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_json_view/flutter_json_view.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';

/// 工具调用步骤展示组件
///
/// 美化显示工具调用的执行步骤
class ToolCallSteps extends StatefulWidget {
  final List<ToolCallStep> steps;
  final bool isGenerating;
  final void Function(int stepIndex)? onRerunStep;

  const ToolCallSteps({
    super.key,
    required this.steps,
    this.isGenerating = false,
    this.onRerunStep,
  });

  @override
  State<ToolCallSteps> createState() => _ToolCallStepsState();
}

class _ToolCallStepsState extends State<ToolCallSteps> {
  // 展开的步骤索引集合
  final Set<int> _expandedSteps = {};

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: theme.primary.mixWhite(0.92),
        borderRadius: theme.radii.md,
        border: Border.all(
          color: theme.primary.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.primary.mixWhite(0.85),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(DsRadii.mdValue),
                topRight: Radius.circular(DsRadii.mdValue),
              ),
            ),
            child: Row(
              children: [
                DsIcon(DsIconKind.gear, size: 20, color: theme.primaryText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '工具调用 (${widget.steps.length} 个步骤)',
                    style: DsTypography.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.text,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 步骤列表
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            itemCount: widget.steps.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final step = widget.steps[index];
              final isExpanded = _expandedSteps.contains(index);

              return _buildStepCard(step, index, isExpanded);
            },
          ),
        ],
      ),
    );
  }

  /// 构建单个步骤卡片
  Widget _buildStepCard(ToolCallStep step, int index, bool isExpanded) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: theme.radii.sm,
        border: Border.all(
          color: theme.textSub.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 步骤头部
          Pressable(
            onPressed: () {
              setState(() {
                if (isExpanded) {
                  _expandedSteps.remove(index);
                } else {
                  _expandedSteps.add(index);
                }
              });
            },
            semanticLabel: '${index + 1}. ${step.title}',
            builder:
                (context, states) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // 状态图标
                      _buildStatusIcon(step.status),
                      const SizedBox(width: 8),

                      // 步骤标题
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${index + 1}. ${step.title}',
                              style: DsTypography.body.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.text,
                              ),
                            ),
                            if (step.desc.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                step.desc,
                                style: DsTypography.caption.copyWith(
                                  color: theme.textSub,
                                ),
                                maxLines: isExpanded ? null : 1,
                                overflow:
                                    isExpanded ? null : TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // 展开/折叠图标
                      DsIcon(
                        isExpanded
                            ? DsIconKind.chevronUp
                            : DsIconKind.chevronDown,
                        size: 20,
                        color: theme.textSub,
                      ),
                    ],
                  ),
                ),
          ),

          // 展开的详细内容
          if (isExpanded) ...[
            Divider(height: 1, color: theme.textSub.withValues(alpha: 0.3)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 执行方法
                  _buildInfoRow('方法', step.method),
                  const SizedBox(height: 8),

                  // 执行数据
                  if (step.data.isNotEmpty) ...[
                    Text(
                      '执行代码:',
                      style: DsTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.surfaceAlt.withValues(alpha: 0.6),
                        borderRadius: theme.radii.sm,
                      ),
                      child: SelectableText(
                        step.data,
                        style: DsTypography.caption.copyWith(
                          fontFamily: 'monospace',
                          color: theme.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // 执行结果
                  if (step.result != null) ...[
                    Text(
                      '执行结果:',
                      style: DsTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.success,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.success.mixWhite(0.92),
                        borderRadius: theme.radii.sm,
                        border: Border.all(
                          color: theme.success.withValues(alpha: 0.5),
                        ),
                      ),
                      child: _buildResultContent(step, theme),
                    ),
                  ],

                  // 错误信息
                  if (step.error != null) ...[
                    Text(
                      '错误信息:',
                      style: DsTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.danger,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.danger.mixWhite(0.92),
                        borderRadius: theme.radii.sm,
                        border: Border.all(
                          color: theme.danger.withValues(alpha: 0.5),
                        ),
                      ),
                      child: SelectableText(
                        step.error!,
                        style: DsTypography.caption.copyWith(color: theme.text),
                      ),
                    ),
                  ],

                  // 重新执行按钮
                  if (!widget.isGenerating && widget.onRerunStep != null) ...[
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: theme.textSub.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: DSButton(
                        label: 'agent_chat_executeAgain'.tr,
                        icon: DsIconKind.refresh,
                        size: DSButtonSize.sm,
                        variant: DSButtonVariant.outline,
                        onPressed: () => widget.onRerunStep!(index),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 按步骤声明的返回格式渲染结果
  ///
  /// - [ToolCallStep.resultFormat] 'markdown'：纯文本/Markdown（如 read_image 描述）
  /// - 默认 'json'：标准 JSON 用可折叠 JSON 视图；解析失败回退纯文本
  Widget _buildResultContent(ToolCallStep step, dynamic theme) {
    final result = step.result ?? '';

    if (step.resultFormat == 'markdown') {
      return MarkdownBody(
        data: result,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: DsTypography.caption.copyWith(color: theme.text, height: 1.5),
          listBullet: DsTypography.caption.copyWith(color: theme.text),
          blockquote: TextStyle(color: theme.textSub),
          code: DsTypography.caption.copyWith(
            fontFamily: 'monospace',
            color: theme.text,
          ),
        ),
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(result);
    } catch (_) {
      decoded = null;
    }
    if (decoded == null) {
      return SelectableText(
        result,
        style: DsTypography.caption.copyWith(color: theme.text),
      );
    }

    final jsonTheme = JsonViewTheme(
      backgroundColor: Colors.transparent,
      defaultTextStyle: DsTypography.caption.copyWith(
        color: theme.text,
        fontSize: 13,
      ),
      keyStyle: TextStyle(color: Colors.deepPurple.shade700),
      stringStyle: TextStyle(color: Colors.amber.shade900),
      intStyle: TextStyle(color: Colors.blue.shade700),
      doubleStyle: TextStyle(color: Colors.blue.shade700),
      boolStyle: TextStyle(color: Colors.green.shade700),
      openIcon: Icon(Icons.arrow_drop_down, size: 18, color: theme.textSub),
      closeIcon: Icon(Icons.arrow_drop_up, size: 18, color: theme.textSub),
    );
    return decoded is Map<String, dynamic>
        ? JsonView.map(decoded, theme: jsonTheme)
        : JsonView.string(result, theme: jsonTheme);
  }

  /// 构建状态图标
  Widget _buildStatusIcon(ToolCallStatus status) {
    final theme = DSThemeBridge.resolve(context);
    switch (status) {
      case ToolCallStatus.pending:
        return DsIcon(
          DsIconKind.minus,
          size: 20,
          color: theme.textSub.withValues(alpha: 0.6),
        );
      case ToolCallStatus.running:
        return SizedBox(
          width: 20,
          height: 20,
          // DSLoadingDots 内部画布为 size*4，取 5 才能放进 20x20
          child: Center(child: DSLoadingDots(size: 5)),
        );
      case ToolCallStatus.success:
        return DsIcon(DsIconKind.check, size: 20, color: theme.success);
      case ToolCallStatus.failed:
        return DsIcon(DsIconKind.close, size: 20, color: theme.danger);
    }
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    final theme = DSThemeBridge.resolve(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            '$label:',
            style: DsTypography.caption.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.text,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ),
      ],
    );
  }
}
