import 'dart:io';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/file_attachment.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/gallery_viewer.dart';
import 'markdown_content.dart';
import 'tool_process_view.dart';
import 'chain_message_container.dart';
import 'package:aboutme/plugins/chat/widgets/audio_player_widget.dart';

/// agent 消息气泡的内容组件
///
/// 仅渲染气泡内容列（链式容器/Agent 标签/正文/工具步骤/附件），
/// 由 chat 插件的 MessageBubble 气泡框架通过 contentBuilder 注入，
/// 容器/头像/时间戳/操作栏由宿主框架提供。
class AgentMessageContent extends StatelessWidget {
  final ChatMessage message;
  final Future<void> Function(String messageId, int stepIndex)? onRerunStep;

  /// 执行匹配的模版
  final Future<void> Function(String messageId, String templateId)?
  onExecuteTemplate;

  /// 获取模版名称
  final String? Function(String templateId)? getTemplateName;

  /// 获取 Agent 名称（链式模式）
  final String? Function(String agentId)? getAgentName;

  /// MessageService（用于加载链式消息）
  final dynamic messageService;

  /// 气泡文字颜色（由气泡框架按背景亮度计算传入，用户主色气泡为白色）
  final Color? textColor;

  const AgentMessageContent({
    super.key,
    required this.message,
    this.onRerunStep,
    this.onExecuteTemplate,
    this.getTemplateName,
    this.getAgentName,
    this.messageService,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return _buildContentColumn(context);
  }

  /// 构建气泡内容列（链式容器/Agent标签/正文/工具步骤/附件）
  Widget _buildContentColumn(BuildContext context) {
    final isUser = message.isUser;
    final isToolCallMessage =
        message.toolCall != null && message.toolCall!.steps.isNotEmpty;
    // 纯语音消息：无文字内容且附件全部为音频 → 不渲染正文区
    final isVoiceOnly =
        !isToolCallMessage &&
        (message.matchedTemplateIds == null ||
            message.matchedTemplateIds!.isEmpty) &&
        message.content.trim().isEmpty &&
        message.attachments.isNotEmpty &&
        message.attachments.every((a) => a.isAudio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 如果是链式调用的第一条消息，使用 ChainMessageContainer
        if (!isUser &&
            message.chainExecutionId != null &&
            message.chainStepIndex == 0 &&
            messageService != null)
          ChainMessageContainer(
            conversationId: message.conversationId,
            chainExecutionId: message.chainExecutionId!,
            messageService: messageService,
            getAgentName: getAgentName,
            onRerunStep: onRerunStep,
          )
        else ...[
          // 传统的单消息显示模式
          // Agent 标签（链式模式下显示，仅当不使用容器时）
          if (!isUser &&
              message.generatedByAgentId != null &&
              message.chainStepIndex != null)
            _buildAgentLabel(context),

          // 消息内容 - 总是实时渲染内容（流式输出）
          if (isToolCallMessage)
            // 如果是工具调用消息，显示工具调用步骤
            _buildToolCallContent()
          else if (message.matchedTemplateIds != null &&
              message.matchedTemplateIds!.isNotEmpty)
            // 显示模版选择按钮
            _buildTemplateSelectionUI()
          else if (!isVoiceOnly)
            // 总是显示消息内容（包括正在生成中的内容）
            _buildMessageContent(),

          // 附件显示（纯语音消息直接裸露，无内容间距）
          if (message.attachments.isNotEmpty) ...[
            if (!isVoiceOnly) const SizedBox(height: 8),
            _buildAttachments(),
          ],
        ],
      ],
    );
  }

