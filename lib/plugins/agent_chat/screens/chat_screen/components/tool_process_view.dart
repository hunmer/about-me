import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'tool_call_steps.dart';

/// 生成中思考内容的折叠入口：默认收起为"思考中..."一行，
/// 点击展开 muted 小字号正文（限高滚动，自动跟随最新内容）
class ThinkingLiveView extends StatefulWidget {
  final String thinking;
  final bool autoScroll;
  final bool initiallyExpanded;

  const ThinkingLiveView({
    super.key,
    required this.thinking,
    this.autoScroll = true,
    this.initiallyExpanded = false,
  });

  @override
  State<ThinkingLiveView> createState() => _ThinkingLiveViewState();
}

class _ThinkingLiveViewState extends State<ThinkingLiveView> {
  final ScrollController _scrollController = ScrollController();
  late bool _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(ThinkingLiveView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoScroll &&
        _expanded &&
        widget.thinking != oldWidget.thinking &&
        _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.surfaceAlt.withValues(alpha: 0.6),
        borderRadius: theme.radii.sm,
        border: Border(
          left: BorderSide(
            color: theme.primary.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 入口行：思考中 / 收起，点击切换展开
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  DSLoadingDots(size: 4, color: theme.primaryText),
                  const SizedBox(width: 6),
                  Text(
                    _expanded ? '收起思考' : '思考中...',
                    style: DsTypography.caption.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.textSub,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  DsIcon(
                    _expanded ? DsIconKind.chevronUp : DsIconKind.chevronDown,
                    size: 14,
                    color: theme.textSub,
                  ),
                ],
              ),
            ),
          ),
          // 展开内容：muted 小字号流式全文
          if (_expanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
                child: Text(
                  widget.thinking,
                  style: DsTypography.caption.copyWith(
                    color: theme.textSub,
                    height: 1.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 各轮正文展示（过程文本，每轮一块）
class TurnTextsView extends StatelessWidget {
  final List<String> texts;
  final String? thinking;

  const TurnTextsView({super.key, required this.texts, this.thinking});

  List<String> get _visibleTexts {
    final thinkingText = _normalizeProcessText(thinking);
    return texts.map((text) => ChatMessage.splitThink(text).$2.trim()).where((
      text,
    ) {
      if (text.isEmpty) return false;
      final normalized = _normalizeProcessText(text);
      return thinkingText == null || normalized != thinkingText;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _visibleTexts.length; i++)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.surfaceAlt.withValues(alpha: 0.6),
              borderRadius: theme.radii.sm,
              border: Border(
                left: BorderSide(
                  color: theme.textSub.withValues(alpha: 0.5),
                  width: 3,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第 ${i + 1} 轮',
                  style: DsTypography.caption.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.textSub,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _visibleTexts[i],
                  style: DsTypography.caption.copyWith(
                    color: theme.textSub,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String? _normalizeProcessText(String? text) {
  final normalized = text?.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

/// 生成中的实时过程视图：思考流 + 各轮正文 + 工具步骤状态（Codex 风格全展开）
class LiveProcessView extends StatelessWidget {
  final ChatMessage message;
  final bool isGenerating;
  final void Function(int stepIndex)? onRerunStep;

  const LiveProcessView({
    super.key,
    required this.message,
    this.isGenerating = true,
    this.onRerunStep,
  });

  @override
  Widget build(BuildContext context) {
    final thinking = message.resolvedThinkingContent;
    final turnTexts = message.processTexts;
    final steps = message.toolCall?.steps ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (thinking != null && thinking.isNotEmpty)
          ThinkingLiveView(thinking: thinking),
        if (turnTexts.isNotEmpty)
          TurnTextsView(texts: turnTexts, thinking: thinking),
        if (steps.isNotEmpty)
          ToolCallSteps(
            steps: steps,
            isGenerating: isGenerating,
            onRerunStep: onRerunStep,
          ),
      ],
    );
  }
}

/// 完成后的折叠过程区块：入口按钮 + 展开后的思考内容与工具步骤
class CollapsibleProcessSection extends StatefulWidget {
  final ChatMessage message;
  final void Function(int stepIndex)? onRerunStep;

  const CollapsibleProcessSection({
    super.key,
    required this.message,
    this.onRerunStep,
  });

  @override
  State<CollapsibleProcessSection> createState() =>
      _CollapsibleProcessSectionState();
}

class _CollapsibleProcessSectionState extends State<CollapsibleProcessSection> {
  bool _expanded = false;

  /// 步骤使用的工具图标头像，图标与 ToolCallSteps 一致
  /// （插件步骤用插件图标，run_js 等回退代码图标），按工具去重
  List<Widget> _buildToolAvatars(List<ToolCallStep> steps, AppThemeData theme) {
    final seenTools = <String>{};
    final avatars = <Widget>[];
    for (final step in steps) {
      PluginBase? plugin;
      if (step.method == 'plugin_tool') {
        try {
          final call = jsonDecode(step.data) as Map<String, dynamic>;
          final pluginId = call['pluginId'] as String?;
          if (pluginId != null) {
            plugin = PluginManager.instance.getPlugin(pluginId);
          }
        } catch (_) {}
      }
      if (!seenTools.add(plugin?.id ?? step.method)) continue;
      final color = plugin?.color ?? theme.primary;
      avatars.add(
        DSAvatar(
          size: 18,
          color: color,
          child:
              plugin == null
                  ? DsIcon(DsIconKind.code, size: 10, color: theme.onPrimary)
                  : Icon(
                    plugin.icon ?? Icons.extension,
                    size: 10,
                    color: theme.onPrimary,
                  ),
        ),
      );
    }
    return avatars;
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final thinking = widget.message.resolvedThinkingContent;
    final turnTexts = widget.message.processTexts;
    final steps = widget.message.toolCall?.steps ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // 入口按钮：展开/收起执行过程，工具图标头像堆叠展示使用的工具列表
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.primary.mixWhite(0.9),
              borderRadius: theme.radii.sm,
              border: Border.all(color: theme.primary.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (steps.isNotEmpty) ...[
                  // 聊天界面无 AppTheme 祖先，DSAvatarStack 依赖它取主题
                  DSThemeBridge(
                    child: DSAvatarStack(
                      radius: 9,
                      avatars: _buildToolAvatars(steps, theme),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  _expanded ? '收起执行过程' : '查看执行过程',
                  style: DsTypography.caption.copyWith(
                    color: theme.primaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${steps.length} 个步骤'
                  '${turnTexts.length > 1 ? ' · ${turnTexts.length} 轮回复' : ''}'
                  '${thinking != null && thinking.isNotEmpty ? ' · 思考 ${thinking.length} 字' : ''})',
                  style: DsTypography.caption.copyWith(
                    fontSize: 10,
                    color: theme.primaryText.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 2),
                DsIcon(
                  _expanded ? DsIconKind.chevronUp : DsIconKind.chevronDown,
                  size: 14,
                  color: theme.primaryText,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (thinking != null && thinking.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.surfaceAlt.withValues(alpha: 0.6),
                            borderRadius: theme.radii.sm,
                            border: Border(
                              left: BorderSide(
                                color: theme.primary.withValues(alpha: 0.5),
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '思考过程',
                                style: DsTypography.caption.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: theme.textSub,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                thinking,
                                style: DsTypography.caption.copyWith(
                                  color: theme.textSub,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (turnTexts.isNotEmpty || steps.isNotEmpty)
                          const SizedBox(height: 8),
                      ],
                      if (turnTexts.isNotEmpty) ...[
                        TurnTextsView(texts: turnTexts, thinking: thinking),
                        if (steps.isNotEmpty) const SizedBox(height: 8),
                      ],
                      if (steps.isNotEmpty)
                        ToolCallSteps(
                          steps: steps,
                          isGenerating: false,
                          onRerunStep: widget.onRerunStep,
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
