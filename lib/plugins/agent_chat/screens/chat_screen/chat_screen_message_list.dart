part of 'chat_screen.dart';

/// 消息列表：适配 / 日期分隔 / 多选 / 气泡操作栏
extension _ChatScreenMessageListExt on _ChatScreenState {
  /// 消息列表：适配为通用 Message 模型，气泡复用 chat 框架 + agent 内容注入
  Widget _buildAgentMessageList() {
    // 搜索/过滤时展示过滤结果
    final messages = _searchQuery.isNotEmpty || _filterState.hasAnyFilter
        ? _filteredMessages
        : _controller.messages;
    final sourceById = <String, ChatMessage>{};
    final adapted = <Message>[];
    for (final message in messages) {
      sourceById[message.id] = message;
      adapted.add(_adaptMessage(message));
    }

    // 组内首条：发送方切换或跨天时重显头像/用户名（与 chat 分组策略一致）
    final firstOfGroupById = <String, bool>{};
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final prev = i > 0 ? messages[i - 1] : null;
      firstOfGroupById[message.id] =
          prev == null ||
          prev.isUser != message.isUser ||
          !_isSameDay(prev.timestamp, message.timestamp);
    }

    return MessageList(
      items: _buildItemsWithDateSeparators(adapted),
      isMultiSelectMode: _isMultiSelectMode,
      selectedMessageIds: _selectedMessageIds,
      scrollController: _scrollController,
      bubbleBuilder: (context, message) {
        final source = sourceById[message.id];
        if (source == null) return const SizedBox.shrink();

        // 会话分隔符：特殊样式，不进气泡框架
        if (source.isSessionDivider) {
          return _SessionDivider(message: source);
        }

        // 链式调用的后续消息/最终总结隐藏（与原 agent 气泡逻辑一致）
        if (source.chainExecutionId != null &&
            ((source.chainStepIndex != null && source.chainStepIndex! > 0) ||
                source.isFinalSummary)) {
          return const SizedBox.shrink();
        }

        return _BubbleEntrance(
          isNew: source.timestamp.isAfter(
            DateTime.now().subtract(const Duration(seconds: 5)),
          ),
          alignRight: source.isUser,
          // chat 气泡框架：头像/时间戳/悬浮操作栏，内容由 agent 组件注入
          child: chat_bubble.MessageBubble(
            message: message,
            isSelected: _selectedMessageIds.value.contains(source.id),
            isMultiSelectMode: _isMultiSelectMode,
            // 多选模式下点击气泡切换选中
            onTap: _isMultiSelectMode
                ? () => _toggleMessageSelection(source.id)
                : null,
            currentUserId: _ChatScreenState._localUser.id,
            showAvatar: true,
            isFirstOfGroup: firstOfGroupById[source.id] ?? true,
            onEdit: () => _showEditMessageDialog(source),
            onDelete: () => _showDeleteConfirmation(source.id),
            onCopy: () => _copyMessage(source),
            onSetFixedSymbol: (_) {},
            contentBuilder: (context, message, textColor) =>
                AgentMessageContent(
                  message: source,
                  textColor: textColor,
                  onExecuteTemplate: (messageId, templateId) async {
                    final template = _controller.templateService
                        ?.getTemplateById(templateId);
                    if (template != null) {
                      await _controller.executeMatchedTemplate(
                        messageId,
                        template,
                      );
                    }
                  },
                  onRerunStep: (messageId, stepIndex) async {
                    await _handleRerunStep(messageId, stepIndex);
                  },
                  getTemplateName: (templateId) {
                    return _controller.templateService
                        ?.getTemplateById(templateId)
                        ?.name;
                  },
                  getAgentName: (agentId) {
                    // 从 agent 链中查找
                    if (_isChainMode && _agentChain != null) {
                      final agent = _agentChain!.firstWhere(
                        (a) => a.id == agentId,
                        orElse: () => _agentChain!.first,
                      );
                      return agent.name;
                    }
                    return _currentAgent?.name;
                  },
                  messageService: _controller.messageService,
                ),
            infoBarTrailing: _buildThinkingEntry(source),
            actionsOverride: _buildAgentActionRow(source),
            showActionsOnOwnMessage: true,
          ),
        );
      },
      // 以下回调仅默认气泡路径使用，自定义气泡下不生效
      onMessageEdit: (_) {},
      onMessageDelete: (_) async {},
      onMessageCopy: (_) {},
      onSetFixedSymbol: (_, _) {},
      onSetBubbleColor: (_, _) {},
      onReply: (_) {},
      onToggleFavorite: (_) {},
      onToggleMessageSelection: (_) {},
      onReplyTap: (_) {},
    );
  }

  /// 将 agent 的 ChatMessage 适配为通用 Message 模型（用于气泡框架布局/日期分隔）
  Message _adaptMessage(ChatMessage message) {
    final isUser = message.isUser;
    return Message(
      id: message.id,
      content: message.content,
      user: isUser
          ? _ChatScreenState._localUser
          : User(
              id: 'agent_chat_agent',
              username: _getAgentDisplayText(),
              iconPath: _currentAgent?.avatarUrl,
            ),
      type: isUser ? MessageType.sent : MessageType.received,
      date: message.timestamp,
      editedAt: message.editedAt,
      metadata: {
        ...?message.metadata,
        // 用户消息被 AI 已读（活人感）：转换为 chat 气泡的 readBy 约定
        if (isUser && message.metadata?['readAt'] != null)
          'readBy': <dynamic>['ai'],
      },
    );
  }

  /// 复制消息内容
  void _copyMessage(ChatMessage source) {
    Clipboard.setData(ClipboardData(text: source.content));
    toastService.showToast('已复制到剪贴板');
  }

  /// 切换多选模式（退出时清空选中）
  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedMessageIds.value = <String>{};
      }
    });
  }

  /// 切换消息选中状态
  void _toggleMessageSelection(String messageId) {
    final selected = Set<String>.from(_selectedMessageIds.value);
    if (!selected.add(messageId)) {
      selected.remove(messageId);
    }
    _selectedMessageIds.value = selected;
  }

  /// 复制多条选中的消息
  void _copySelectedMessages() {
    final selectedMessages = _controller.messages
        .where((m) => _selectedMessageIds.value.contains(m.id))
        .toList();

    if (selectedMessages.isEmpty) return;

    final textToCopy = selectedMessages
        .map((m) => '${m.isUser ? '我' : 'AI'}: ${m.content}')
        .join('\n\n');

    Clipboard.setData(ClipboardData(text: textToCopy));
    toastService.showToast('已复制 ${selectedMessages.length} 条消息');

    _toggleMultiSelectMode();
  }

  /// 删除多条选中的消息
  Future<void> _deleteSelectedMessages() async {
    final selectedMessages = _controller.messages
        .where((m) => _selectedMessageIds.value.contains(m.id))
        .toList();

    if (selectedMessages.isEmpty) return;

    // 显示一次确认对话框
    final confirm = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (ctx) => DSDialog(
            title: '删除消息',
            message: '确定要删除选中的 ${selectedMessages.length} 条消息吗？此操作不可撤销。',
            cancelText: 'agent_chat_cancel'.tr,
            confirmText: 'agent_chat_delete'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () => Navigator.pop(dialogContext, true),
            onCancel: () => Navigator.pop(dialogContext, false),
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {
      for (final message in selectedMessages) {
        await _controller.deleteMessage(message.id);
      }
      if (mounted) {
        toastService.showToast('已删除 ${selectedMessages.length} 条消息');
        _toggleMultiSelectMode();
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('删除失败: $e');
      }
    }
  }

  /// 气泡悬浮操作栏（chat 风格）：按消息类型动态生成按钮
  Widget _buildAgentActionRow(ChatMessage source) {
    final isToolCallMessage =
        source.toolCall != null && source.toolCall!.steps.isNotEmpty;

    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        Widget action(
          DsIconKind icon,
          String tooltip,
          VoidCallback onPressed, {
          Color? iconColor,
        }) => DSIconButton(
          icon: icon,
          size: 32,
          color: theme.surfaceAlt,
          iconColor: iconColor ?? theme.textSub,
          onPressed: onPressed,
          tooltip: tooltip,
        );

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            action(DsIconKind.copy, '复制', () => _copyMessage(source)),
            // 工具调用消息不可编辑
            if (!isToolCallMessage)
              action(
                DsIconKind.edit,
                '编辑',
                () => _showEditMessageDialog(source),
              ),
            if (!source.isUser && _currentAgent != null)
              action(
                DsIconKind.refresh,
                '重新生成',
                () => _controller.regenerateResponse(source.id),
              ),
            if (!source.isUser && isToolCallMessage) ...[
              action(
                DsIconKind.download,
                '保存工具',
                () => _handleSaveTool(source),
              ),
              action(
                DsIconKind.refresh,
                '重新执行工具',
                () => _handleRerunTool(source.id),
              ),
              action(DsIconKind.info, '查看详情', () => _showToolDetail(source)),
            ],
            action(
              DsIconKind.trash,
              '删除',
              () => _showDeleteConfirmation(source.id),
              iconColor: theme.danger,
            ),
          ],
        );
      },
    );
  }

  /// 时间戳行尾部：思考过程入口（仅 AI 消息且有思考内容，含内联 think 标签）
  Widget? _buildThinkingEntry(ChatMessage source) {
    if (source.isUser || source.resolvedThinkingContent == null) {
      return null;
    }
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Pressable(
          onPressed: () => _showThinkingSheet(source),
          semanticLabel: '查看思考过程',
          builder: (context, states) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DsIcon(DsIconKind.bot, size: 12, color: theme.primaryText),
              const SizedBox(width: 4),
              Text(
                '查看思考过程',
                style: DsTypography.caption.copyWith(color: theme.primaryText),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建带日期分隔符的列表项（newest-first，配合 reverse ListView）
  List<dynamic> _buildItemsWithDateSeparators(List<Message> messages) {
    final result = <dynamic>[];
    DateTime? lastDate;

    for (int i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      final messageDate = DateTime(
        message.date.year,
        message.date.month,
        message.date.day,
      );

      // 如果是新的一天，先添加上一天的日期分隔符
      if (lastDate == null || !_isSameDay(lastDate, messageDate)) {
        if (lastDate != null) {
          result.add(lastDate);
        }
        lastDate = messageDate;
      }
      result.add(message);
    }

    // 添加最早一天的日期分隔符
    if (lastDate != null) {
      result.add(lastDate);
    }

    return result;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 构建空状态
  Widget _buildEmptyState() {
    final theme = DSThemeBridge.resolve(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DsIcon(DsIconKind.chat, size: 64, color: theme.textSub),
          const SizedBox(height: 16),
          Text(
            _currentAgent != null ? '开始新的对话' : '请先选择一个Agent',
            style: DsTypography.heading.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 8),
          if (_currentAgent != null)
            Text(
              '当前Agent: ${_currentAgent!.name}',
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
        ],
      ),
    );
  }
}

class _BubbleEntrance extends StatelessWidget {
  final Widget child;
  final bool isNew;
  final bool alignRight;

  const _BubbleEntrance({
    required this.child,
    required this.isNew,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    if (!isNew) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: Transform.scale(
              scale: 0.96 + 0.04 * t,
              alignment: alignRight
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// 会话分隔符（新会话标记），居中胶囊 + 两侧分割线
class _SessionDivider extends StatelessWidget {
  final ChatMessage message;

  const _SessionDivider({required this.message});

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.primary.mixWhite(0.88),
                borderRadius: theme.radii.md,
                border: Border.all(color: theme.primary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DsIcon(DsIconKind.plus, size: 16, color: theme.primaryText),
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
  }
}