  /// 构建工具调用内容
  Widget _buildToolCallContent() {
    // 如果有工具调用,显示steps组件
    if (message.toolCall != null && message.toolCall!.steps.isNotEmpty) {
      final onRerun = onRerunStep != null
          ? (int stepIndex) => onRerunStep!(message.id, stepIndex)
          : null;

      // 生成中：过程视图全展开（思考流 + 工具步骤状态 + 流式正文）
      if (message.isGenerating) {
        return Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            final streaming = _visibleStreamingText();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LiveProcessView(
                  message: message,
                  isGenerating: true,
                  onRerunStep: onRerun,
                ),
                if (streaming.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  MarkdownContent(content: streaming, textColor: textColor),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    DSLoadingDots(size: 8, color: theme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '正在生成...',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      }

      // 已完成：只显示最终回复 + 可展开的执行过程
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownContent(content: _extractFinalReply(), textColor: textColor),
          CollapsibleProcessSection(message: message, onRerunStep: onRerun),
        ],
      );
    }

    // 降级到普通文本显示
    return MarkdownContent(content: message.content, textColor: textColor);
  }

  /// 生成中可见的流式正文：剥内联 think 标签，截掉结构化展示过的工具结果段
  String _visibleStreamingText() =>
      ChatMessage.stripToolResult(message.content);

  /// 已完成消息的最终回复：优先 [AI最终回复] 标记，无标记时兜底显示
  /// 剥离 think 后、工具结果段之前的全部正文
  String _extractFinalReply() {
    final marked = _parseToolCallContent(message.content)['finalReply'];
    if (marked != null && marked.isNotEmpty) return marked;
    return ChatMessage.stripToolResult(message.content);
  }

  /// 解析工具调用消息的content
  /// 返回: {'thinking': '...', 'finalReply': '...'}
  /// 内联 think 标签已剥离（思考内容经时间戳行入口查看）
  Map<String, String> _parseToolCallContent(String content) {
    final result = <String, String>{};

    // 查找 [AI最终回复] 标记
    final finalReplyIndex = content.indexOf('[AI最终回复]');

    if (finalReplyIndex != -1) {
      // 只提取AI最终回复部分
      final replyStart = finalReplyIndex + '[AI最终回复]'.length;
      result['finalReply'] = ChatMessage.splitThink(
        content.substring(replyStart),
      ).$2;
    } else {
      // 如果没有 [AI最终回复] 标记，可能是旧数据，尝试提取工具执行结果之前的内容
      final toolResultIndex = content.indexOf('[工具执行结果]');
      if (toolResultIndex != -1) {
        // 有工具执行结果标记，但没有AI回复，提取思考内容
        final thinkingRaw = content.substring(0, toolResultIndex);
        result['thinking'] = _stripToolJsonBlocks(thinkingRaw).trim();
      } else if (content.contains('已执行工具模版:') || content.contains('执行结果：')) {
        // 是工具模板执行消息但没有AI回复，不显示任何文本（只显示工具调用步骤）
        result['thinking'] = '';
      } else {
        // 其他情况，全部作为思考内容
        result['thinking'] = _stripToolJsonBlocks(content).trim();
      }
    }

    // thinking 区域同样剥离内联 think 标签，避免原样渲染
    final thinking = result['thinking'];
    if (thinking != null && thinking.isNotEmpty) {
      result['thinking'] = ChatMessage.splitThink(thinking).$2;
    }

    return result;
  }

  /// 移除工具调用返回的JSON代码块，避免在思考区域显示
  String _stripToolJsonBlocks(String content) {
    var cleaned = content;
    cleaned = cleaned.replaceAll(
      RegExp(r'```json[\s\S]*?```', multiLine: true),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\{\s*"steps"\s*:\s*\[[\s\S]*?\]\s*\}', multiLine: true),
      '',
    );
    return cleaned;
  }

  /// 构建附件显示
  Widget _buildAttachments() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: message.attachments.map((attachment) {
        // 图片附件显示缩略图
        if (attachment.isImage) {
          return _buildImageAttachment(attachment);
        }

        // 语音附件复用 chat 的音频播放器（AI 语音消息）
        if (attachment.isAudio) {
          return Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return SizedBox(
                width: 220,
                child: AudioPlayerWidget(
                  audioPath: attachment.filePath,
                  durationInSeconds: attachment.durationSeconds ?? 0,
                  primaryColor: theme.primary,
                  backgroundColor: theme.textSub,
                ),
              );
            },
          );
        }

