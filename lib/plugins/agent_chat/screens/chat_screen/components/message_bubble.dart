import 'dart:io';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:flutter/services.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/file_attachment.dart';
import 'package:aboutme/plugins/agent_chat/services/token_counter_service.dart';
import 'package:aboutme/plugins/agent_chat/services/message_detail_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/file_preview/file_preview_screen.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'markdown_content.dart';
import 'tool_detail_dialog.dart';
import 'tool_call_steps.dart';
import 'chain_message_container.dart';
import 'package:timeago/timeago.dart' as timeago;

/// 消息气泡组件
///
/// 极简设计，显示单条消息
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Future<void> Function(String messageId, String newContent)? onEdit;
  final Future<void> Function(String messageId)? onDelete;
  final Future<void> Function(String messageId)? onRegenerate;
  final Future<void> Function(ChatMessage message)? onSaveTool;
  final Future<void> Function(String messageId)? onRerunTool;
  final Future<void> Function(String messageId, int stepIndex)? onRerunStep;
  final Future<void> Function(String messageId, String templateId)?
  onExecuteTemplate; // 执行匹配的模版
  final String? Function(String templateId)? getTemplateName; // 获取模版名称
  final String? Function(String agentId)? getAgentName; // 获取 Agent 名称（链式模式）
  final VoidCallback? onCancel; // 取消生成的回调
  final bool hasAgent;
  final StorageManager? storage;

  /// MessageService（用于加载链式消息）
  final dynamic messageService;

  const MessageBubble({
    super.key,
    required this.message,
    this.onEdit,
    this.onDelete,
    this.onRegenerate,
    this.onSaveTool,
    this.onRerunTool,
    this.onRerunStep,
    this.onExecuteTemplate,
    this.getTemplateName,
    this.getAgentName,
    this.onCancel,
    this.hasAgent = true,
    this.storage,
    this.messageService,
  });

  @override
  Widget build(BuildContext context) {
    // 如果是会话分隔符，显示特殊样式
    if (message.isSessionDivider) {
      return _buildSessionDivider();
    }

    // -  如果是链式调用的后续消息（不是第一条）或最终总结消息，隐藏显示
    // 注意：isFinalSummary 消息在单agent模式下应该显示，所以不隐藏
    if (message.chainExecutionId != null &&
        ((message.chainStepIndex != null && message.chainStepIndex! > 0) ||
            message.isFinalSummary)) {
      return const SizedBox.shrink();
    }

    final isUser = message.isUser;
    final isToolCallMessage =
        message.toolCall != null && message.toolCall!.steps.isNotEmpty;
    final theme = DSThemeBridge.resolve(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // 消息内容
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // 消息气泡
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isUser
                            ? theme.primary.mixWhite(0.85)
                            : theme.surfaceAlt,
                    borderRadius: theme.radii.md,
                  ),
                  child: Column(
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
                        else
                          // 总是显示消息内容（包括正在生成中的内容）
                          _buildMessageContent(),

                        // 附件显示
                        if (message.attachments.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildAttachments(),
                        ],
                      ],
                    ],
                  ),
                ),

                // 底部信息栏
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Token统计
                    Text(
                      TokenCounterService.formatTokenCountShort(
                        message.tokenCount,
                      ),
                      style: TextStyle(fontSize: 11, color: theme.textSub),
                    ),

                    const SizedBox(width: 8),

                    // 时间
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(fontSize: 11, color: theme.textSub),
                    ),

                    // 显示思考过程按钮（仅当有思考内容且不是用户消息时显示）
                    if (!isUser &&
                        message.thinkingContent != null &&
                        message.thinkingContent!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Pressable(
                        onPressed: () => _showThinkingDialog(context),
                        builder:
                            (context, states) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DsIcon(
                                  DsIconKind.bot,
                                  size: 12,
                                  color: theme.primaryText,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '显示思考过程',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.primaryText,
                                  ),
                                ),
                              ],
                            ),
                      ),
                    ],

                    // 已编辑标记
                    if (message.editedAt != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(已编辑)',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.textSub.withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],

                    // 操作按钮
                    if (!message.isGenerating) ...[
                      const SizedBox(width: 8),
                      _buildActionMenu(context),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建会话分隔符
  Widget _buildSessionDivider() {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Divider(
                  color: theme.primary.withValues(alpha: 0.45),
                  thickness: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primary.mixWhite(0.88),
                    borderRadius: theme.radii.md,
                    border: Border.all(color: theme.primary),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DsIcon(
                        DsIconKind.plus,
                        size: 16,
                        color: theme.primaryText,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        message.content,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.primaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: theme.primary.withValues(alpha: 0.45),
                  thickness: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建工具调用内容
  Widget _buildToolCallContent() {
    // 如果有工具调用,显示steps组件
    if (message.toolCall != null && message.toolCall!.steps.isNotEmpty) {
      return Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          // 智能解析content，提取思考内容和AI回复
          final parsedContent = _parseToolCallContent(message.content);

          // 检查工具调用是否已经被解析（有steps）
          final toolCallParsed = message.toolCall?.steps.isNotEmpty ?? false;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 显示AI最终回复（优先显示）
              if (parsedContent['finalReply']?.isNotEmpty ?? false) ...[
                MarkdownContent(content: parsedContent['finalReply']!),
                const SizedBox(height: 12),
              ]
              // 只有当工具调用还未解析时，才显示正在生成的 markdown
              else if (!toolCallParsed &&
                  message.isGenerating &&
                  message.content.isNotEmpty) ...[
                // 实时显示正在生成的 Markdown 内容
                MarkdownContent(content: message.content),
                const SizedBox(height: 12),
              ]
              // 如果正在生成但没有内容，显示加载占位符
              else if (message.isGenerating) ...[
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
                const SizedBox(height: 12),
              ],

              // 显示工具调用步骤
              ToolCallSteps(
                steps: message.toolCall!.steps,
                isGenerating: message.isGenerating,
                onRerunStep:
                    onRerunStep != null
                        ? (stepIndex) => onRerunStep!(message.id, stepIndex)
                        : null,
              ),

              // 只有在工具调用未解析时，才显示思考内容（原始markdown）
              // 工具调用解析成功后，隐藏原始内容以避免重复显示
              if (!toolCallParsed &&
                  (parsedContent['thinking']?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                MarkdownContent(content: parsedContent['thinking']!),
              ],
            ],
          );
        },
      );
    }

    // 降级到普通文本显示
    return MarkdownContent(content: message.content);
  }

  /// 解析工具调用消息的content
  /// 返回: {'thinking': '...', 'finalReply': '...'}
  Map<String, String> _parseToolCallContent(String content) {
    final result = <String, String>{};

    // 查找 [AI最终回复] 标记
    final finalReplyIndex = content.indexOf('[AI最终回复]');

    if (finalReplyIndex != -1) {
      // 只提取AI最终回复部分
      final replyStart = finalReplyIndex + '[AI最终回复]'.length;
      result['finalReply'] = content.substring(replyStart).trim();
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
      children:
          message.attachments.map((attachment) {
            // 图片附件显示缩略图
            if (attachment.isImage) {
              return _buildImageAttachment(attachment);
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
    NavigationHelper.push(
      context,
      FilePreviewScreen(
        filePath: attachment.filePath,
        fileName: attachment.fileName,
        mimeType: 'image/${_getImageExtension(attachment.fileName)}',
        fileSize: attachment.fileSize,
      ),
    );
  }

  /// 获取图片扩展名
  String _getImageExtension(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return ext.isNotEmpty ? ext : 'jpg';
  }

  /// 构建操作菜单
  Widget _buildActionMenu(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final isToolCallMessage =
        message.toolCall != null && message.toolCall!.steps.isNotEmpty;

    return DSPopover(
      width: 200,
      contentBuilder: (popoverContext, close) {
        final popoverTheme = DSThemeBridge.resolve(popoverContext);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MenuAction(
              icon: DsIconKind.copy,
              label: 'agent_chat_copy'.tr,
              theme: popoverTheme,
              onTap: () {
                close();
                Clipboard.setData(ClipboardData(text: message.content));
                toastService.showToast('已复制到剪贴板');
              },
            ),
            // 允许编辑所有消息（除了工具调用消息）
            if (onEdit != null && !isToolCallMessage)
              _MenuAction(
                icon: DsIconKind.edit,
                label: 'agent_chat_edit'.tr,
                theme: popoverTheme,
                onTap: () {
                  close();
                  _showEditDialog(context);
                },
              ),
            if (!message.isUser && onRegenerate != null && hasAgent)
              _MenuAction(
                icon: DsIconKind.refresh,
                label: 'agent_chat_regenerate'.tr,
                theme: popoverTheme,
                onTap: () {
                  close();
                  onRegenerate?.call(message.id);
                },
              ),
            if (!message.isUser && isToolCallMessage && onSaveTool != null)
              _MenuAction(
                icon: DsIconKind.download,
                label: 'agent_chat_saveTool'.tr,
                theme: popoverTheme,
                accent: popoverTheme.primaryText,
                onTap: () {
                  close();
                  onSaveTool?.call(message);
                },
              ),
            if (!message.isUser && isToolCallMessage && onRerunTool != null)
              _MenuAction(
                icon: DsIconKind.refresh,
                label: 'agent_chat_reExecuteTool'.tr,
                theme: popoverTheme,
                accent: popoverTheme.secondary,
                onTap: () {
                  close();
                  onRerunTool?.call(message.id);
                },
              ),
            if (!message.isUser && isToolCallMessage && storage != null)
              _MenuAction(
                icon: DsIconKind.info,
                label: 'agent_chat_viewDetails'.tr,
                theme: popoverTheme,
                accent: popoverTheme.primaryText,
                onTap: () {
                  close();
                  _showToolDetailDialog(context);
                },
              ),
            if (onDelete != null)
              _MenuAction(
                icon: DsIconKind.trash,
                label: 'agent_chat_delete'.tr,
                theme: popoverTheme,
                accent: popoverTheme.danger,
                onTap: () {
                  close();
                  onDelete?.call(message.id);
                },
              ),
          ],
        );
      },
      child: DsIcon(DsIconKind.more, size: 16, color: theme.textSub),
    );
  }

  /// 显示编辑对话框
  void _showEditDialog(BuildContext context) {
    final textController = TextEditingController(text: message.content);
    // 与原实现一致：字符数在打开时计算一次
    final initialLength = textController.text.length;

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder: (ctx) {
                final theme = DSThemeBridge.resolve(ctx);
                return JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'agent_chat_editMessage'.tr,
                            style: DsTypography.title.copyWith(
                              color: theme.text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!message.isUser)
                            DSBadge(
                              label: 'AI',
                              color: theme.secondary,
                              textColor: theme.text,
                            ),
                        ],
                      ),
                      SizedBox(height: theme.spacing.md),
                      DSInput(
                        controller: textController,
                        hint: '输入消息内容...',
                        maxLines: null,
                        minLines: 5,
                        keyboardType: TextInputType.multiline,
                      ),
                      SizedBox(height: theme.spacing.xs),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$initialLength 字符',
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                        ),
                      ),
                      SizedBox(height: theme.spacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: DSButton(
                              label: 'agent_chat_cancel'.tr,
                              variant: DSButtonVariant.outline,
                              onPressed: () => Navigator.pop(dialogContext),
                            ),
                          ),
                          SizedBox(width: theme.spacing.md),
                          Expanded(
                            child: DSButton(
                              label: 'agent_chat_save'.tr,
                              onPressed: () {
                                final newContent = textController.text.trim();
                                if (newContent.isNotEmpty &&
                                    newContent != message.content) {
                                  onEdit?.call(message.id, newContent);
                                }
                                Navigator.pop(dialogContext);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
  }

  /// 显示工具调用详情对话框
  Future<void> _showToolDetailDialog(BuildContext context) async {
    if (storage == null) {
      toastService.showToast('无法加载详情数据');
      return;
    }

    // 显示加载指示器
    showDSDialog(
      context: context,
      barrierDismissible: false,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => const DSThemeBridge(child: Center(child: DSLoadingDots())),
    );

    try {
      // 加载消息详细数据
      final detailService = MessageDetailService(storage: storage!);
      final detail = await detailService.loadDetail(message.id);

      // 关闭加载指示器
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (detail == null) {
        if (context.mounted) {
          toastService.showToast('未找到详细数据，可能此消息是在更新前创建的');
        }
        return;
      }

      // 显示详情对话框
      if (context.mounted) {
        showDSDialog(
          context: context,
          theme: DSThemeBridge.resolve(context),
          builder:
              (dialogContext) => ToolDetailDialog(
                detail: detail,
                toolCallSteps: message.toolCall?.steps,
              ),
        );
      }
    } catch (e) {
      // 关闭加载指示器
      if (context.mounted) {
        Navigator.of(context).pop();
        toastService.showToast('加载详情失败: $e');
      }
    }
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
                        color:
                            isExecuted
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
                            color:
                                isExecuted ? theme.success : theme.primaryText,
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
                                    color:
                                        isExecuted
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
                                  onPressed:
                                      () => _showTemplateResultDialog(context),
                                  semanticLabel: '查看结果',
                                  builder:
                                      (context, states) => DsIcon(
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
                                icon:
                                    isExecuted
                                        ? DsIconKind.refresh
                                        : DsIconKind.play,
                                size: DSButtonSize.sm,
                                variant:
                                    isExecuted
                                        ? DSButtonVariant.secondary
                                        : DSButtonVariant.primary,
                                onPressed:
                                    onExecuteTemplate != null
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

    // 没有找到工具结果标记，直接显示内容
    if (toolResultIndex == -1) {
      return MarkdownContent(content: content);
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
      // 找到了最终回复的开始位置
      final finalReply = content.substring(finalReplyStart).trim();

      if (finalReply.isEmpty) {
        // 最终回复为空，显示加载状态
        return _buildToolLoadingState();
      } else {
        // 显示最终回复
        return MarkdownContent(content: finalReply);
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
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder: (ctx) {
                final theme = DSThemeBridge.resolve(ctx);
                return JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(
                    maxWidth: 480,
                    maxHeight: 560,
                  ),
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
                              style: DsTypography.title.copyWith(
                                color: theme.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: theme.spacing.md),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: message.toolCall!.steps.length,
                          separatorBuilder:
                              (context, index) =>
                                  SizedBox(height: theme.spacing.lg),
                          itemBuilder: (context, index) {
                            final step = message.toolCall!.steps[index];
                            final isSuccess =
                                step.status == ToolCallStatus.success;
                            final isFailed =
                                step.status == ToolCallStatus.failed;
                            final statusColor =
                                isSuccess
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
                                    color:
                                        isSuccess
                                            ? theme.success.mixWhite(0.88)
                                            : isFailed
                                            ? theme.danger.mixWhite(0.9)
                                            : theme.surfaceAlt,
                                    borderRadius: theme.radii.sm,
                                    border: Border.all(color: statusColor),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            style: DsTypography.caption
                                                .copyWith(
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
    final hasContent = message.content.isNotEmpty;

    // 如果既没有内容也没有工具模板，显示空消息提示
    if (!hasContent && !hasToolTemplate) {
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
            if (hasContent) MarkdownContent(content: message.content),
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

  /// 显示思考过程对话框
  void _showThinkingDialog(BuildContext context) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder: (ctx) {
                final theme = DSThemeBridge.resolve(ctx);
                return JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(
                    maxWidth: 480,
                    maxHeight: 520,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          DsIcon(
                            DsIconKind.bot,
                            color: theme.primaryText,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '思考过程',
                            style: DsTypography.title.copyWith(
                              color: theme.text,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: theme.spacing.md),
                      Flexible(
                        child: SingleChildScrollView(
                          child: MarkdownContent(
                            content: message.thinkingContent ?? '',
                          ),
                        ),
                      ),
                      SizedBox(height: theme.spacing.md),
                      DSButton(
                        label: '关闭',
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

  /// 格式化时间
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 24) {
      return timeago.format(dateTime, locale: 'zh');
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// 气泡菜单行（DSPopover 内容）
class _MenuAction extends StatelessWidget {
  const _MenuAction({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.accent,
  });

  final DsIconKind icon;
  final String label;
  final AppThemeData theme;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final effective = accent ?? theme.text;
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: pressed ? theme.surfaceAlt : null,
            borderRadius: theme.radii.sm,
          ),
          child: Row(
            children: [
              DsIcon(icon, size: 16, color: effective),
              SizedBox(width: theme.spacing.sm),
              Text(
                label,
                style: DsTypography.caption.copyWith(color: effective),
              ),
            ],
          ),
        );
      },
    );
  }
}
