import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/onboarding/plugin_onboarding_screen.dart';
import 'provider_settings_screen.dart';
import 'model_list_screen.dart';
import 'multimodal_model_setup_screen.dart';
import 'prompt_preset_screen.dart';
import '../services/agentlib_resource_service.dart';
import 'package:agentlib/agent_slots.dart';
import '../aliveness/widgets/jev_settings_dialog.dart';
import '../aliveness/screens/memory_manager_screen.dart';
import '../openai_plugin.dart';
import '../services/soul_forge_service.dart';
import '../services/chat_assistant_service.dart';
import 'agent_edit_screen.dart';
import 'agent_resource_list_screen.dart';
import '../models/ai_agent.dart';

class PluginSettingsScreen extends StatefulWidget {
  const PluginSettingsScreen({super.key});

  @override
  State<PluginSettingsScreen> createState() => _PluginSettingsScreenState();
}

class _PluginSettingsScreenState extends State<PluginSettingsScreen> {
  late String _multimodalModelLabel;

  /// 内置聊天助手当前使用的模型（设置项尾部展示）
  String _chatAssistantModelLabel = '';

  /// 可选 Agent 列表（askContext 默认 Agent 配置用）
  List<AIAgent> _agents = [];

  /// askContext 默认 Agent ID（null 表示不使用默认）
  String? _askContextAgentId;

  @override
  void initState() {
    super.initState();
    _multimodalModelLabel = _loadMultimodalModelLabel();
    _loadChatAssistantModelLabel();
    _askContextAgentId =
        OpenAIPlugin.instance.settings['askContextDefaultAgentId'] as String?;
    _loadAgents();
    AgentResourceSlots slots;
    try {
      slots = AgentLibResourceService.fromSettings(
        OpenAIPlugin.instance.settings,
      );
      AgentLibResourceService.globalSlots = slots;
    } catch (_) {
      slots = AgentLibResourceService.globalSlots;
    }
  }

  /// 识图模型设置项展示：优先新配置（含连接信息），回退旧版仅模型名
  String _loadMultimodalModelLabel() {
    final settings = OpenAIPlugin.instance.settings;
    final config =
        settings['multimodalModelConfig'] as Map<String, dynamic>?;
    final model =
        (config?['model'] as String?) ??
        (settings['defaultMultimodalModel'] as String? ?? '');
    return model.trim().isEmpty ? '未配置' : model.trim();
  }

  Future<void> _openMultimodalModelSetup() async {
    await NavigationHelper.push(
      context,
      const MultimodalModelSetupScreen(),
    );
    if (mounted) {
      setState(() => _multimodalModelLabel = _loadMultimodalModelLabel());
    }
  }

  /// 重新运行引导的配置步骤（厂商 / 默认模型 / API Key），
  /// 跳过欢迎页；完成后走插件的 onOnboardingComplete 应用配置
  void _reopenOnboardingSetup() {
    showPluginOnboarding(
      context,
      plugin: OpenAIPlugin.instance,
      steps: OpenAIPlugin.instance
          .getOnboardingSteps(context)
          .where((step) => step.builder != null)
          .toList(),
    );
  }

  /// 打开内置 Soul Forge 的编辑页（连接 / 模型配置）
  Future<void> _openSoulForgeSettings() async {
    await SoulForgeService.ensureBuiltinAgent();
    final agent = await SoulForgeService.loadBuiltinAgent();
    if (!mounted || agent == null) return;
    await NavigationHelper.push(context, AgentEditScreen(agent: agent));
  }

  /// 内置聊天助手设置项尾部展示：当前使用的模型名
  Future<void> _loadChatAssistantModelLabel() async {
    final agent = await ChatAssistantService.loadBuiltinAgent();
    if (!mounted) return;
    final model = agent?.model.trim() ?? '';
    setState(() => _chatAssistantModelLabel = model.isEmpty ? '未配置' : model);
  }