        // 非图片附件显示文件信息
        return _buildFileAttachment(attachment);
      }).toList(),
    );
  }

  /// 构建图片附件
  Widget _buildImageAttachment(FileAttachment attachment) {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return GestureDetector(
          onTap: () => _viewImage(context, attachment),
          child: ClipRRect(
            borderRadius: theme.radii.sm,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
              child: Image.file(
                File(attachment.filePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 200,
                    height: 150,
                    color: theme.surfaceAlt,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DsIcon(
                          DsIconKind.image,
                          size: 48,
                          color: theme.textSub,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Image load failed',
                          style: TextStyle(fontSize: 12, color: theme.textSub),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建文件附件
  Widget _buildFileAttachment(FileAttachment attachment) {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: theme.radii.sm,
            border: Border.all(color: theme.textSub.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DsIcon(DsIconKind.book, size: 16, color: theme.textSub),
              const SizedBox(width: 4),
              Text(
                attachment.fileName,
                style: TextStyle(fontSize: 12, color: theme.text),
              ),
              const SizedBox(width: 4),
              Text(
                attachment.formattedSize,
                style: TextStyle(fontSize: 10, color: theme.textSub),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 查看图片大图
  void _viewImage(BuildContext context, FileAttachment attachment) {
    GalleryViewer.showFilePreview(
      context,
      filePath: attachment.filePath,
      fileName: attachment.fileName,
      mimeType: 'image/${_getImageExtension(attachment.fileName)}',
      fileSize: attachment.fileSize,
    );
  }

  /// 获取图片扩展名
  String _getImageExtension(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return ext.isNotEmpty ? ext : 'jpg';
  }

  /// 构建模版选择UI
  Widget _buildTemplateSelectionUI() {
    // 检查模版是否已运行（通过检查是否有工具调用记录）
    final hasToolCall =
        message.toolCall != null && message.toolCall!.steps.isNotEmpty;

    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 模版卡片列表
            ...message.matchedTemplateIds!.map((templateId) {
              // 获取模版名称
              final templateName = getTemplateName?.call(templateId) ?? '未知模版';
              // 判断当前模版是否已运行
              // 只要有 toolCall，就说明已经执行了
              final isExecuted = hasToolCall;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 模版卡片
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isExecuted
                            ? theme.success.mixWhite(0.85)
                            : theme.primary.mixWhite(0.85),
                        border: Border.all(
                          color: isExecuted ? theme.success : theme.primary,
                        ),
                        borderRadius: theme.radii.sm,
                      ),
                      child: Row(
                        children: [
                          // 左侧：图标
                          DsIcon(
                            isExecuted ? DsIconKind.check : DsIconKind.play,
                            size: 24,
                            color: isExecuted
                                ? theme.success
                                : theme.primaryText,
                          ),
                          const SizedBox(width: 12),

                          // 中间：模版信息
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  templateName,
                                  style: DsTypography.heading.copyWith(
                                    color: theme.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isExecuted ? '已运行' : '待运行',
                                  style: DsTypography.caption.copyWith(
                                    color: isExecuted
                                        ? theme.success
                                        : theme.primaryText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 右侧：操作按钮
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 查看结果按钮（仅已运行时显示）
                              if (isExecuted) ...[
                                Pressable(
                                  onPressed: () =>
                                      _showTemplateResultDialog(context),
                                  semanticLabel: '查看结果',
                                  builder: (context, states) => DsIcon(
                                    DsIconKind.info,
                                    size: 20,
                                    color: theme.success,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],

                              // 运行/重新运行按钮
                              DSButton(
                                label: isExecuted ? '重新运行' : '运行',
                                icon: isExecuted
                                    ? DsIconKind.refresh
                                    : DsIconKind.play,
                                size: DSButtonSize.sm,
                                variant: isExecuted
                                    ? DSButtonVariant.secondary
                                    : DSButtonVariant.primary,
                                onPressed: onExecuteTemplate != null
                                    ? () => onExecuteTemplate!(
                                        message.id,
                                        templateId,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 分割线（如果有 AI 回复内容）
                    if (message.content.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Divider(
                        color: theme.textSub.withValues(alpha: 0.3),
                        thickness: 1,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // AI 最终回复（从 content 中提取，排除工具结果部分）
                    if (message.content.isNotEmpty) _buildFinalReplyContent(),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  /// 构建 AI 最终回复内容（排除工具执行结果部分）
  Widget _buildFinalReplyContent() {
    String content = message.content;

    // 支持多种格式的工具结果分隔符
    final markers = ['[工具执行结果]', '工具执行结果:', '工具执行结果：'];

    int toolResultIndex = -1;
    for (var marker in markers) {
      final index = content.indexOf(marker);
      if (index != -1) {
        toolResultIndex = index;
        break;
      }
    }

    // 没有找到工具结果标记，直接显示内容（剥离内联 think 标签）
    if (toolResultIndex == -1) {
      return MarkdownContent(
        content: ChatMessage.splitThink(content).$2,
        textColor: textColor,
      );
    }

    // 找到工具结果后面的内容
    final afterToolResult = content.substring(toolResultIndex);

    // 查找结束标记（如 "请根据以上工具执行结果直接回答用户的问题" 后的内容）
    final promptEndMarkers = [
      '请根据以上工具执行结果直接回答用户的问题，不要再次调用工具。',
      '请根据以上工具执行结果直接回答用户的问题',
    ];

    int finalReplyStart = -1;

    // 首先尝试查找 [AI最终回复] 标记
    final aiReplyIndex = content.indexOf('[AI最终回复]');
    if (aiReplyIndex != -1) {
      finalReplyStart = aiReplyIndex + '[AI最终回复]'.length;
    } else {
      // 尝试查找提示词结束标记后的内容
      for (var marker in promptEndMarkers) {
        final index = afterToolResult.indexOf(marker);
        if (index != -1) {
          finalReplyStart = toolResultIndex + index + marker.length;
          break;
        }
      }
    }

    if (finalReplyStart != -1) {
      // 找到了最终回复的开始位置（剥离内联 think 标签）
      final finalReply = ChatMessage.splitThink(
        content.substring(finalReplyStart).trim(),
      ).$2;

      if (finalReply.isEmpty) {
        // 最终回复为空，显示加载状态
        return _buildToolLoadingState();
      } else {
        // 显示最终回复
        return MarkdownContent(content: finalReply, textColor: textColor);
      }
    } else {
      // 没有找到最终回复，说明还在执行中，显示加载状态
      return _buildToolLoadingState();
    }
  }

  /// 构建工具执行时的加载状态
  Widget _buildToolLoadingState() {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DSLoadingDots(size: 8, color: theme.primary),
                const SizedBox(width: 8),
                Text(
                  'AI正在构建答案...',
                  style: DsTypography.caption.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.textSub,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 显示模版结果对话框
  void _showTemplateResultDialog(BuildContext context) {
    // 获取工具调用结果
    if (message.toolCall == null || message.toolCall!.steps.isEmpty) {
      return;
    }

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (ctx) {
            final theme = DSThemeBridge.resolve(ctx);
            return JellyBox(
              radius: theme.radii.xxl,
              padding: EdgeInsets.all(theme.spacing.xl),
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      DsIcon(
                        DsIconKind.clipboard,
                        color: theme.primaryText,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'agent_chat_toolExecutionResult'.tr,
                          style: DsTypography.title.copyWith(color: theme.text),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: theme.spacing.md),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: message.toolCall!.steps.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(height: theme.spacing.lg),
                      itemBuilder: (context, index) {
                        final step = message.toolCall!.steps[index];
                        final isSuccess = step.status == ToolCallStatus.success;
                        final isFailed = step.status == ToolCallStatus.failed;
                        final statusColor = isSuccess
                            ? theme.success
                            : isFailed
                            ? theme.danger
                            : theme.textSub;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 步骤标题
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.primary.mixWhite(0.88),
                                    borderRadius: theme.radii.sm,
                                  ),
                                  child: Text(
                                    '步骤 ${index + 1}',
                                    style: DsTypography.caption.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    step.title,
                                    style: DsTypography.heading.copyWith(
                                      color: theme.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // 步骤描述
                            if (step.desc.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                step.desc,
                                style: DsTypography.caption.copyWith(
                                  color: theme.text,
                                ),
                              ),
                            ],

                            // 执行结果
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSuccess
                                    ? theme.success.mixWhite(0.88)
                                    : isFailed
                                    ? theme.danger.mixWhite(0.9)
                                    : theme.surfaceAlt,
                                borderRadius: theme.radii.sm,
                                border: Border.all(color: statusColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      DsIcon(
                                        isSuccess
                                            ? DsIconKind.check
                                            : isFailed
                                            ? DsIconKind.close
                                            : DsIconKind.clock,
                                        size: 16,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isSuccess
                                            ? '执行成功'
                                            : isFailed
                                            ? '执行失败'
                                            : '执行中',
                                        style: DsTypography.caption.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (step.result != null ||
                                      step.error != null) ...[
                                    const SizedBox(height: 8),
                                    Divider(
                                      height: 1,
                                      color: theme.textSub.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      step.error ?? step.result ?? '无结果',
                                      style: DsTypography.caption.copyWith(
                                        fontFamily: 'monospace',
                                        color: theme.text,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  SizedBox(height: theme.spacing.md),
                  DSButton(
                    label: 'agent_chat_close'.tr,
                    expand: true,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 构建消息内容（处理工具模板和普通文本）
  Widget _buildMessageContent() {
    // 检查是否有工具模板信息（用户消息）
    final toolTemplate =
        message.metadata?['toolTemplate'] as Map<String, dynamic>?;
    final hasToolTemplate = toolTemplate != null;
    // 正文剥离内联 <think> 标签（思考内容经时间戳行入口查看）
    final visibleContent = message.splitThinkContent().$2;
    final hasContent = visibleContent.isNotEmpty;

    // 无正文无模板：生成中的纯思考阶段显示可展开的"思考中"入口；
    // 完成后思考经时间戳行入口查看
    if (!hasContent && !hasToolTemplate) {
      final thinking = message.resolvedThinkingContent;
      if (thinking != null) {
        if (message.isGenerating) {
          return ThinkingLiveView(thinking: thinking);
        }
        return const SizedBox.shrink();
      }
      return Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Text(
            '(空消息)',
            style: TextStyle(fontStyle: FontStyle.italic, color: theme.textSub),
          );
        },
      );
    }

    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 显示工具模板（如果有）
            if (hasToolTemplate) ...[
              _buildUserToolTemplate(toolTemplate),
              // 如果同时有文本内容，添加分隔
              if (hasContent) ...[
                const SizedBox(height: 8),
                Divider(
                  color: theme.textSub.withValues(alpha: 0.3),
                  thickness: 1,
                ),
                const SizedBox(height: 8),
              ],
            ],
            // 显示文本内容（如果有）
            if (hasContent)
              MarkdownContent(content: visibleContent, textColor: textColor),
          ],
        );
      },
    );
  }

  /// 构建用户选择的工具模板显示
  Widget _buildUserToolTemplate(Map<String, dynamic> toolTemplate) {
    final name = toolTemplate['name'] as String? ?? '未知模板';
    final description = toolTemplate['description'] as String?;

    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.secondary.mixWhite(0.85),
            borderRadius: theme.radii.sm,
            border: Border.all(color: theme.secondary),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DsIcon(DsIconKind.gear, size: 18, color: theme.textSub),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '工具模板:',
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            name,
                            style: DsTypography.body.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建 Agent 标签（链式模式）
  Widget _buildAgentLabel(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final agentName =
        getAgentName?.call(message.generatedByAgentId!) ?? 'Agent';
    final stepIndex = message.chainStepIndex!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.primary.mixWhite(0.9),
          borderRadius: theme.radii.sm,
          border: Border.all(color: theme.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsIcon(DsIconKind.layers, size: 14, color: theme.primaryText),
            const SizedBox(width: 4),
            Text(
              '步骤 ${stepIndex + 1}: $agentName',
              style: DsTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
