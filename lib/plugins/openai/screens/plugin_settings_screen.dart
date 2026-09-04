import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'provider_settings_screen.dart';
import 'model_list_screen.dart';
import 'prompt_preset_screen.dart';

class PluginSettingsScreen extends StatelessWidget {
  const PluginSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold/AppBar 属结构性组件,刻意保留 Material;列表项前导图标
    // (cloud/model_training/text_snippet)在 DS 暂无等价图标,一并保留 Material
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: Text('openai_pluginSettingsTitle'.tr),
            ),
            body: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud),
                  title: Text('openai_providerSettingsTitle'.tr),
                  subtitle: Text('openai_pluginDescription'.tr),
                  trailing: DsIcon(
                    DsIconKind.chevronRight,
                    size: 20,
                    color: theme.textSub,
                  ),
                  onTap: () {
                    NavigationHelper.push(
                      context,
                      const ProviderSettingsScreen(),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.model_training),
                  title: Text('openai_modelManagement'.tr),
                  subtitle: Text('openai_modelManagementDescription'.tr),
                  trailing: DsIcon(
                    DsIconKind.chevronRight,
                    size: 20,
                    color: theme.textSub,
                  ),
                  onTap: () {
                    NavigationHelper.push(context, const ModelListScreen());
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.text_snippet),
                  title: Text('openai_promptPresetManagement'.tr),
                  subtitle: Text('openai_promptPresetManagementDescription'.tr),
                  trailing: DsIcon(
                    DsIconKind.chevronRight,
                    size: 20,
                    color: theme.textSub,
                  ),
                  onTap: () {
                    NavigationHelper.push(context, const PromptPresetScreen());
                  },
                ),
                const Divider(),
              ],
            ),
          );
        },
      ),
    );
  }
}