  /// 打开内置聊天助手的编辑页（服务商 / 模型 / 连接配置）
  Future<void> _openChatAssistantSettings() async {
    await ChatAssistantService.ensureBuiltinAgent();
    final agent = await ChatAssistantService.loadBuiltinAgent();
    if (!mounted || agent == null) return;
    await NavigationHelper.push(context, AgentEditScreen(agent: agent));
    _loadChatAssistantModelLabel();
  }

  /// 加载可选 Agent 列表（不含内置 Agent）
  Future<void> _loadAgents() async {
    try {
      final agents = await OpenAIPlugin.instance.controller.loadVisibleAgents();
      if (mounted) {
        setState(() => _agents = agents);
      }
    } catch (e) {
      debugPrint('加载Agent列表失败: $e');
    }
  }

  /// 切换 askContext 默认 Agent
  void _onAskContextAgentChanged(String? agentId) {
    setState(() => _askContextAgentId = agentId);
    OpenAIPlugin.instance.updateSettings({'askContextDefaultAgentId': agentId});
  }

  void _saveSlots(AgentResourceSlots slots) {
    AgentLibResourceService.globalSlots = slots;
    OpenAIPlugin.instance.updateSettings(
      AgentLibResourceService.toSettings(slots),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold 属结构性组件,刻意保留 Material;顶栏用 DSLightHeader,列表项用 DSListItem
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: Builder(
                builder: (context) {
                  final theme = DSThemeBridge.resolve(context);
                  return Column(
                  children: [
                    DSLightHeader(title: 'openai_pluginSettingsTitle'.tr),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.all(theme.spacing.lg),
                        children: [
                          DSListItem(
                            leading: DsIcon(
                              DsIconKind.image,
                              size: 22,
                              color: theme.primary,
                            ),
                            title: '默认识图模型',
                            subtitle:
                                '当前模型不支持图片时，read_image 工具使用此模型解析',
                            showChevron: true,
                            trailing: SizedBox(
                              width: 120,
                              child: Text(
                                _multimodalModelLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: DsTypography.caption.copyWith(
                                  color: theme.textSub,
                                ),
                              ),
                            ),
                            onTap: _openMultimodalModelSetup,
                          ),
                          SizedBox(height: theme.spacing.sm),
                          DSListItem(
                            leading: DsIcon(
                              DsIconKind.bot,
                              size: 22,
                              color: theme.primary,
                            ),
                            title: '询问上下文默认Agent',
                            subtitle: '询问当前上下文打开聊天时，未单独配置路由时使用的Agent',
                            showChevron: false,
                            trailing: DSSelect<String?>(
                              width: 140,
                              value: _askContextAgentId,
                              hint: '未设置',
                              items: [
                                const DSSelectItem<String?>(
                                  label: '未设置',
                                  value: null,
                                ),
                                ..._agents.map(
                                  (agent) => DSSelectItem<String?>(
                                    label: agent.name,
                                    value: agent.id,
                                  ),
                                ),
                              ],
                              onChanged: _onAskContextAgentChanged,
                            ),
                          ),
                          SizedBox(height: theme.spacing.sm),
                          DSListItem(
                            leading: DsIcon(
                              DsIconKind.refresh,
                              size: 22,
                              color: theme.primary,
                            ),
                            title: '默认模型设置',
                            subtitle: '重新运行引导，配置默认厂商、模型与 API Key',
                            showChevron: true,
                            onTap: _reopenOnboardingSetup,
                          ),
                          SizedBox(height: theme.spacing.sm),
                          DSListItem(
                            leading: DsIcon(
                              DsIconKind.layers,
                              size: 22,
                              color: theme.primary,
                            ),
                            title: 'Skills',
                            subtitle:
                                '${AgentLibResourceService.globalSlots.skills.length} 个资源',
                            showChevron: true,
                            onTap: () => NavigationHelper.push(
                              context,
                              AgentResourceListScreen(
                                type: AgentResourceType.skills,
                                resources:
                                    AgentLibResourceService.globalSlots.skills,
                                onChanged: (items) {
                                  _saveSlots(
                                    AgentResourceSlots(
                                      skills: items,
                                      mcpServers: AgentLibResourceService
                                          .globalSlots
                                          .mcpServers,
                                    ),
                                  );
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: theme.spacing.sm),
                          DSListItem(
                            leading: DsIcon(
                              DsIconKind.block,
                              size: 22,
                              color: theme.primary,
                            ),
                            title: 'MCP Servers',
                            subtitle:
                                '${AgentLibResourceService.globalSlots.mcpServers.length} 个资源',
                            showChevron: true,
                            onTap: () => NavigationHelper.push(
                              context,
                              AgentResourceListScreen(
                                type: AgentResourceType.mcpServers,
                                resources: AgentLibResourceService
                                    .globalSlots
                                    .mcpServers,
                                onChanged: (items) {
                                  _saveSlots(
                                    AgentResourceSlots(
                                      skills: AgentLibResourceService
                                          .globalSlots
                                          .skills,
                                      mcpServers: items,
                                    ),
                                  );
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: theme.spacing.sm),
                          DSListItem(
                            leading: DsIcon(
                              DsIconKind.moon,
                              size: 22,
                              color: theme.primary,
                            ),
                            title: '活人感决策模型（Jev）',
                            subtitle: '活人感增强的快决策层，未配置时使用本地规则',
                            showChevron: true,
                            onTap: () => showJevSettingsDialog(context),
                          ),
                          SizedBox(height: theme.spacing.sm),
                          DSListItem(
                            leading: DsIcon(
                              DsIconKind.star,
                              size: 22,
                              color: theme.primary,
                            ),
                            title: 'Soul Forge',
                            subtitle: '内置人格设计师，配置生成人设使用的模型与连接',
                            showChevron: true,
                            onTap: _openSoulForgeSettings,
                          ),
                          SizedBox(height: theme.spacing.sm),
                          DSListItem(
                            leading: DsIcon(
                              DsIconKind.chat,
                              size: 22,
                              color: theme.primary,
                            ),
                            title: '聊天助手',
                            subtitle: '内置快捷速记助手，配置服务商与模型',
                            showChevron: true,
                            trailing: SizedBox(
                              width: 120,
                              child: Text(
                                _chatAssistantModelLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: DsTypography.caption.copyWith(
                                  color: theme.textSub,
                                ),
                              ),
                            ),
                            onTap: _openChatAssistantSettings,
                          ),
                          SizedBox(height: theme.spacing.sm),
                          DSListItem(
                            leading: DsIcon(
                              DsIconKind.gear,
                              size: 22,
                              color: theme.primary,
                            ),
                            title: 'openai_providerSettingsTitle'.tr,
                            subtitle: 'openai_pluginDescription'.tr,
                            showChevron: true,
                            onTap: () {
                              NavigationHelper.push(
                                context,
                                const ProviderSettingsScreen(),
                              );
                            },
                          ),
                          SizedBox(height: theme.spacing.sm),
                          DSListItem(
                            leading: DsIcon(
                              DsIconKind.bot,
                              size: 22,
                              color: theme.primary,
                            ),
                            title: 'openai_modelManagement'.tr,
                            subtitle: 'openai_modelManagementDescription'.tr,
                            showChevron: true,
                            onTap: () {
                              NavigationHelper.push(
                                context,
                                const ModelListScreen(),
                              );
                            },
                          ),
                          SizedBox(height: theme.spacing.sm),
                          DSListItem(
                            leading: DsIcon(
                              DsIconKind.book,
                              size: 22,
                              color: theme.primary,
                            ),
                            title: 'openai_promptPresetManagement'.tr,
                            subtitle:
                                'openai_promptPresetManagementDescription'.tr,
                            showChevron: true,
                            onTap: () {
                              NavigationHelper.push(
                                context,
                                const PromptPresetScreen(),
                              );
                            },
                          ),
                          SizedBox(height: theme.spacing.sm),
                          DSListItem(
                            leading: DsIcon(
                              DsIconKind.layers,
                              size: 22,
                              color: theme.primary,
                            ),
                            title: 'openai_memoryManagerTitle'.tr,
                            subtitle: 'openai_memoryManagerDescription'.tr,
                            showChevron: true,
                            onTap: () {
                              NavigationHelper.push(
                                context,
                                const MemoryManagerScreen(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
