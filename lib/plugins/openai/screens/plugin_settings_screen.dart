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
