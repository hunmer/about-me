import 'package:flutter/material.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/widgets/agent_list_drawer.dart';
import 'package:aboutme/plugins/agent_chat/models/agent_chain_node.dart';
import 'package:aboutme/plugins/agent_chat/models/agent_chain_preset.dart';
import 'package:aboutme/plugins/agent_chat/services/agent_chain_preset_service.dart';

/// Agent 链配置对话框
class AgentChainConfigDialog extends StatefulWidget {
  final List<AgentChainNode>? initialChain;
  final Function(List<AgentChainNode>) onSave;

  const AgentChainConfigDialog({
    super.key,
    this.initialChain,
    required this.onSave,
  });

  @override
  State<AgentChainConfigDialog> createState() => _AgentChainConfigDialogState();
}

class _AgentChainConfigDialogState extends State<AgentChainConfigDialog> {
  late List<AgentChainNode> _chain;
  List<AIAgent> _availableAgents = [];
  bool _isLoading = true;

  /// Agent 链预设服务
  late AgentChainPresetService _presetService;

  @override
  void initState() {
    super.initState();
    _chain = widget.initialChain != null ? List.from(widget.initialChain!) : [];

    // 初始化预设服务
    final storage = PluginManager.instance.storageManager!;
    _presetService = AgentChainPresetService(storage: storage);

    _loadAgents();
  }

