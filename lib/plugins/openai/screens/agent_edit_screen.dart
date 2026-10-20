import 'dart:io';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/clipboard_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/widgets/form_fields/index.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/models/api_format.dart';
import 'package:agentlib/agent_slots.dart';
import 'package:aboutme/plugins/openai/models/service_provider.dart';
import 'package:aboutme/plugins/openai/models/llm_models.dart';
import 'package:aboutme/plugins/openai/models/prompt_preset.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/openai/moments/screens/agent_assets_screen.dart';
import 'package:aboutme/plugins/openai/controllers/provider_controller.dart';
import 'package:aboutme/plugins/openai/services/test_service.dart';
import 'package:aboutme/plugins/openai/services/soul_forge_service.dart';
import 'package:aboutme/plugins/openai/services/chat_assistant_service.dart';
import 'package:aboutme/plugins/openai/services/prompt_preset_service.dart';
import 'package:aboutme/plugins/openai/services/agentlib_resource_service.dart';
import 'package:aboutme/plugins/openai/widgets/agent_resource_selector.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/widgets/aliveness_settings_section.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/services/agent_file_space_service.dart';
import 'package:aboutme/widgets/file_management_screen.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'model_search_screen.dart';

// ServiceProvider 模型已包含 apiFormat 字段

class AgentEditScreen extends StatefulWidget {
  final AIAgent? agent;
  final bool isFromMarketplace; // 是否来自商场
  final String? extraStorageKey; // 如果提供,保存到extra storage;否则保存到临时agents
  final Future<AIAgent?> Function(AIAgent agent)?
  onSave; // 保存回调，如果不为null则调用回调而不保存到controller
  final bool autoOpenSoulForge; // 进入页面后自动弹出修改人设（智能创建）弹层

  const AgentEditScreen({
    super.key,
    this.agent,
    this.isFromMarketplace = false,
    this.extraStorageKey,
    this.onSave,
    this.autoOpenSoulForge = false,
  });

  @override
  State<AgentEditScreen> createState() => _AgentEditScreenState();

  static Route<T> route<T>(
    BuildContext context, {
    AIAgent? agent,
    bool isFromMarketplace = false,
  }) {
    return NavigationHelper.createRoute(
      AgentEditScreen(agent: agent, isFromMarketplace: isFromMarketplace),
    );
  }
}

class _AgentEditScreenState extends State<AgentEditScreen> {
  // FormBuilderWrapper key
  final _formKey = GlobalKey<FormBuilderState>();

  // 服务商相关状态（需要特殊处理）
  List<ServiceProvider> _providers = [];
  String _selectedProviderId = '';

  // 预设相关（用于下拉选项）
  final PromptPresetService _presetService = PromptPresetService();
  List<PromptPreset> _presets = [];
  List<AgentResourceItem> _selectedSkills = [];
  List<AgentResourceItem> _selectedMcpServers = [];
  AlivenessConfig _alivenessConfig = const AlivenessConfig();

  /// 当前标签页：0 基础 / 1 活人感 / 2 素材库 / 3 文件管理
  int _tabIndex = 0;

  /// 文件管理 Tab 的根目录（克隆后随新 id 重新加载）
  Directory? _agentFileDir;

  /// 克隆后当前页面切换为编辑副本（不再退出页面）
  AIAgent? _clonedAgent;

  /// 页面当前编辑的对象：克隆后为副本，否则为传入的 agent
  AIAgent? get _editingAgent => _clonedAgent ?? widget.agent;

