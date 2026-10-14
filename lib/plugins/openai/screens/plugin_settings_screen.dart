import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'provider_settings_screen.dart';
import 'model_list_screen.dart';
import 'prompt_preset_screen.dart';
import '../services/agentlib_resource_service.dart';
import 'package:agentlib/agent_slots.dart';
import '../aliveness/widgets/jev_settings_dialog.dart';
import '../openai_plugin.dart';
import 'agent_resource_list_screen.dart';

class PluginSettingsScreen extends StatefulWidget {
  const PluginSettingsScreen({super.key});

  @override
  State<PluginSettingsScreen> createState() => _PluginSettingsScreenState();
}

class _PluginSettingsScreenState extends State<PluginSettingsScreen> {
  @override
  void initState() {
    super.initState();
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
            body: Builder(
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
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
