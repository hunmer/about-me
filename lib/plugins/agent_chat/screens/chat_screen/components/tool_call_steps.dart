import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_json_view/flutter_json_view.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'ask_user_questions_card.dart';

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
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8),
      itemCount: widget.steps.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final step = widget.steps[index];
        final isExpanded = _expandedSteps.contains(index);

        return _buildStepCard(step, index, isExpanded);
      },
    );
  }

  /// 创建类 plugin_tool 步骤：点击副标题弹出创建的数据详情
  ///
  /// 详情入口由各插件通过 [PluginBase.buildCreatedDetailOpener] 自行提供；
  /// run_js 与插件未支持的方法不展示数据详情
  VoidCallback? _resolveCreatedDataTap(ToolCallStep step) {
    if (step.method != 'plugin_tool' ||
        step.status != ToolCallStatus.success ||
        step.result == null) {
      return null;
    }
    try {
      final call = jsonDecode(step.data) as Map<String, dynamic>;
      final pluginId = call['pluginId'] as String?;
      if (pluginId == null) return null;
      final plugin = PluginManager.instance.getPlugin(pluginId);
      if (plugin == null) return null;
      final created = jsonDecode(step.result!);
      if (created is! Map<String, dynamic>) return null;
      if (created['success'] == false || created['error'] != null) return null;
      return plugin.buildCreatedDetailOpener(
        context,
        (call['method'] as String?) ?? '',
        created,
      );
    } catch (_) {
      return null;
    }
  }

  /// 构建单个步骤卡片
  Widget _buildStepCard(ToolCallStep step, int index, bool isExpanded) {
    if (step.method == 'askuserquestions' &&
        step.status != ToolCallStatus.failed) {
      final data = jsonDecode(step.data) as Map<String, dynamic>;
      return AskUserQuestionsCard(
        key: ValueKey(data['requestId']),
        step: step,
      );
    }
    final theme = DSThemeBridge.resolve(context);
    final plugin = _resolveStepPlugin(step);
    // 创建类步骤副标题渲染为「点击查看详情」按钮，其余展示步骤描述
    final createdDataTap = _resolveCreatedDataTap(step);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DSListItemCard(
          title: '${index + 1}. ${step.title}',
          subtitle: createdDataTap != null
              ? 'agent_chat_viewCreatedDetail'.tr
              : (step.desc.isNotEmpty ? step.desc : null),
          onSubtitleTap: createdDataTap,
          // 非插件步骤（纯 run_js 等）回退到代码图标
          icon: plugin == null ? DsIconKind.code : null,
          // 插件步骤使用插件图标作为水印
          leading: plugin == null ? null : Icon(plugin.icon),
          iconColor: plugin?.color ?? theme.primary,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusIcon(step.status),
              const SizedBox(width: 8),
              DsIcon(
                isExpanded ? DsIconKind.chevronUp : DsIconKind.chevronDown,
                size: 20,
                color: theme.textSub,
              ),
            ],
          ),
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedSteps.remove(index);
              } else {
                _expandedSteps.add(index);
              }
            });
          },
        ),

        // 展开的详细内容
        if (isExpanded) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
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
                // 执行方法
                _buildInfoRow('方法', step.method),
                const SizedBox(height: 8),

                // 执行数据
                if (step.data.isNotEmpty) ...[
                  Text(
                    step.method == 'plugin_tool' ? '执行参数:' : '执行代码:',
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
                    child: _buildDataContent(step, theme),
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
    return _buildJsonOrText(decoded, result, theme);
  }

  /// 执行数据展示：plugin_tool 的参数用 JSON 视图，run_js 回退等宽代码文本
  Widget _buildDataContent(ToolCallStep step, dynamic theme) {
    if (step.method == 'plugin_tool') {
      try {
        final args = (jsonDecode(step.data) as Map<String, dynamic>)['args'];
        if (args != null) {
          return _buildJsonOrText(args, jsonEncode(args), theme);
        }
      } catch (_) {}
    }
    return SelectableText(
      step.data,
      style: DsTypography.caption.copyWith(
        fontFamily: 'monospace',
        color: theme.text,
      ),
    );
  }

  /// JSON 值优先用可折叠 JSON 视图，非 JSON 回退纯文本
  Widget _buildJsonOrText(dynamic decoded, String raw, dynamic theme) {
    final jsonTheme = _buildJsonTheme(theme);
    if (decoded is Map<String, dynamic>) {
      return JsonView.map(decoded, theme: jsonTheme);
    }
    if (decoded != null) {
      return JsonView.string(raw, theme: jsonTheme);
    }
    return SelectableText(
      raw,
      style: DsTypography.caption.copyWith(color: theme.text),
    );
  }

  /// JSON 视图配色跟随主题色板：key 主色、string 警示色、数值副色、布尔成功色
  JsonViewTheme _buildJsonTheme(dynamic theme) => JsonViewTheme(
    backgroundColor: Colors.transparent,
    defaultTextStyle: DsTypography.caption.copyWith(
      color: theme.text,
      fontSize: 13,
    ),
    keyStyle: TextStyle(color: theme.primaryText),
    stringStyle: TextStyle(color: theme.warning),
    intStyle: TextStyle(color: theme.secondary),
    doubleStyle: TextStyle(color: theme.secondary),
    boolStyle: TextStyle(color: theme.success),
    openIcon: Icon(Icons.arrow_drop_down, size: 18, color: theme.textSub),
    closeIcon: Icon(Icons.arrow_drop_up, size: 18, color: theme.textSub),
  );

  /// 解析 plugin_tool 步骤对应的插件
  ///
  /// plugin_tool 的 data 为结构化 JSON（{pluginId, method, args}），
  /// 直接取 pluginId 查插件实例用于展示图标与颜色；run_js 无插件归属，返回 null
  PluginBase? _resolveStepPlugin(ToolCallStep step) {
    if (step.method != 'plugin_tool') return null;
    try {
      final call = jsonDecode(step.data) as Map<String, dynamic>;
      final pluginId = call['pluginId'] as String?;
      if (pluginId == null) return null;
      return PluginManager.instance.getPlugin(pluginId);
    } catch (_) {
      return null;
    }
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
        // 圆角淡色底 + 打勾，与失败/进行中状态的视觉重量对齐
        return Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.success.mixWhite(0.88),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DsIcon(DsIconKind.check, size: 14, color: theme.success),
        );
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
