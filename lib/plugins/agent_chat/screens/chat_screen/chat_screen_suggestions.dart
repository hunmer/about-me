part of 'chat_screen.dart';

/// 猜你想问与已选工具栏
extension _ChatScreenSuggestionsExt on _ChatScreenState {
  /// 加载建议问题
  Future<void> _loadSuggestedQuestions() async {
    // 检查 agent 是否开启了猜你想问功能
    if (_currentAgent == null || !_currentAgent!.enableOpeningQuestions) {
      setState(() {
        _suggestedQuestions = [];
      });
      return;
    }

    // 如果有预设问题,使用预设问题
    if (_currentAgent!.openingQuestions.isNotEmpty) {
      setState(() {
        _suggestedQuestions = List.from(_currentAgent!.openingQuestions);
      });
    } else {
      // 否则使用随机问题
      final questions = await _suggestionsService.getRandomQuestions(count: 5);
      setState(() {
        _suggestedQuestions = questions;
      });
    }
  }

  /// 刷新建议问题（使用 AI 生成）
  Future<void> _refreshSuggestedQuestions() async {
    if (_currentAgent == null) return;

    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      // 使用 AI 生成新问题
      final questions = await _suggestionsService.generateQuestionsWithAI(
        agent: _currentAgent!,
        count: 5,
      );

      setState(() {
        _suggestedQuestions = questions;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSuggestions = false;
      });

      if (mounted) {
        toastService.showToast('生成问题失败: $e');
      }
    }
  }

  /// 构建已选工具栏
  Widget _buildSelectedToolsBar() {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.primary.mixWhite(0.9),
            border: Border(
              bottom: BorderSide(color: theme.primary.withValues(alpha: 0.3)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DsIcon(DsIconKind.gear, size: 16, color: theme.primaryText),
                  const SizedBox(width: 4),
                  Text(
                    '已选工具:',
                    style: DsTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryText,
                    ),
                  ),
                  const Spacer(),
                  DSButton(
                    label: 'agent_chat_clear'.tr,
                    icon: DsIconKind.close,
                    size: DSButtonSize.sm,
                    variant: DSButtonVariant.ghost,
                    onPressed: () async {
                      final confirm = await showDSDialog<bool>(
                        context: context,
                        theme: DSThemeBridge.resolve(context),
                        builder: (dialogContext) => DSThemeBridge(
                          child: Builder(
                            builder: (ctx) => DSDialog(
                              title: 'agent_chat_confirmClear'.tr,
                              message: 'agent_chat_confirmClearTools'.tr,
                              cancelText: 'agent_chat_cancel'.tr,
                              confirmText: 'agent_chat_confirm'.tr,
                              onConfirm: () =>
                                  Navigator.pop(dialogContext, true),
                              onCancel: () =>
                                  Navigator.pop(dialogContext, false),
                            ),
                          ),
                        ),
                      );
                      if (confirm == true) {
                        await _controller.clearSelectedTools();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _controller.selectedTools.map((tool) {
                  return DSChip(
                    label: tool['toolName'] ?? tool['toolId'] ?? '',
                    onDeleted: () async {
                      await _controller.removeToolFromConversation(tool['id']!);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建猜你想问横条
  Widget _buildSuggestedQuestionsBar() {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.surfaceAlt.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: theme.textSub.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          DsIcon(DsIconKind.star, size: 18, color: theme.primaryText),
          const SizedBox(width: 8),
          Text(
            '猜你想问',
            style: DsTypography.caption.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestedQuestions.length,
                itemBuilder: (context, index) {
                  final question = _suggestedQuestions[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: DSChip(
                        label: question,
                        icon: DsIconKind.chat,
                        onSelected: (_) {
                          // 点击问题填入输入框
                          _controller.setInputText(question);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 刷新按钮
          Pressable(
            onPressed: _isLoadingSuggestions
                ? null
                : _refreshSuggestedQuestions,
            semanticLabel: '刷新问题',
            builder: (context, states) => SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: _isLoadingSuggestions
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: DSLoadingDots(size: 5),
                      )
                    : DsIcon(
                        DsIconKind.refresh,
                        size: 20,
                        color: theme.primaryText,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
