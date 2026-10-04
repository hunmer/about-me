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
import '../aliveness/services/aliveness_store.dart';
import '../aliveness/services/keepalive_service.dart';
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

  /// 活人感决策层（Jev）与运行配置对话框
  Future<void> _showJevSettingsDialog(BuildContext context) async {
    final store = AlivenessStore.instance;
    final settings = await store.loadSettings();
    if (!mounted) return;

    final baseUrlCtrl = TextEditingController(
      text: settings['jevBaseUrl'] as String? ?? '',
    );
    final apiKeyCtrl = TextEditingController(
      text: settings['jevApiKey'] as String? ?? '',
    );
    final modelCtrl = TextEditingController(
      text: settings['jevModel'] as String? ?? 'jev-latest',
    );
    final thresholdCtrl = TextEditingController(
      text: '${settings['confidenceThreshold'] ?? 0.65}',
    );
    final voiceServiceCtrl = TextEditingController(
      text: settings['voiceServiceId'] as String? ?? '',
    );
    var keepAlive = settings['keepAliveEnabled'] as bool? ?? false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('活人感决策模型（Jev）'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: baseUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://api.typesafe.ai/v1/systemone',
                  ),
                ),
                TextField(
                  controller: apiKeyCtrl,
                  decoration: const InputDecoration(labelText: 'API Key'),
                  obscureText: true,
                ),
                TextField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(
                    labelText: '模型',
                    hintText: 'jev-latest',
                  ),
                ),
                TextField(
                  controller: thresholdCtrl,
                  decoration: const InputDecoration(
                    labelText: '置信度阈值（0~1，低于则走保守规则）',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const Divider(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('前台保活（Android）'),
                  subtitle: const Text('常驻通知保持主动消息调度，离开 app 后仍可想念你'),
                  value: keepAlive,
                  onChanged: (v) => setDialogState(() => keepAlive = v),
                ),
                TextField(
                  controller: voiceServiceCtrl,
                  decoration: const InputDecoration(
                    labelText: '语音消息 TTS 服务 ID（可选）',
                    hintText: '留空使用默认 TTS 服务，需支持合成的服务',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final threshold =
                    double.tryParse(thresholdCtrl.text.trim()) ?? 0.65;
                await store.saveSettings({
                  'jevBaseUrl': baseUrlCtrl.text.trim().isEmpty
                      ? 'https://api.typesafe.ai/v1/systemone'
                      : baseUrlCtrl.text.trim(),
                  'jevApiKey': apiKeyCtrl.text.trim(),
                  'jevModel': modelCtrl.text.trim().isEmpty
                      ? 'jev-latest'
                      : modelCtrl.text.trim(),
                  'confidenceThreshold': threshold.clamp(0.0, 1.0),
                  'keepAliveEnabled': keepAlive,
                  'voiceServiceId': voiceServiceCtrl.text.trim(),
                });
                // 立即同步前台保活状态
                if (keepAlive) {
                  await AlivenessKeepAliveService.instance.start();
                } else {
                  await AlivenessKeepAliveService.instance.stop();
                }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

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
                      onTap:
                          () => NavigationHelper.push(
                            context,
                            AgentResourceListScreen(
                              type: AgentResourceType.skills,
                              resources:
                                  AgentLibResourceService.globalSlots.skills,
                              onChanged: (items) {
                                _saveSlots(
                                  AgentResourceSlots(
                                    skills: items,
                                    mcpServers:
                                        AgentLibResourceService
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
                      onTap:
                          () => NavigationHelper.push(
                            context,
                            AgentResourceListScreen(
                              type: AgentResourceType.mcpServers,
                              resources:
                                  AgentLibResourceService
                                      .globalSlots
                                      .mcpServers,
                              onChanged: (items) {
                                _saveSlots(
                                  AgentResourceSlots(
                                    skills:
                                        AgentLibResourceService
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
                      onTap: () => _showJevSettingsDialog(context),
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