  @override
  void initState() {
    super.initState();
    _loadProviders();
    _loadPresets();
    if (widget.agent != null) {
      _selectedProviderId = widget.agent!.serviceProviderId;
      _selectedSkills = List.of(widget.agent!.resourceSlots.skills);
      _selectedMcpServers = List.of(widget.agent!.resourceSlots.mcpServers);
      _alivenessConfig =
          widget.agent!.alivenessConfig ?? const AlivenessConfig();
    }
    _loadAgentFileDir();
    if (widget.autoOpenSoulForge) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSmartSoulSheet();
      });
    }
  }

  /// 获取服务商默认颜色
  Color _getColorForServiceProvider(String providerId) {
    switch (providerId) {
      case 'openai':
        return Colors.green;
      case 'azure':
        return Colors.blue;
      case 'ollama':
        return Colors.orange;
      case 'deepseek':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _loadPresets() async {
    _presets = await _presetService.loadPresets();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadProviders() async {
    try {
      final providerController = ProviderController();
      _providers = await providerController.getProviders();

      if (_providers.isNotEmpty) {
        if (_selectedProviderId.isEmpty) {
          // 新建智能体：优先用引导配置的默认厂商，并预填连接配置
          final defaultId =
              OpenAIPlugin.instance.settings['defaultProviderId'] as String?;
          final provider = _providers.firstWhere(
            (p) => p.id == defaultId,
            orElse: () => _providers.first,
          );
          _selectedProviderId = provider.id;
          _patchFormWithProvider(provider);
        }
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ToastService.instance.showToast(
          '${'openai_loadProvidersError'.tr}: $e',
        );
      }
    }
  }

  /// 表单尚未构建时延迟到首帧后填充
  void _patchFormWithProvider(ServiceProvider provider) {
    void apply() => _updateFormWithProvider(provider, silent: true);
    if (_formKey.currentState != null) {
      apply();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) apply();
      });
    }
  }

  String _formatHeaders(Map<String, String> headers) {
    return headers.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  Map<String, String> _parseHeaders(String headersText) {
    final Map<String, String> result = {};
    final lines = headersText.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      final colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        final key = line.substring(0, colonIndex).trim();
        final value = line.substring(colonIndex + 1).trim();
        if (key.isNotEmpty) {
          result[key] = value;
        }
      }
    }

    return result;
  }

  Future<void> _saveAgent() async {
    if (_formKey.currentState == null ||
        !_formKey.currentState!.saveAndValidate()) {
      return;
    }

    final values = _formKey.currentState!.value;
    final resourceSlots = AgentResourceSlots(
      skills: _selectedSkills,
      mcpServers: _selectedMcpServers,
    );

    // 从 iconAvatarRow 字段获取图标和头像
    final iconAvatarData = values['iconAvatar'] as Map<String, dynamic>?;

    // 从 promptEditor 字段获取提示词
    final prompts = values['promptEditor'] as List<dynamic>? ?? [];
    // 构建完整的 messages 数组（包含 system 类型）
    final allMessages = <Prompt>[];
    String systemPrompt = '';

    for (final p in prompts) {
      if (p is Map<String, dynamic>) {
        final prompt = Prompt.fromJson(p);
        if (prompt.type == 'system') {
          systemPrompt = prompt.content;
        }
        allMessages.add(prompt);
      }
    }

    // 如果没有 system 类型的消息但有 systemPrompt，添加它
    if (systemPrompt.isNotEmpty &&
        !allMessages.any((m) => m.type == 'system')) {
      allMessages.insert(0, Prompt(type: 'system', content: systemPrompt));
    }

    final agent = AIAgent(
      id: _editingAgent?.id ?? const Uuid().v4(),
      version: _editingAgent?.version,
      name: values['name'] as String? ?? '',
      description: values['description'] as String? ?? '',
      serviceProviderId: _selectedProviderId,
      baseUrl: values['baseUrl'] as String? ?? '',
      headers: _parseHeaders(values['headers'] as String? ?? ''),
      model: values['model'] as String? ?? 'gpt-3.5-turbo',
      tags: (values['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: _editingAgent?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      temperature: (double.tryParse('${values['temperature']}') ?? 0.7).clamp(
        0.0,
        2.0,
      ),
      icon: iconAvatarData?['icon'] as IconData?,
      iconColor: iconAvatarData?['iconColor'] as Color?,
      avatarUrl: iconAvatarData?['avatarUrl'] as String?,
      enableFunctionCalling: values['enableFunctionCalling'] as bool? ?? false,
      promptPresetId: values['promptPresetId'] as String?,
      enableOpeningQuestions:
          values['enableOpeningQuestions'] as bool? ?? false,
      openingQuestions:
          (values['openingQuestions'] as List<dynamic>?)?.cast<String>() ?? [],
      messages: allMessages.isNotEmpty ? allMessages : null,
      apiFormat: values['apiFormat'] as String? ?? 'openai',
      resourceSlots: resourceSlots,
      alivenessConfig: _alivenessConfig,
    );

    try {
      // 如果提供了 onSave 回调，调用它并返回 agent
      if (widget.onSave != null) {
        final resultAgent = await widget.onSave!(agent);
        if (mounted) {
          // 回调返回的 agent（可能是处理后的版本）
          final finalAgent = resultAgent ?? agent;
          // 显示成功提示
          ToastService.instance.showToast('保存成功');
          // 返回配置
          Navigator.of(context).pop(finalAgent);
        }
        return;
      }

      // 否则按原有逻辑保存到 controller
      final plugin = PluginManager.instance.getPlugin('openai') as OpenAIPlugin;
      final controller = plugin.controller;

      // 根据 extraStorageKey 的值决定保存位置
      if (widget.extraStorageKey != null) {
        // 保存到 extra storage
        await controller.saveAgentToExtraStorage(
          agent,
          widget.extraStorageKey!,
        );
      } else if (widget.agent == null) {
        // 新建 agent，添加到正式 agents 列表
        await controller.addAgent(agent);
      } else if (widget.isFromMarketplace && _clonedAgent == null) {
        // 从商场安装，添加到正式agents列表（已克隆过的走更新）
        await controller.addAgent(agent);
      } else {
        // 编辑现有 Agent（含克隆出的副本）
        await controller.updateAgent(agent);
      }

      if (mounted) {
        // 显示成功提示
        ToastService.instance.showToast(
          widget.isFromMarketplace
              ? '安装成功'
              : (_editingAgent == null ? '创建成功' : '保存成功'),
        );
        // 返回true表示保存成功
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ToastService.instance.showToast('${'openai_errorSavingAgent'.tr}: $e');
      }
    }
  }

  Future<void> _selectResources({required bool skills}) async {
    final global = skills
        ? AgentLibResourceService.globalSlots.skills
        : AgentLibResourceService.globalSlots.mcpServers;
    final existing = skills ? _selectedSkills : _selectedMcpServers;
    final resources = [
      ...global,
      ...existing.where((item) => !global.any((entry) => entry.id == item.id)),
    ];
    final selected = await showAgentResourceSelector(
      context: context,
      title: skills ? '选择 Skills' : '选择 MCP Servers',
      resources: resources,
      selected: existing,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (skills) {
        _selectedSkills = selected;
      } else {
        _selectedMcpServers = selected;
      }
    });
  }

  Widget _buildResourceSelector({required bool skills}) {
    final selected = skills ? _selectedSkills : _selectedMcpServers;
    return DSListItem(
      leading: DsIcon(skills ? DsIconKind.layers : DsIconKind.block, size: 22),
      title: skills ? 'AgentLib Skills' : 'AgentLib MCP Servers',
      subtitle: selected.isEmpty
          ? '未选择'
          : selected.map((item) => item.displayName).join('、'),
      showChevron: true,
      onTap: () => _selectResources(skills: skills),
    );
  }

  Future<void> _deleteAgent() async {
    // 确认删除对话框
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (dialogContext) => DSDialog(
            title: 'openai_deleteAgentConfirm'.tr,
            message: 'openai_deleteAgentMessage'.tr,
            confirmText: 'openai_delete'.tr,
            cancelText: 'openai_cancel'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () => Navigator.of(dialogContext).pop(true),
            onCancel: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
      ),
    );

    if (confirmed != true || _editingAgent == null) return;

    try {
      final plugin = PluginManager.instance.getPlugin('openai') as OpenAIPlugin;
      final controller = plugin.controller;
      await controller.deleteAgent(_editingAgent!.id);
      if (mounted) {
        ToastService.instance.showToast('openai_agentDeleted'.tr);
        // 返回true表示删除成功
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ToastService.instance.showToast('${'openai_deleteFailed'.tr}: $e');
      }
    }
  }

  Future<void> _shareAgent() async {
    final current = _editingAgent;
    if (current == null) return;

    final agentJson = current.toJson();
    final hasHeaders = current.headers.isNotEmpty;

    // 如果有 headers，询问用户是否包含
    if (hasHeaders) {
      // DSDialog 只支持双按钮,这里用三按钮的果冻对话框
      final choice = await showDSDialog<String>(
        context: context,
        theme: DSThemeBridge.resolve(context),
        builder: (dialogContext) => DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return JellyBox(
                radius: theme.radii.xxl,
                padding: EdgeInsets.all(theme.spacing.xl),
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'openai_shareAgent'.tr,
                      textAlign: TextAlign.center,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                    SizedBox(height: theme.spacing.sm),
                    Text(
                      'openai_shareHeadersWarning'.tr,
                      textAlign: TextAlign.center,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                    SizedBox(height: theme.spacing.lg),
                    DSButton(
                      label: 'openai_removeHeaders'.tr,
                      onPressed: () =>
                          Navigator.of(dialogContext).pop('remove'),
                    ),
                    SizedBox(height: theme.spacing.sm),
                    DSButton(
                      label: 'openai_keepHeaders'.tr,
                      onPressed: () => Navigator.of(dialogContext).pop('keep'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      if (choice == 'cancel' || choice == null) return;
      if (choice == 'remove') {
        agentJson.remove('headers');
      }
    }

    // 使用 ClipboardService 复制
    final success = await ClipboardService.instance.copyToClipboard(
      method: 'openai_agent_import',
      args: agentJson,
    );

    if (success) {
      Toast.success('openai_agentCopied'.tr);
    } else {
      Toast.error('openai_copyFailed'.tr);
    }
  }

  Future<void> _cloneAgent() async {
    if (_editingAgent == null || _formKey.currentState == null) return;

    // 先触发表单保存和验证，确保获取当前表单的最新值
    if (!_formKey.currentState!.saveAndValidate()) {
      // 表单验证失败，不进行克隆
      return;
    }

    final values = _formKey.currentState!.value;

    // 从 iconAvatarRow 字段获取图标和头像
    final iconAvatarData = values['iconAvatar'] as Map<String, dynamic>?;

    // 从 promptEditor 字段获取提示词
    final prompts = values['promptEditor'] as List<dynamic>? ?? [];
    // 构建完整的 messages 数组（包含 system 类型）
    final allMessages = <Prompt>[];
    String systemPrompt = '';

    for (final p in prompts) {
      if (p is Map<String, dynamic>) {
        final prompt = Prompt.fromJson(p);
        if (prompt.type == 'system') {
          systemPrompt = prompt.content;
        }
        allMessages.add(prompt);
      }
    }

    // 如果没有 system 类型的消息但有 systemPrompt，添加它
    if (systemPrompt.isNotEmpty &&
        !allMessages.any((m) => m.type == 'system')) {
      allMessages.insert(0, Prompt(type: 'system', content: systemPrompt));
    }

    // 创建一个新的智能体，复制当前智能体的所有属性，但生成新ID并更新名称
    final clonedAgent = AIAgent(
      id: const Uuid().v4(),
      version: _editingAgent?.version,
      name: '${values['name'] as String? ?? ''} (复制)',
      description: values['description'] as String? ?? '',
      serviceProviderId: _selectedProviderId,
      baseUrl: values['baseUrl'] as String? ?? '',
      headers: _parseHeaders(values['headers'] as String? ?? ''),
      model: values['model'] as String? ?? 'gpt-3.5-turbo',
      tags: (values['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      icon: iconAvatarData?['icon'] as IconData?,
      iconColor: iconAvatarData?['iconColor'] as Color?,
      avatarUrl: iconAvatarData?['avatarUrl'] as String?,
      enableFunctionCalling: values['enableFunctionCalling'] as bool? ?? false,
      promptPresetId: values['promptPresetId'] as String?,
      enableOpeningQuestions:
          values['enableOpeningQuestions'] as bool? ?? false,
      openingQuestions:
          (values['openingQuestions'] as List<dynamic>?)?.cast<String>() ?? [],
      messages: allMessages.isNotEmpty ? allMessages : null,
      apiFormat: values['apiFormat'] as String? ?? 'openai',
      resourceSlots: AgentResourceSlots(
        skills: _selectedSkills,
        mcpServers: _selectedMcpServers,
      ),
      alivenessConfig: _alivenessConfig,
    );

    try {
      final plugin = PluginManager.instance.getPlugin('openai') as OpenAIPlugin;
      final controller = plugin.controller;
      await controller.addAgent(clonedAgent);
      if (mounted) {
        ToastService.instance.showToast('openai_agentCloned'.tr);
        // 不退出页面：当前表单切换为编辑新副本（key 变化强制重建表单）
        setState(() {
          _clonedAgent = clonedAgent;
          _agentFileDir = null;
        });
        _loadAgentFileDir();
      }
    } catch (e) {
      if (mounted) {
        ToastService.instance.showToast('${'openai_cloneFailed'.tr}: $e');
      }
    }
  }

  /// 更多菜单：智能创建/优化、分享、克隆、删除（原 AppBar 上的零散按钮）
  Widget _buildMoreMenu(AppThemeData theme) {
    return DSPopover(
      width: 200,
      contentBuilder: (context, close) {
        final menuTheme = DSThemeBridge.resolve(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AgentMenuRow(
              icon: DsIcon(DsIconKind.star, size: 20, color: menuTheme.primary),
              label: 'openai_editPersona'.tr,
              theme: menuTheme,
              onTap: () {
                close();
                _showSmartSoulSheet();
              },
            ),
            // 只有在非回调模式下才提供分享、克隆、删除
            if (widget.onSave == null && _editingAgent != null) ...[
              _AgentMenuRow(
                icon: DsIcon(
                  DsIconKind.share,
                  size: 20,
                  color: menuTheme.primary,
                ),
                label: 'openai_shareAgent'.tr,
                theme: menuTheme,
                onTap: () {
                  close();
                  _shareAgent();
                },
              ),
              _AgentMenuRow(
                icon: DsIcon(
                  DsIconKind.copy,
                  size: 20,
                  color: menuTheme.primary,
                ),
                label: 'openai_cloneAgent'.tr,
                theme: menuTheme,
                onTap: () {
                  close();
                  _cloneAgent();
                },
              ),
              // 内置 agent 不可删除
              if (!SoulForgeService.isBuiltinAgent(_editingAgent!.id) &&
                  !ChatAssistantService.isBuiltinAgent(_editingAgent!.id))
                _AgentMenuRow(
                  icon: DsIcon(
                    DsIconKind.trash,
                    size: 20,
                    color: menuTheme.danger,
                  ),
                  label: 'openai_deleteAgent'.tr,
                  theme: menuTheme,
                  danger: true,
                  onTap: () {
                    close();
                    _deleteAgent();
                  },
                ),
            ],
          ],
        );
      },
      child: DSIconButton(
        icon: DsIconKind.dots,
        size: 38,
        color: theme.surface,
        iconColor: theme.text,
        tooltip: 'openai_more'.tr,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold 属结构性组件,刻意保留 Material;表单基于共享 FormBuilderWrapper(本轮保留 Material)
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            backgroundColor: dsScaffoldBackground(theme),
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 轻量手绘顶栏：保存 + 更多菜单（design.md §2.1）
                  DSLightHeader(
                    title: _editingAgent == null
                        ? 'openai_createAgent'.tr
                        : 'openai_editAgent'.tr,
                    trailingWidth: 84,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DSIconButton(
                          icon: widget.isFromMarketplace
                              ? DsIconKind.download
                              : DsIconKind.check,
                          size: 38,
                          color: theme.surface,
                          iconColor: theme.text,
                          onPressed: _saveAgent,
                          tooltip: widget.isFromMarketplace
                              ? 'openai_install'.tr
                              : 'openai_save'.tr,
                        ),
                        const SizedBox(width: 8),
                        _buildMoreMenu(theme),
                      ],
                    ),
                  ),
                  // 手绘标签页（design.md §9）：基础 / 活人感 / 素材库 / 文件管理
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DSTabs(
                      labels: [
                        'openai_tabBasic'.tr,
                        'openai_tabAliveness'.tr,
                        'openai_tabAssets'.tr,
                        'openai_tabFiles'.tr,
                      ],
                      selected: _tabIndex,
                      onChanged: (i) => setState(() => _tabIndex = i),
                    ),
                  ),
                  Expanded(
                    child: FormBuilderWrapper(
                      // 克隆后 _editingAgent.id 变化，强制重建表单以应用副本数据
                      key: ValueKey('agent_form_${_editingAgent?.id ?? 'new'}'),
                      formKey: _formKey,
                      // Tab 内容为滚动列表，需撑满剩余高度
                      expandContent: true,
                      buttonBuilder: (context, onSubmit, onReset) {
                        return const SizedBox.shrink();
                      },
                      config: FormConfig(
                        showSubmitButton: false,
                        showResetButton: false,
                        fieldSpacing: 16,
                        fields: [..._basicFieldConfigs(), ..._alivenessFieldConfigs()],
                        onSubmit: (values) {
                          // 由 _saveAgent 处理
                        },
                      ),
                      // IndexedStack 让四个 Tab 内容常驻：字段不卸载，切换 Tab 不丢表单值
                      contentBuilder: (context, fields) {
                        final basicCount = _basicFieldConfigs().length;
                        final basicWidgets = fields.sublist(0, basicCount);
                        final alivenessWidgets = fields.sublist(basicCount);
                        return IndexedStack(
                          index: _tabIndex,
                          children: [
                            _buildBasicTab(basicWidgets),
                            _buildAlivenessTab(alivenessWidgets),
                            _buildAssetsTab(),
                            _buildFilesTab(),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DSThemeBridge(
                      child: Builder(
                        builder: (context) {
                          return DSButton(
                            label: 'openai_testAgent'.tr,
                            expand: true,
                            onPressed: _testAgent,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ========== 表单字段按 Tab 分组 ==========

  /// 基础 Tab 字段：身份信息 + 连接配置
  /// （必填字段相对顺序与拆分前一致，验证提示行为不变）
  List<FormFieldConfig> _basicFieldConfigs() {
    return [
      // 图标头像行
      FormFieldConfig(
        name: 'iconAvatar',
        type: FormFieldType.iconAvatarRow,
        initialValue: {
          'icon': _editingAgent?.icon,
          'iconColor':
              _editingAgent?.iconColor ??
              _getColorForServiceProvider(_selectedProviderId),
          'avatarUrl': _editingAgent?.avatarUrl,
        },
        extra: {'avatarSaveDirectory': 'openai/agent_avatars'},
      ),
      // 名称
      FormFieldConfig(
        name: 'name',
        type: FormFieldType.text,
        labelText: 'openai_agentName'.tr,
        hintText: 'openai_enterAgentName'.tr,
        initialValue: _editingAgent?.name ?? '',
        required: true,
        validationMessage: 'openai_pleaseEnterName'.tr,
      ),
      // 服务商选择 - 使用自定义渲染处理特殊逻辑
      FormFieldConfig(
        name: 'serviceProvider',
        type: FormFieldType.select,
        labelText: 'openai_serviceProvider'.tr,
        initialValue:
            _providers.any((p) => p.id == _selectedProviderId)
                ? _selectedProviderId
                : (_providers.isNotEmpty ? _providers.first.id : null),
        required: true,
        items: _providers
            .map((p) => DropdownMenuItem(value: p.id, child: Text(p.label)))
            .toList(),
        onChanged: (value) {
          if (value != null) {
            final provider = _providers.firstWhere((p) => p.id == value);
            setState(() => _selectedProviderId = value);
            // 服务商切换时的特殊逻辑
            _handleProviderChange(provider);
          }
        },
      ),
      // API 格式选择
      FormFieldConfig(
        name: 'apiFormat',
        type: FormFieldType.select,
        labelText: 'API 格式',
        hintText: '选择 API 格式',
        initialValue: _editingAgent?.apiFormat ?? 'openai',
        required: true,
        items: ApiFormat.values
            .map(
              (format) => DropdownMenuItem(
                value: format.value,
                child: Text(format.label),
              ),
            )
            .toList(),
      ),
      // 描述
      FormFieldConfig(
        name: 'description',
        type: FormFieldType.textArea,
        labelText: 'openai_description'.tr,
        hintText: 'openai_enterDescription'.tr,
        initialValue: _editingAgent?.description ?? '',
        required: true,
        validationMessage: 'openai_pleaseEnterDescription'.tr,
        extra: {'minLines': 3, 'maxLines': 3},
      ),
      // BaseUrl
      FormFieldConfig(
        name: 'baseUrl',
        type: FormFieldType.text,
        labelText: 'openai_baseUrl'.tr,
        hintText: 'openai_enterBaseUrl'.tr,
        initialValue: _editingAgent?.baseUrl ?? '',
        required: true,
        validationMessage: 'openai_pleaseEnterBaseUrl'.tr,
      ),
      // 模型（带搜索按钮）
      FormFieldConfig(
        name: 'model',
        type: FormFieldType.text,
        labelText: 'openai_model'.tr,
        hintText: 'openai_enterModel'.tr,
        initialValue: _editingAgent?.model ?? '',
        suffixButtons: [
          InputGroupButton(
            icon: Icons.search,
            tooltip: 'openai_searchModel'.tr,
            onPressed: () => _selectModel(),
          ),
        ],
      ),
      // Headers
      FormFieldConfig(
        name: 'headers',
        type: FormFieldType.textArea,
        labelText: 'openai_headers'.tr,
        hintText: 'openai_enterHeaders'.tr,
        initialValue: _formatHeaders(_editingAgent?.headers ?? {}),
        extra: {'minLines': 3, 'maxLines': 3},
      ),
      // 标签
      FormFieldConfig(
        name: 'tags',
        type: FormFieldType.tags,
        initialTags: _editingAgent?.tags ?? [],
      ),
      // 启用函数调用
      FormFieldConfig(
        name: 'enableFunctionCalling',
        type: FormFieldType.switchField,
        labelText: 'openai_enablePluginFunctionCalls'.tr,
        hintText: 'openai_allowAICallPluginFunctions'.tr,
        initialValue: _editingAgent?.enableFunctionCalling ?? false,
      ),
    ];
  }

  /// 活人感 Tab 字段：人设与拟人交互
  List<FormFieldConfig> _alivenessFieldConfigs() {
    return [
      // Prompt 预设选择
      FormFieldConfig(
        name: 'promptPresetId',
        type: FormFieldType.select,
        labelText: 'openai_promptPreset'.tr,
        hintText: 'openai_selectPromptPreset'.tr,
        initialValue: _editingAgent?.promptPresetId,
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text('openai_noPreset'.tr),
          ),
          ..._presets.map(
            (preset) => DropdownMenuItem<String>(
              value: preset.id,
              child: Text(preset.name),
            ),
          ),
        ],
      ),
      // 提示词编辑器
      FormFieldConfig(
        name: 'promptEditor',
        type: FormFieldType.promptEditor,
        initialValue:
            _editingAgent?.messages
                ?.map((p) => p.toJson())
                .toList() as List<dynamic>? ?? [],
      ),
      FormFieldConfig(
        name: 'temperature',
        type: FormFieldType.number,
        labelText: '生成温度（0-2）',
        hintText: '0.7（越高越随机，角色扮演建议 0.7-0.9）',
        initialValue: _editingAgent?.temperature ?? 0.7,
      ),
      // 启用开场白问题
      FormFieldConfig(
        name: 'enableOpeningQuestions',
        type: FormFieldType.switchField,
        labelText: 'openai_enableGuessWhatYouWantToAsk'.tr,
        hintText: 'openai_showPresetOpeningQuestions'.tr,
        initialValue: _editingAgent?.enableOpeningQuestions ?? false,
      ),
      // 开场白问题列表（条件显示）
      FormFieldConfig(
        name: 'openingQuestions',
        type: FormFieldType.listAdd,
        initialValue: _editingAgent?.openingQuestions ?? [],
        extra: {'initialItems': _editingAgent?.openingQuestions ?? []},
        visible: (values) => values['enableOpeningQuestions'] == true,
      ),
    ];
  }

  // ========== Tab 内容 ==========

  /// Tab 内容滚动容器
  Widget _tabList(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(16), children: children);

  /// 字段间补 16 间距（与原 fieldSpacing 一致）
  List<Widget> _spaced(List<Widget> widgets) => [
    for (var i = 0; i < widgets.length; i++) ...[
      if (i > 0) const SizedBox(height: 16),
      widgets[i],
    ],
  ];

  /// 基础 Tab：表单字段 + Skills / MCP 资源选择
  Widget _buildBasicTab(List<Widget> fieldWidgets) => _tabList([
    ..._spaced(fieldWidgets),
    const SizedBox(height: 16),
    _buildResourceSelector(skills: true),
    const SizedBox(height: 8),
    _buildResourceSelector(skills: false),
  ]);

  /// 活人感 Tab：人设字段 + 活人感增强设置（卡片自带边距）
  Widget _buildAlivenessTab(List<Widget> fieldWidgets) => _tabList([
    ..._spaced(fieldWidgets),
    const SizedBox(height: 8),
    AlivenessSettingsSection(
      config: _alivenessConfig,
      agentId: _editingAgent?.id,
      agentName: _editingAgent?.name ?? '',
      onChanged: (c) => setState(() => _alivenessConfig = c),
    ),
  ]);

  /// 素材库 Tab：内嵌资产管理（未保存的智能体提示先保存）
  Widget _buildAssetsTab() {
    final agent = _editingAgent;
    if (agent?.id == null) {
      return Center(
        child: DSEmptyState(
          icon: DsIconKind.photoLibrary,
          title: 'openai_assetsNeedSave'.tr,
        ),
      );
    }
    return AgentAssetsScreen(
      agentId: agent!.id,
      agentName: agent.name,
      embedded: true,
    );
  }

  /// 文件管理 Tab：内嵌 Agent 独立文件空间（目录异步加载）
  Widget _buildFilesTab() {
    if (_editingAgent?.id == null) {
      return Center(
        child: DSEmptyState(
          icon: DsIconKind.folder,
          title: 'openai_filesNeedSave'.tr,
        ),
      );
    }
    final dir = _agentFileDir;
    if (dir == null) {
      return const Center(child: DSLoadingDots());
    }
    return FileManagementScreen(rootDirectory: dir, embedded: true);
  }

  /// 解析当前编辑对象的独立文件空间目录
  void _loadAgentFileDir() {
    final id = _editingAgent?.id;
    if (id == null) return;
    AgentFileSpaceService.instance.directoryForAgent(id).then((dir) {
      if (mounted) setState(() => _agentFileDir = dir);
    });
  }

  // 处理服务商切换
  void _handleProviderChange(ServiceProvider provider) {
    // 如果是编辑现有智能体（含克隆出的副本），先询问用户是否要更新配置
    if (_editingAgent != null) {
      showDSDialog(
        context: context,
        theme: DSThemeBridge.resolve(context),
        builder: (dialogContext) => DSThemeBridge(
          child: Builder(
            builder: (dialogContext) => DSDialog(
              title: 'openai_updateConfig'.tr,
              message: 'openai_updateConfigConfirm'.tr,
              confirmText: 'openai_useDefaultConfig'.tr,
              cancelText: 'openai_keepCurrentConfig'.tr,
              onCancel: () {
                Navigator.of(dialogContext).pop();
                // 保留当前配置，不更新
              },
              onConfirm: () {
                Navigator.of(dialogContext).pop();
                // 更新为服务商默认配置
                _updateFormWithProvider(provider);
              },
            ),
          ),
        ),
      );
    } else {
      // 新建智能体，直接使用服务商默认配置
      _updateFormWithProvider(provider);
    }
  }

  // 使用服务商配置更新表单
  void _updateFormWithProvider(
    ServiceProvider provider, {
    bool silent = false,
  }) {
    if (_formKey.currentState != null) {
      final currentValues = Map<String, dynamic>.from(
        _formKey.currentState!.value,
      );
      currentValues['serviceProvider'] = provider.id;
      currentValues['baseUrl'] = provider.baseUrl;
      currentValues['headers'] = _formatHeaders(provider.headers);
      currentValues['apiFormat'] = provider.apiFormat;
      if (provider.defaultModel != null && provider.defaultModel!.isNotEmpty) {
        currentValues['model'] = provider.defaultModel!;
      }
      _formKey.currentState!.patchValue(currentValues);
    }
    if (!silent) {
      ToastService.instance.showToast('openai_configUpdated'.tr);
    }
  }

  // 模型选择
  Future<void> _selectModel() async {
    final currentModel = _formKey.currentState?.value['model'] as String? ?? '';
    final selectedModel = await NavigationHelper.push<LLMModel>(
      context,
      ModelSearchScreen(
        initialModelId: currentModel,
        initialProvider: _selectedProviderId.isEmpty
            ? null
            : _selectedProviderId,
      ),
    );
    if (selectedModel != null && _formKey.currentState != null) {
      _formKey.currentState!.patchValue({'model': selectedModel.id});
    }
  }

  // 触发表单验证并测试 Agent

  Future<void> _testAgent() async {
    if (_formKey.currentState == null ||
        !_formKey.currentState!.saveAndValidate()) {
      return;
    }

    final values = _formKey.currentState!.value;

    // 从 iconAvatarRow 字段获取图标和头像
    final iconAvatarData = values['iconAvatar'] as Map<String, dynamic>?;

    // 从 promptEditor 字段获取提示词
    final prompts = values['promptEditor'] as List<dynamic>? ?? [];
    // 构建完整的 messages 数组（包含 system 类型）
    final allMessages = <Prompt>[];

    for (final p in prompts) {
      if (p is Map<String, dynamic>) {
        allMessages.add(Prompt.fromJson(p));
      }
    }

    // 创建临时agent用于测试，使用表单中的最新配置
    final headers = _parseHeaders(values['headers'] as String? ?? '');
    final apiKey = headers['Authorization']?.replaceFirst('Bearer ', '') ?? '';

    final testAgent = AIAgent(
      id: 'test',
      model: values['model'] as String? ?? 'gpt-4-vision-preview',
      name: values['name'] as String? ?? '',
      description: values['description'] as String? ?? '',
      serviceProviderId: _selectedProviderId,
      baseUrl: values['baseUrl'] as String? ?? '',
      headers: headers,
      tags: (values['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      temperature: (double.tryParse('${values['temperature']}') ?? 0.7).clamp(
        0.0,
        2.0,
      ),
      icon: iconAvatarData?['icon'] as IconData?,
      iconColor: iconAvatarData?['iconColor'] as Color?,
      avatarUrl: iconAvatarData?['avatarUrl'] as String?,
      maxLength: 2000,
      topP: 1.0,
      frequencyPenalty: 0.0,
      presencePenalty: 0.0,
      enableFunctionCalling: values['enableFunctionCalling'] as bool? ?? false,
      promptPresetId: values['promptPresetId'] as String?,
      enableOpeningQuestions:
          values['enableOpeningQuestions'] as bool? ?? false,
      openingQuestions:
          (values['openingQuestions'] as List<dynamic>?)?.cast<String>() ?? [],
      messages: allMessages.isNotEmpty ? allMessages : null,
      apiFormat: values['apiFormat'] as String? ?? 'openai',
    );

    // 获取当前表单的值
    final formValues = {
      'name': values['name'],
      'baseUrl': values['baseUrl'],
      'model': values['model'],
      'serviceProviderId': _selectedProviderId,
      'apiKey': apiKey,
      'temperature': testAgent.temperature,
      'maxLength': 2000,
      'topP': 1.0,
      'frequencyPenalty': 0.0,
      'presencePenalty': 0.0,
    };

    await TestService.showLongTextInputDialog(
      context,
      title: '${'openai_testAgentTitle'.tr}${testAgent.name}',
      hintText: 'openai_enterTestText'.tr,
      enableImagePicker: true,
      testAgent: testAgent,
      formValues: formValues,
    );
  }

  // ========== 智能创建 / 优化人设（Soul Forge） ==========

  /// 从表单读取连接配置（不触发校验），供生成请求使用
  AIAgent? _buildConnectionAgent() {
    final form = _formKey.currentState;
    if (form == null) return null;
    final values = form.instantValue;
    final baseUrl = (values['baseUrl'] as String?)?.trim() ?? '';
    final model = (values['model'] as String?)?.trim() ?? '';
    if (baseUrl.isEmpty || model.isEmpty) return null;
    return AIAgent(
      id: 'soul_forge_conn',
      name: 'Soul Forge',
      description: '',
      tags: const [],
      serviceProviderId: _selectedProviderId,
      baseUrl: baseUrl,
      headers: _parseHeaders(values['headers'] as String? ?? ''),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      model: model,
      maxLength: 4096,
      apiFormat: values['apiFormat'] as String? ?? 'openai',
    );
  }

  /// 从表单构建当前 agent 快照（含现有提示词），作为优化上下文
  AIAgent? _buildCurrentAgentSnapshot() {
    final form = _formKey.currentState;
    if (form == null) return null;
    final values = form.instantValue;
    final prompts = values['promptEditor'] as List<dynamic>? ?? [];
    final messages = <Prompt>[];
    for (final p in prompts) {
      if (p is Map<String, dynamic>) {
        messages.add(Prompt.fromJson(p));
      }
    }
    return AIAgent(
      id: _editingAgent?.id ?? 'draft',
      name: values['name'] as String? ?? '',
      description: values['description'] as String? ?? '',
      tags: (values['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      serviceProviderId: _selectedProviderId,
      baseUrl: '',
      headers: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      model: values['model'] as String? ?? '',
      messages: messages,
    );
  }

  Future<void> _showSmartSoulSheet() async {
    final current = _buildCurrentAgentSnapshot();
    final hasCurrentSoul =
        current != null && current.effectiveSystemPrompt.trim().isNotEmpty;

    final result = await SmoothBottomSheet.show<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DSThemeBridge(
        child: Builder(
          builder: (context) => _SmartSoulSheet(
            defaultOptimize: hasCurrentSoul,
            onGenerate: (optimize, requirement) => SoulForgeService.generate(
              optimize: optimize,
              requirement: requirement,
              connectionAgent: _buildConnectionAgent(),
              currentAgent: current,
            ),
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      _applySoulResult(result);
    }
  }

  /// 将生成的 SOUL JSON 回填到表单
  void _applySoulResult(Map<String, dynamic> soul) {
    final form = _formKey.currentState;
    if (form == null) return;

    final patch = <String, dynamic>{};

    final name = (soul['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) patch['name'] = name;

    final description = (soul['description'] as String?)?.trim();
    if (description != null && description.isNotEmpty) {
      patch['description'] = description;
    }

    final tags = (soul['tags'] as List<dynamic>?)?.cast<String>().toList();
    if (tags != null && tags.isNotEmpty) patch['tags'] = tags;

    final systemPrompt = (soul['systemPrompt'] as String?)?.trim();
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      // 替换 system 消息，保留现有非 system 预设消息
      final prompts = form.instantValue['promptEditor'] as List<dynamic>? ?? [];
      final others = prompts
          .where((p) => (p as Map<String, dynamic>)['type'] != 'system')
          .toList();
      patch['promptEditor'] = [
        {'type': 'system', 'content': systemPrompt},
        ...others,
      ];
    }

    final questions = (soul['openingQuestions'] as List<dynamic>?)
        ?.cast<String>()
        .toList();
    if (questions != null && questions.isNotEmpty) {
      patch['enableOpeningQuestions'] = true;
      patch['openingQuestions'] = questions;
    }

    form.patchValue(patch);
    ToastService.instance.showToast('openai_soulForgeApplied'.tr);
  }
}

/// 更多菜单中的菜单行（气泡内，手绘果冻条样式）
class _AgentMenuRow extends StatelessWidget {
  const _AgentMenuRow({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.danger = false,
  });

  final Widget icon;
  final String label;
  final AppThemeData theme;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? theme.danger : theme.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Pressable(
        onPressed: onTap,
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return JellyBox(
            radius: theme.radii.md,
            raised: false,
            color: pressed ? accent.mixWhite(0.9) : theme.surfaceAlt,
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.sm + 2,
            ),
            child: Row(
              children: [
                icon,
                SizedBox(width: theme.spacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: DsTypography.body.copyWith(
                      color: danger ? theme.danger : theme.text,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 智能创建 / 优化人设底部弹层内容（SmoothBottomSheet）
class _SmartSoulSheet extends StatefulWidget {
  final bool defaultOptimize;
  final Future<Map<String, dynamic>> Function(bool optimize, String requirement)
  onGenerate;

  const _SmartSoulSheet({
    required this.defaultOptimize,
    required this.onGenerate,
  });

  @override
  State<_SmartSoulSheet> createState() => _SmartSoulSheetState();
}

class _SmartSoulSheetState extends State<_SmartSoulSheet> {
  late final TextEditingController _controller;
  late bool _optimize = widget.defaultOptimize;
  bool _isGenerating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final requirement = _controller.text.trim();
    if (requirement.isEmpty) {
      setState(() => _error = 'openai_soulForgeRequirementEmpty'.tr);
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      final soul = await widget.onGenerate(_optimize, requirement);
      if (mounted) {
        Navigator.of(context).pop(soul);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        // 外壳背景/圆角由 SmoothBottomSheet 提供，这里只留边距
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'openai_soulForgeTitle'.tr,
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.sm),
                Text(
                  'openai_soulForgeDesc'.tr,
                  textAlign: TextAlign.center,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
                SizedBox(height: theme.spacing.md),
                Row(
                  children: [
                    Expanded(
                      child: DSButton(
                        label: 'openai_smartCreate'.tr,
                        size: DSButtonSize.sm,
                        variant: _optimize
                            ? DSButtonVariant.outline
                            : DSButtonVariant.primary,
                        onPressed: _isGenerating
                            ? null
                            : () => setState(() => _optimize = false),
                      ),
                    ),
                    SizedBox(width: theme.spacing.sm),
                    Expanded(
                      child: DSButton(
                        label: 'openai_smartOptimize'.tr,
                        size: DSButtonSize.sm,
                        variant: _optimize
                            ? DSButtonVariant.primary
                            : DSButtonVariant.outline,
                        onPressed: _isGenerating
                            ? null
                            : () => setState(() => _optimize = true),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: theme.spacing.md),
                DSInput(
                  controller: _controller,
                  hint: _optimize
                      ? 'openai_soulForgeHintOptimize'.tr
                      : 'openai_soulForgeHintCreate'.tr,
                  maxLines: 6,
                  enabled: !_isGenerating,
                ),
                if (_error != null) ...[
                  SizedBox(height: theme.spacing.sm),
                  Text(
                    _error!,
                    style: DsTypography.caption.copyWith(color: theme.danger),
                  ),
                ],
                if (_isGenerating) ...[
                  SizedBox(height: theme.spacing.md),
                  Center(
                    child: DSLoadingDots(
                      label: 'openai_soulForgeGenerating'.tr,
                    ),
                  ),
                ],
                SizedBox(height: theme.spacing.lg),
                DSButton(
                  label: 'openai_soulForgeGenerate'.tr,
                  icon: DsIconKind.star,
                  onPressed: _isGenerating ? null : _generate,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
