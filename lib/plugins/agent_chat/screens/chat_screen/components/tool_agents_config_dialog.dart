import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/openai/models/llm_models.dart';

/// 工具调用 Agent 配置对话框
/// 适用于单 Agent 和 Agent 链模式
class ToolAgentsConfigDialog extends StatefulWidget {
  final ToolAgentConfig? initialToolDetectionConfig;
  final ToolAgentConfig? initialToolExecutionConfig;
  final Function(
    ToolAgentConfig? toolDetectionConfig,
    ToolAgentConfig? toolExecutionConfig,
  )
  onSave;

  const ToolAgentsConfigDialog({
    super.key,
    this.initialToolDetectionConfig,
    this.initialToolExecutionConfig,
    required this.onSave,
  });

  @override
  State<ToolAgentsConfigDialog> createState() => _ToolAgentsConfigDialogState();
}

class _ToolAgentsConfigDialogState extends State<ToolAgentsConfigDialog> {
  bool _isLoading = true;
  ToolAgentConfig? _toolDetectionConfig;
  ToolAgentConfig? _toolExecutionConfig;

  // 实际保存的服务商列表（Map 格式）
  List<Map<String, dynamic>> _savedProviders = [];

  @override
  void initState() {
    super.initState();
    _toolDetectionConfig = widget.initialToolDetectionConfig;
    _toolExecutionConfig = widget.initialToolExecutionConfig;
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      final openAIPlugin =
          PluginManager.instance.getPlugin('openai') as OpenAIPlugin?;
      if (openAIPlugin != null) {
        // 使用 UseCase 获取服务商列表
        final result = await openAIPlugin.useCase.getServiceProviders({});
        if (result.isSuccess && result.dataOrNull != null) {
          setState(() {
            _savedProviders = result.dataOrNull!;
            _isLoading = false;
          });
        } else {
          throw Exception(result.errorOrNull?.message ?? '未知错误');
        }
      }
    } catch (e) {
      print('加载服务商列表失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 获取指定服务商的所有模型
  List<LLMModel> _getModelsForProvider(String providerId) {
    for (final group in llmModelGroups) {
      if (group.id == providerId) {
        return group.models;
      }
    }
    return [];
  }

  /// 获取服务商显示名称
  String _getProviderLabel(String providerId) {
    for (final group in llmModelGroups) {
      if (group.id == providerId) {
        return group.name;
      }
    }
    return providerId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return JellyBox(
      radius: theme.radii.xxl,
      padding: EdgeInsets.all(theme.spacing.xl),
      constraints: const BoxConstraints(maxWidth: 540),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DsIcon(DsIconKind.gear, color: theme.primaryText),
              const SizedBox(width: 8),
              Text(
                '工具调用 Agent 配置',
                style: DsTypography.title.copyWith(color: theme.text),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          if (_isLoading)
            const SizedBox(
              width: 400,
              height: 200,
              child: Center(child: DSThemeBridge(child: DSLoadingDots())),
            )
          else
            SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '配置工具调用的两个阶段使用的专用 Agent。选择服务商和模型后，将使用 ToolService 中预设的 prompt 临时创建 agent。如果未配置，则使用默认 prompt 替换当前 agent 的 system prompt。',
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                  const SizedBox(height: 16),

                  // ========== 工具需求识别配置 ==========
                  _buildAgentConfigSection(
                    context,
                    title: '工具需求识别（第一阶段）',
                    subtitle: '用于识别用户需要使用的工具，返回 needed_tools 列表',
                    config: _toolDetectionConfig,
                    onChanged: (config) {
                      setState(() {
                        _toolDetectionConfig = config;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // ========== 工具执行配置 ==========
                  _buildAgentConfigSection(
                    context,
                    title: '工具执行（第二阶段）',
                    subtitle: '用于生成工具调用的 JavaScript 代码',
                    config: _toolExecutionConfig,
                    onChanged: (config) {
                      setState(() {
                        _toolExecutionConfig = config;
                      });
                    },
                  ),
                ],
              ),
            ),
          SizedBox(height: theme.spacing.lg),
          Row(
            children: [
              Expanded(
                child: DSButton(
                  label: '取消',
                  variant: DSButtonVariant.outline,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DSButton(
                  label: '保存',
                  onPressed: () {
                    widget.onSave(_toolDetectionConfig, _toolExecutionConfig);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建单个 Agent 配置区域
  Widget _buildAgentConfigSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required ToolAgentConfig? config,
    required Function(ToolAgentConfig?) onChanged,
  }) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.textSub.withValues(alpha: 0.3)),
        borderRadius: theme.radii.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DsTypography.heading.copyWith(color: theme.text)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 12),

          // 未配置状态
          if (config == null) ...[
            DSButton(
              label: '配置服务商和模型',
              icon: DsIconKind.plus,
              variant: DSButtonVariant.outline,
              onPressed: () {
                _showAgentConfigDialog(onChanged);
              },
            ),
          ] else ...[
            // 已配置状态
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primary.mixWhite(0.88),
                      borderRadius: theme.radii.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '服务商: ${_getProviderLabel(config.providerId)}',
                          style: DsTypography.body.copyWith(color: theme.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '模型: ${config.modelName ?? config.modelId}',
                          style: DsTypography.body.copyWith(color: theme.text),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Pressable(
                  onPressed: () {
                    _showAgentConfigDialog(onChanged, initialConfig: config);
                  },
                  semanticLabel: '编辑配置',
                  builder:
                      (context, states) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: DsIcon(
                          DsIconKind.edit,
                          size: 20,
                          color: theme.textSub,
                        ),
                      ),
                ),
                Pressable(
                  onPressed: () {
                    onChanged(null);
                  },
                  semanticLabel: '清除配置',
                  builder:
                      (context, states) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: DsIcon(
                          DsIconKind.trash,
                          size: 20,
                          color: theme.danger,
                        ),
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 显示 Agent 配置对话框
  void _showAgentConfigDialog(
    Function(ToolAgentConfig?) onChanged, {
    ToolAgentConfig? initialConfig,
  }) {
    String? selectedProviderId = initialConfig?.providerId;
    String? selectedModelId = initialConfig?.modelId;

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setDialogState) => DSThemeBridge(
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
                              initialConfig == null ? '配置 Agent' : '编辑 Agent',
                              textAlign: TextAlign.center,
                              style: DsTypography.title.copyWith(
                                color: theme.text,
                              ),
                            ),
                            SizedBox(height: theme.spacing.md),

                            // 选择服务商
                            DSSelect<String>(
                              value: selectedProviderId,
                              hint: '请选择服务商',
                              items: [
                                ..._savedProviders.map((provider) {
                                  return DSSelectItem<String>(
                                    value: provider['id'] as String,
                                    label: provider['label'] as String,
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedProviderId = value;
                                  selectedModelId = null; // 重置模型选择
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // 选择模型
                            if (selectedProviderId != null) ...[
                              DSSelect<String>(
                                value: selectedModelId,
                                hint: '请选择模型',
                                items: [
                                  ..._getModelsForProvider(
                                    selectedProviderId!,
                                  ).map((model) {
                                    return DSSelectItem<String>(
                                      value: model.id,
                                      label: model.name,
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedModelId = value;
                                  });
                                },
                              ),
                            ],
                            SizedBox(height: theme.spacing.lg),
                            Row(
                              children: [
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
                                    label: '确定',
                                    onPressed: () {
                                      if (selectedProviderId != null &&
                                          selectedModelId != null) {
                                        final model = _getModelsForProvider(
                                          selectedProviderId!,
                                        ).firstWhere(
                                          (m) => m.id == selectedModelId,
                                        );

                                        onChanged(
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
}
