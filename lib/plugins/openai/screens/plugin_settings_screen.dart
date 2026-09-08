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
import '../openai_plugin.dart';

class PluginSettingsScreen extends StatefulWidget {
  const PluginSettingsScreen({super.key});

  @override
  State<PluginSettingsScreen> createState() => _PluginSettingsScreenState();
}

class _PluginSettingsScreenState extends State<PluginSettingsScreen> {
  late final TextEditingController _skillsController;
  late final TextEditingController _mcpController;

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
    _skillsController = TextEditingController(text: slots.skills.join(', '));
    _mcpController = TextEditingController(text: slots.mcpServers.join(', '));
  }

  @override
  void dispose() {
    _skillsController.dispose();
    _mcpController.dispose();
    super.dispose();
  }

  void _saveSlots() {
    final slots = AgentResourceSlots(
      skills: _split(_skillsController.text),
      mcpServers: _split(_mcpController.text),
    );
    AgentLibResourceService.globalSlots = slots;
    OpenAIPlugin.instance.updateSettings(
      AgentLibResourceService.toSettings(slots),
    );
  }

  List<String> _split(String value) =>
      value
          .split(RegExp(r'[,\n]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();

  @override
  Widget build(BuildContext context) {
    // Scaffold/AppBar 属结构性组件,刻意保留 Material;列表项已换 DSListItem
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            appBar: AppBar(
              leading: DSIconButton(
                icon: DsIconKind.chevronLeft,
                size: 40,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                onPressed: () => Navigator.maybePop(context),
              ),
              title: Text('openai_pluginSettingsTitle'.tr),
            ),
            body: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return ListView(
                  padding: EdgeInsets.all(theme.spacing.lg),
                  children: [
                    _ResourceSlotSection(
                      skillsController: _skillsController,
                      mcpController: _mcpController,
                      onChanged: _saveSlots,
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
                        NavigationHelper.push(context, const ModelListScreen());
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
                      subtitle: 'openai_promptPresetManagementDescription'.tr,
                      showChevron: true,
                      onTap: () {
                        NavigationHelper.push(
                          context,
                          const PromptPresetScreen(),
                        );
                      },
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

class _ResourceSlotSection extends StatelessWidget {
  const _ResourceSlotSection({
    required this.skillsController,
    required this.mcpController,
    required this.onChanged,
  });

  final TextEditingController skillsController;
  final TextEditingController mcpController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.extension_outlined),
      title: const Text('AgentLib 资源插槽'),
      subtitle: const Text('全局 Skills 与 MCP Server'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        TextField(
          controller: skillsController,
          decoration: const InputDecoration(
            labelText: 'Skills',
            hintText: 'skill-id, another-skill',
          ),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: mcpController,
          decoration: const InputDecoration(
            labelText: 'MCP Servers',
            hintText: 'https://example.com/mcp',
          ),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}
