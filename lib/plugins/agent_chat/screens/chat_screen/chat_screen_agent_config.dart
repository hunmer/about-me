part of 'chat_screen.dart';

/// Agent 选择与配置（单/链/工具Agent）及会话设置
extension _ChatScreenAgentConfigExt on _ChatScreenState {
  /// 显示设置对话框
  void _showSettings() {
    int? customContextCount = widget.conversation.contextMessageCount;

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => DSThemeBridge(
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
                    Text(
                      'agent_chat_conversationSettings'.tr,
                      textAlign: TextAlign.center,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                    SizedBox(height: theme.spacing.md),
                    Text(
                      '上下文消息数量',
                      style: DsTypography.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.text,
                      ),
                    ),
                    SizedBox(height: theme.spacing.sm),
                    // 与原实现一致：单选项仅作展示（无切换回调）
                    Row(
                      children: [
                        DSRadio<int?>(
                          value: null,
                          groupValue: null,
                          onChanged: null,
                        ),
                        Expanded(
                          child: Text(
                            'agent_chat_useGlobalSettings'.tr,
                            style: DsTypography.body.copyWith(
                              color: theme.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        DSRadio<int?>(
                          value: -1,
                          groupValue: null,
                          onChanged: null,
                        ),
                        Expanded(
                          child: Text(
                            'agent_chat_custom'.tr,
                            style: DsTypography.body.copyWith(
                              color: theme.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (customContextCount != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: DSSlider(
                                value: (customContextCount! - 1) / 49,
                                onChanged: (value) {
                                  setDialogState(() {
                                    customContextCount =
                                        (value * 49).round() + 1;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '$customContextCount',
                                textAlign: TextAlign.center,
                                style: DsTypography.body.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: theme.spacing.lg),
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
                            onPressed: () async {
                              // 保存设置
                              final updatedConversation = widget.conversation
                                  .copyWith(
                                    contextMessageCount: customContextCount,
                                  );
                              await _controller.conversationService
                                  .updateConversation(updatedConversation);
                              if (mounted) {
                                Navigator.pop(dialogContext);
                                toastService.showToast('Settings saved');
                              }
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
      ),
    );
  }

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

  /// 显示Agent选择器（支持单/链模式选择）
  Future<void> _showAgentSelector() async {
    if (!mounted) return;

    // 检查当前配置状态
    final isCurrentlySingleMode = !_isChainMode && _currentAgent != null;
    final isCurrentlyChainMode =
        _isChainMode && _agentChain != null && _agentChain!.isNotEmpty;

    // 获取当前配置的agent显示文本
    String getCurrentAgentDisplayText() {
      if (isCurrentlySingleMode) {
        return '当前: ${_currentAgent!.name}';
      } else if (isCurrentlyChainMode) {
        final chainLength = _agentChain!.length;
        final agentNames = _agentChain!.map((a) => a.name).join(' → ');
        return '当前 ($chainLength个): $agentNames';
      }
      return '未配置';
    }

    // 显示模式选择对话框
    final mode = await showDSDialog<String>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (ctx) {
            final theme = DSThemeBridge.resolve(ctx);
            return JellyBox(
              radius: theme.radii.xxl,
              padding: EdgeInsets.all(theme.spacing.xl),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '选择配置模式',
                    textAlign: TextAlign.center,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.md),
                  _ModeOption(
                    icon: isCurrentlySingleMode
                        ? DsIconKind.check
                        : DsIconKind.bot,
                    accent: isCurrentlySingleMode ? theme.success : null,
                    title: '单 Agent 模式',
                    subtitle: isCurrentlySingleMode
                        ? '${getCurrentAgentDisplayText()} | 选择一个 Agent 进行对话'
                        : '选择一个 Agent 进行对话',
                    onTap: () => Navigator.pop(dialogContext, 'single'),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  _ModeOption(
                    icon: isCurrentlyChainMode
                        ? DsIconKind.check
                        : DsIconKind.layers,
                    accent: isCurrentlyChainMode ? theme.success : null,
                    title: 'Agent 链模式',
                    subtitle: isCurrentlyChainMode
                        ? '${getCurrentAgentDisplayText()} | 配置多个 Agent 顺序执行'
                        : '配置多个 Agent 顺序执行',
                    onTap: () => Navigator.pop(dialogContext, 'chain'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (mode == null || !mounted) return;

    if (mode == 'single') {
      await _showSingleAgentSelector();
    } else {
      await _showAgentChainConfig();
    }
  }

  /// 显示单 Agent 选择器
  Future<void> _showSingleAgentSelector() async {
    if (!mounted) return;

    final currentAgent = _currentAgent;
    final selectedAgents = currentAgent != null
        ? [
            {'id': currentAgent.id, 'name': currentAgent.name},
          ]
        : <Map<String, String>>[];

    await SmoothBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AgentListDrawer(
        selectedAgents: selectedAgents,
        allowMultipleSelection: false,
        onAgentSelected: (List<Map<String, String>> agents) async {
          if (agents.isEmpty) return;

          final selectedAgentId = agents.first['id'];
          if (selectedAgentId == null) return;

          try {
            await _controller.switchToSingleAgent(selectedAgentId);
            await _loadSuggestedQuestions();

            // 立即更新本地状态并刷新 UI
            if (mounted) {
              // 重新从 controller 同步状态
              _syncAgentStateFromController();
              // 强制刷新 UI
              setState(() {});
              toastService.showToast('已切换到 ${agents.first['name']}');
            }
          } catch (e) {
            if (mounted) {
              toastService.showToast('切换Agent失败: $e');
            }
          }
        },
      ),
    );
  }

  /// 显示 Agent 链配置对话框
  Future<void> _showAgentChainConfig() async {
    if (!mounted) return;

    await showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => AgentChainConfigDialog(
        initialChain: _controller.conversation.agentChain,
        onSave: (chain) async {
          try {
            await _controller.selectAgentChain(chain);

            // 立即更新本地状态并刷新 UI
            if (mounted) {
              // 重新从 controller 同步状态
              _syncAgentStateFromController();
              // 强制刷新 UI
              setState(() {});
              toastService.showToast('Agent 链配置成功');
            }
          } catch (e) {
            if (mounted) {
              toastService.showToast('配置失败: $e');
            }
          }
        },
      ),
    );
  }

  /// 显示工具调用 Agent 配置对话框（工具识别与工具执行两个阶段共用一个 agent）
  Future<void> _showToolAgentsConfig() async {
    if (!mounted) return;

    // 加载已保存的服务商列表
    List<Map<String, dynamic>> providers = [];
    try {
      final openAIPlugin =
          PluginManager.instance.getPlugin('openai') as OpenAIPlugin?;
      if (openAIPlugin != null) {
        final result = await openAIPlugin.useCase.getServiceProviders({});
        if (result.isSuccess && result.dataOrNull != null) {
          providers = result.dataOrNull!;
        }
      }
    } catch (e) {
      debugPrint('加载服务商列表失败: $e');
    }
    if (!mounted) return;

    final initialConfig = _controller.conversation.toolAgentConfig;
    String? selectedProviderId = initialConfig?.providerId;
    String? selectedModelId = initialConfig?.modelId;

    await showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setDialogState) => DSThemeBridge(
                  child: Builder(
                    builder: (ctx) {
                      final theme = DSThemeBridge.resolve(ctx);
                      final models = _getModelsForProvider(selectedProviderId);
                      return JellyBox(
                        radius: theme.radii.xxl,
                        padding: EdgeInsets.all(theme.spacing.xl),
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                DsIcon(
                                  DsIconKind.gear,
                                  color: theme.primaryText,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '工具调用 Agent 配置',
                                  style: DsTypography.title.copyWith(
                                    color: theme.text,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: theme.spacing.md),
                            Text(
                              '为工具调用的两个阶段（工具识别、生成调用代码）配置共用的专用 Agent。未配置时使用默认 prompt 替换当前 agent 的 system prompt。',
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 选择服务商
                            DSSelect<String>(
                              value: selectedProviderId,
                              hint: '请选择服务商',
                              items: providers
                                  .map(
                                    (p) => DSSelectItem<String>(
                                      value: p['id'] as String,
                                      label: p['label'] as String,
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedProviderId = value;
                                  selectedModelId = null;
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // 选择模型
                            if (selectedProviderId != null)
                              DSSelect<String>(
                                value: selectedModelId,
                                hint: '请选择模型',
                                items: models
                                    .map(
                                      (m) => DSSelectItem<String>(
                                        value: m.id,
                                        label: m.name,
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setDialogState(() => selectedModelId = value);
                                },
                              ),
                            SizedBox(height: theme.spacing.lg),
                            Row(
                              children: [
                                if (initialConfig != null) ...[
                                  Expanded(
                                    child: DSButton(
                                      label: '清除配置',
                                      variant: DSButtonVariant.destructive,
                                      onPressed: () {
                                        _saveToolAgentConfig(null);
                                        Navigator.pop(dialogContext);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: DSButton(
                                    label: '取消',
                                    variant: DSButtonVariant.outline,
                                    onPressed:
                                        () => Navigator.pop(dialogContext),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DSButton(
                                    label: '保存',
                                    onPressed: () {
                                      if (selectedProviderId != null &&
                                          selectedModelId != null) {
                                        final model = models.firstWhere(
                                          (m) => m.id == selectedModelId,
                                        );
                                        _saveToolAgentConfig(
                                          ToolAgentConfig(
                                            providerId: selectedProviderId!,
                                            modelId: selectedModelId!,
                                            modelName: model.name,
                                          ),
                                        );
                                        Navigator.pop(dialogContext);
                                      }
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
          ),
    );
  }

  /// 获取指定服务商的所有模型
  List<LLMModel> _getModelsForProvider(String? providerId) {
    if (providerId == null) return [];
    for (final group in llmModelGroups) {
      if (group.id == providerId) {
        return group.models;
      }
    }
    return [];
  }

  /// 保存/清除工具调用专用 Agent 配置
  Future<void> _saveToolAgentConfig(ToolAgentConfig? config) async {
    try {
      await _controller.configureToolAgents(toolAgentConfig: config);
      if (mounted) {
        toastService.showToast('工具 Agent 配置成功');
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('配置失败: $e');
      }
    }
  }

  /// 获取 Agent 显示文本
  String _getAgentDisplayText() {
    if (_isChainMode) {
      final chainLength = _agentChain?.length ?? 0;
      if (chainLength == 0) return '配置 Agent 链';
      return '$chainLength 个 Agent 链';
    } else {
      return _currentAgent?.name ?? 'agent_chat_selectAgent'.tr;
    }
  }

  /// 检查是否有有效的 Agent
  bool _hasValidAgent() {
    if (_isChainMode) {
      return _agentChain != null && _agentChain!.isNotEmpty;
    } else {
      return _currentAgent != null;
    }
  }
}
