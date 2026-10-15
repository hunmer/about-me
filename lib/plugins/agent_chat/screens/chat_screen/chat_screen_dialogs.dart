part of 'chat_screen.dart';

/// 消息级对话框与工具处理 / 管理页跳转
extension _ChatScreenDialogsExt on _ChatScreenState {
  /// 显示清空聊天记录确认对话框
  Future<void> _showClearMessagesConfirm() async {
    if (_controller.messages.isEmpty) {
      toastService.showToast('当前没有消息记录');
      return;
    }

    final confirm = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (ctx) => DSDialog(
            title: 'agent_chat_confirmClear'.tr,
            message:
                '确定要清空当前会话的所有消息吗？\n\n'
                '当前共有 ${_controller.messages.length} 条消息，此操作不可恢复。',
            cancelText: 'agent_chat_cancel'.tr,
            confirmText: 'agent_chat_clear'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () => Navigator.pop(dialogContext, true),
            onCancel: () => Navigator.pop(dialogContext, false),
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _controller.clearAllMessages();
        if (mounted) {
          toastService.showToast('聊天记录已清空');
        }
      } catch (e) {
        if (mounted) {
          toastService.showToast('清空失败: $e');
        }
      }
    }
  }

  /// 显示消息编辑对话框
  void _showEditMessageDialog(ChatMessage source) {
    final textController = TextEditingController(text: source.content);
    // 与原实现一致：字符数在打开时计算一次
    final initialLength = textController.text.length;

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
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                      const SizedBox(width: 8),
                      if (!source.isUser)
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
                                newContent != source.content) {
                              _controller.editMessage(source.id, newContent);
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

  /// 底部 sheet 显示思考过程（独立 thinkingContent + 内联 think 合并展示）
  void _showThinkingSheet(ChatMessage source) {
    showDSBottomSheet(
      context: context,
      title: '思考过程',
      builder: (sheetContext) => DSThemeBridge(
        child: Builder(
          builder: (ctx) {
            final theme = DSThemeBridge.resolve(ctx);
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.6,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.xl),
                child: MarkdownContent(
                  content: source.resolvedThinkingContent ?? '',
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 显示工具调用详情对话框
  Future<void> _showToolDetail(ChatMessage source) async {
    // 显示加载指示器
    showDSDialog(
      context: context,
      barrierDismissible: false,
      theme: DSThemeBridge.resolve(context),
      builder: (_) =>
          const DSThemeBridge(child: Center(child: DSLoadingDots())),
    );

    try {
      // 加载消息详细数据
      final detailService = MessageDetailService(storage: widget.storage);
      final detail = await detailService.loadDetail(source.id);

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
          builder: (dialogContext) => ToolDetailDialog(
            detail: detail,
            toolCallSteps: source.toolCall?.steps,
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

  /// 显示Token统计
  void _showTokenStats() {
    final totalTokens = _controller.getTotalTokens();
    final contextTokens = _controller.getContextTokens();

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
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'agent_chat_tokenStatistics'.tr,
                    textAlign: TextAlign.center,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.md),
                  _buildStatRow(ctx, '总Token数', totalTokens.toString()),
                  SizedBox(height: theme.spacing.sm),
                  _buildStatRow(ctx, '上下文Token数', contextTokens.toString()),
                  SizedBox(height: theme.spacing.sm),
                  _buildStatRow(
                    ctx,
                    '上下文消息数',
                    '${_controller.contextMessageCount} 条',
                  ),
                  SizedBox(height: theme.spacing.md),
                  Text(
                    '注：Token数为估算值，实际消耗以API返回为准',
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                  SizedBox(height: theme.spacing.md),
                  DSButton(
                    label: 'agent_chat_close'.tr,
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    final theme = DSThemeBridge.resolve(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: DsTypography.body.copyWith(color: theme.text)),
        Text(
          value,
          style: DsTypography.body.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.text,
          ),
        ),
      ],
    );
  }

  /// 处理保存工具
  Future<void> _handleSaveTool(ChatMessage message) async {
    await showSaveToolDialog(
      context,
      message,
      _templateService,
      declaredTools: _controller.selectedTools,
    );
  }

  /// 处理重新执行工具
  Future<void> _handleRerunTool(String messageId) async {
    try {
      await _controller.rerunToolCall(messageId);
      if (mounted) {
        toastService.showToast('工具重新执行完成');
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('重新执行工具失败: $e');
      }
    }
  }

  /// 处理重新执行单个步骤
  Future<void> _handleRerunStep(String messageId, int stepIndex) async {
    try {
      await _controller.rerunSingleStep(messageId, stepIndex);
      if (mounted) {
        toastService.showToast('步骤 ${stepIndex + 1} 重新执行完成');
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('重新执行步骤失败: $e');
      }
    }
  }

  /// 打开工具模板管理界面
  void _openToolTemplateManagement() {
    NavigationHelper.push(
      context,
      ToolTemplateScreen(
        templateService: _templateService,
        onUseTemplate: (template) {
          _controller.setSelectedToolTemplate(template);
        },
      ),
    );
  }

  /// 打开工具管理界面
  void _openToolManagement() {
    NavigationHelper.push(
      context,
      ToolManagementScreen(
        conversationId: widget.conversation.id,
        onAddToChat: (pluginId, toolId, config) async {
          await _controller.addToolToConversation(
            pluginId,
            toolId,
            config.title,
          );
          if (mounted) {
            toastService.showToast('已添加工具: ${config.title}');
          }
        },
      ),
    );
  }

  /// 打开 agent 朋友圈
  void _openMoments() {
    NavigationHelper.push(context, const MomentsScreen());
  }

  /// 显示删除确认对话框
  Future<void> _showDeleteConfirmation(String messageId) async {
    final confirm = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (ctx) => DSDialog(
            title: 'agent_chat_confirmDelete'.tr,
            message: 'agent_chat_confirmDeleteMessage'.tr,
            cancelText: 'agent_chat_cancel'.tr,
            confirmText: 'agent_chat_delete'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () => Navigator.pop(dialogContext, true),
            onCancel: () => Navigator.pop(dialogContext, false),
          ),
        ),
      ),
    );

    if (confirm == true) {
      await _controller.deleteMessage(messageId);
    }
  }
}