  Future<void> _loadAgents() async {
    try {
      final openAIPlugin =
          PluginManager.instance.getPlugin('openai') as OpenAIPlugin?;
      if (openAIPlugin != null) {
        // 加载所有agents (包括临时agents；内置 agent 不出现在可选列表)
        final normalAgents = await openAIPlugin.controller.loadVisibleAgents();
        final temporaryAgents = openAIPlugin.controller.temporaryAgents;
        // 加载extra storage agents
        final extraAgents = await openAIPlugin.controller
            .loadExtraStorageAgents('agent_chain_agents');
        _availableAgents = [
          ...normalAgents,
          ...temporaryAgents,
          ...extraAgents,
        ];
      }
    } catch (e) {
      debugPrint('加载Agent列表失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addNode() {
    if (_availableAgents.isEmpty) return;

    setState(() {
      _chain.add(
        AgentChainNode(
          agentId: _availableAgents.first.id,
          contextMode: AgentContextMode.conversationContext,
          order: _chain.length,
        ),
      );
    });
  }

  void _removeNode(int index) {
    setState(() {
      _chain.removeAt(index);
      // 重新排序
      for (int i = 0; i < _chain.length; i++) {
        _chain[i] = _chain[i].copyWith(order: i);
      }
    });
  }

  void _moveUp(int index) {
    if (index == 0) return;
    setState(() {
      final temp = _chain[index];
      _chain[index] = _chain[index - 1].copyWith(order: index);
      _chain[index - 1] = temp.copyWith(order: index - 1);
    });
  }

  void _moveDown(int index) {
    if (index >= _chain.length - 1) return;
    setState(() {
      final temp = _chain[index];
      _chain[index] = _chain[index + 1].copyWith(order: index);
      _chain[index + 1] = temp.copyWith(order: index + 1);
    });
  }

  String _getContextModeDescription(AgentContextMode mode) {
    switch (mode) {
      case AgentContextMode.conversationContext:
        return '使用会话历史消息作为上下文（遵循上下文消息数量设置）';
      case AgentContextMode.chainContext:
        return '将前面所有 Agent 的输出作为上下文传递';
      case AgentContextMode.previousOnly:
        return '仅使用上一个 Agent 的输出作为输入';
    }
  }

  String _getContextModeLabel(AgentContextMode mode) {
    switch (mode) {
      case AgentContextMode.conversationContext:
        return '会话上下文';
      case AgentContextMode.chainContext:
        return '链式上下文（所有前序输出）';
      case AgentContextMode.previousOnly:
        return '仅上一步输出';
    }
  }

  /// 保存当前链为预设
  Future<void> _saveAsPreset() async {
    if (_chain.isEmpty) {
      toastService.showToast('当前链为空，无法保存');
      return;
    }

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDSDialog<bool>(
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
                    '保存为预设',
                    textAlign: TextAlign.center,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.md),
                  DSInput(
                    controller: nameController,
                    label: '预设名称',
                    hint: '输入预设名称',
                  ),
                  SizedBox(height: theme.spacing.md),
                  DSInput(
                    controller: descriptionController,
                    label: '描述（可选）',
                    hint: '简要描述预设用途',
                    maxLines: 2,
                  ),
                  SizedBox(height: theme.spacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: DSButton(
                          label: '取消',
                          variant: DSButtonVariant.outline,
                          onPressed: () => Navigator.pop(dialogContext, false),
                        ),
                      ),
                      SizedBox(width: theme.spacing.md),
                      Expanded(
                        child: DSButton(
                          label: '保存',
                          onPressed: () {
                            if (nameController.text.trim().isEmpty) {
                              toastService.showToast('请输入预设名称');
                              return;
                            }
                            Navigator.pop(dialogContext, true);
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

    if (result == true && mounted) {
      final name = nameController.text.trim();
      final description = descriptionController.text.trim();

      // 检查名称是否已存在
      if (_presetService.isNameExists(name)) {
        toastService.showToast('预设名称 "$name" 已存在');
        return;
      }

      try {
        final preset = AgentChainPreset(
          name: name,
          description: description.isEmpty ? null : description,
          chain: List.from(_chain),
        );

        await _presetService.savePreset(preset);

        if (mounted) {
          toastService.showToast('预设 "$name" 已保存');
        }
      } catch (e) {
        if (mounted) {
          toastService.showToast('保存失败: $e');
        }
      }
    }
  }

  /// 显示预设列表
  Future<void> _showPresetList() async {
    // 加载预设
    await _presetService.loadPresets();
    final presets = _presetService.presets;

    if (!mounted) return;

    if (presets.isEmpty) {
      toastService.showToast('暂无保存的预设');
      return;
    }

    await showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (ctx) {
            final theme = DSThemeBridge.resolve(ctx);
            return JellyBox(
              radius: theme.radii.xxl,
              padding: EdgeInsets.all(theme.spacing.xl),
              constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '选择预设',
                    textAlign: TextAlign.center,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.md),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: presets.length,
                      itemBuilder: (context, index) {
                        final preset = presets[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: EdgeInsets.all(theme.spacing.md),
                            decoration: BoxDecoration(
                              color: theme.surfaceAlt.withValues(alpha: 0.5),
                              borderRadius: theme.radii.md,
                              border: Border.all(
                                color: theme.textSub.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Pressable(
                                    onPressed: () {
                                      _applyPreset(preset.id);
                                      Navigator.pop(dialogContext);
                                    },
                                    semanticLabel: preset.name,
                                    builder: (context, states) => Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          preset.name,
                                          style: DsTypography.body.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme.text,
                                          ),
                                        ),
                                        if (preset.description != null)
                                          Text(
                                            preset.description!,
                                            style: DsTypography.caption
                                                .copyWith(color: theme.textSub),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${preset.chain.length} 个 Agent',
                                          style: DsTypography.caption.copyWith(
                                            color: theme.textSub,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Pressable(
                                  onPressed: () async {
                                    final confirm = await showDSDialog<bool>(
                                      context: context,
                                      theme: DSThemeBridge.resolve(context),
                                      builder: (confirmContext) => DSThemeBridge(
                                        child: Builder(
                                          builder: (c2) => DSDialog(
                                            title: '确认删除',
                                            message:
                                                '确定要删除预设 "${preset.name}" 吗？',
                                            cancelText: '取消',
                                            confirmText: '删除',
                                            confirmVariant:
                                                DSButtonVariant.destructive,
                                            onConfirm: () => Navigator.pop(
                                              confirmContext,
                                              true,
                                            ),
                                            onCancel: () => Navigator.pop(
                                              confirmContext,
                                              false,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );

                                    if (confirm == true && mounted) {
                                      await _deletePreset(preset.id);
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext); // 关闭预设列表
                                      }
                                    }
                                  },
                                  semanticLabel: '删除预设',
                                  builder: (context, states) => DsIcon(
                                    DsIconKind.trash,
                                    size: 20,
                                    color: theme.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: theme.spacing.md),
                  DSButton(
                    label: '关闭',
                    expand: true,
                    variant: DSButtonVariant.outline,
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

  /// 应用预设
  Future<void> _applyPreset(String presetId) async {
    final preset = _presetService.getPreset(presetId);
    if (preset == null) {
      toastService.showToast('预设不存在');
      return;
    }

    setState(() {
      _chain = List.from(preset.chain);
    });

    toastService.showToast('已应用预设 "${preset.name}"');
  }

  /// 删除预设
  Future<void> _deletePreset(String presetId) async {
    try {
      await _presetService.deletePreset(presetId);

      if (mounted) {
        toastService.showToast('预设已删除');
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('删除失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return JellyBox(
      radius: theme.radii.xxl,
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Agent 链配置',
                style: DsTypography.title.copyWith(color: theme.text),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Pressable(
                    onPressed: _showPresetList,
                    semanticLabel: '加载预设',
                    builder: (context, states) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: DsIcon(
                        DsIconKind.book,
                        size: 20,
                        color: theme.textSub,
                      ),
                    ),
                  ),
                  Pressable(
                    onPressed: _saveAsPreset,
                    semanticLabel: '保存为预设',
                    builder: (context, states) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: DsIcon(
                        DsIconKind.download,
                        size: 20,
                        color: theme.textSub,
                      ),
                    ),
                  ),
                  Pressable(
                    onPressed: () => Navigator.pop(context),
                    semanticLabel: '关闭',
                    builder: (context, states) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: DsIcon(
                        DsIconKind.close,
                        size: 20,
                        color: theme.textSub,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 说明文字
          Text(
            '配置多个 Agent 按顺序执行，每个 Agent 可选择不同的上下文模式',
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 16),

          // Agent 链列表
          Expanded(
            child: _isLoading
                ? const Center(child: DSLoadingDots())
                : _chain.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DsIcon(
                          DsIconKind.layers,
                          size: 48,
                          color: theme.textSub,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无 Agent 节点',
                          style: DsTypography.body.copyWith(
                            color: theme.textSub,
                          ),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: _chain.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _chain.removeAt(oldIndex);
                        _chain.insert(newIndex, item);
                        // 更新 order
                        for (int i = 0; i < _chain.length; i++) {
                          _chain[i] = _chain[i].copyWith(order: i);
                        }
                      });
                    },
                    itemBuilder: (context, index) {
                      final node = _chain[index];

                      return Container(
                        key: ValueKey(index),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: theme.radii.md,
                          border: Border.all(
                            color: theme.textSub.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 节点标题和操作按钮
                            Row(
                              children: [
                                DsIcon(
                                  DsIconKind.drag,
                                  color: theme.textSub.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '步骤 ${index + 1}',
                                  style: DsTypography.heading.copyWith(
                                    color: theme.text,
                                  ),
                                ),
                                const Spacer(),
                                Pressable(
                                  onPressed: index > 0
                                      ? () => _moveUp(index)
                                      : null,
                                  semanticLabel: '上移',
                                  builder: (context, states) => Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: DsIcon(
                                      DsIconKind.chevronUp,
                                      size: 20,
                                      color: theme.textSub,
                                    ),
                                  ),
                                ),
                                Pressable(
                                  onPressed: index < _chain.length - 1
                                      ? () => _moveDown(index)
                                      : null,
                                  semanticLabel: '下移',
                                  builder: (context, states) => Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: DsIcon(
                                      DsIconKind.chevronDown,
                                      size: 20,
                                      color: theme.textSub,
                                    ),
                                  ),
                                ),
                                Pressable(
                                  onPressed: () => _removeNode(index),
                                  semanticLabel: '删除节点',
                                  builder: (context, states) => Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: DsIcon(
                                      DsIconKind.trash,
                                      size: 20,
                                      color: theme.danger,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Agent 选择器
                            Pressable(
                              onPressed: () async {
                                final result =
                                    await SmoothBottomSheet.show<
                                      List<Map<String, String>>
                                    >(
                                      context: context,
                                      builder: (context) => DSThemeBridge(
                                        child: Builder(
                                          builder: (context) => AgentListDrawer(
                                            selectedAgents: [
                                              {
                                                'id': node.agentId,
                                                'name': _availableAgents
                                                    .firstWhere(
                                                      (a) =>
                                                          a.id == node.agentId,
                                                      orElse: () =>
                                                          _availableAgents
                                                              .first,
                                                    )
                                                    .name,
                                              },
                                            ],
                                            onAgentSelected: (agents) {},
                                            allowMultipleSelection: false,
                                            extraStorageKey:
                                                'agent_chain_agents',
                                          ),
                                        ),
                                      ),
                                    );

                                if (result != null && result.isNotEmpty) {
                                  setState(() {
                                    _chain[index] = _chain[index].copyWith(
                                      agentId: result.first['id'],
                                    );
                                    // 重新加载agents以包含可能新增的临时agents
                                    _loadAgents();
                                  });
                                }
                              },
                              semanticLabel: '选择 Agent',
                              builder: (context, states) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.surfaceAlt.withValues(
                                    alpha: 0.5,
                                  ),
                                  borderRadius: theme.radii.sm,
                                  border: Border.all(
                                    color: theme.textSub.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Agent',
                                            style: DsTypography.caption
                                                .copyWith(color: theme.textSub),
                                          ),
                                          Text(
                                            _availableAgents
                                                .firstWhere(
                                                  (a) => a.id == node.agentId,
                                                  orElse: () =>
                                                      _availableAgents.first,
                                                )
                                                .name,
                                            style: DsTypography.body.copyWith(
                                              color: theme.text,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DsIcon(
                                      DsIconKind.chevronDown,
                                      color: theme.primaryText,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 上下文模式选择器
                            DSSelect<AgentContextMode>(
                              value: node.contextMode,
                              items: AgentContextMode.values.map((mode) {
                                return DSSelectItem(
                                  value: mode,
                                  label: _getContextModeLabel(mode),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _chain[index] = _chain[index].copyWith(
                                      contextMode: value,
                                    );
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 8),

                            // 上下文模式说明
                            Text(
                              _getContextModeDescription(node.contextMode),
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 16),

          // 底部按钮
          Row(
            children: [
              DSButton(
                label: '添加 Agent',
                icon: DsIconKind.plus,
                onPressed: _addNode,
              ),
              const Spacer(),
              DSButton(
                label: '取消',
                variant: DSButtonVariant.ghost,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              DSButton(
                label: '保存',
                onPressed: _chain.isEmpty
                    ? null
                    : () {
                        widget.onSave(_chain);
                        Navigator.pop(context);
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
