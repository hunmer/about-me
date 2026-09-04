import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/models/plugin_analysis_method.dart';

class MethodSelectionDialog extends StatelessWidget {
  final Function(PluginAnalysisMethod) onMethodSelected;

  const MethodSelectionDialog({super.key, required this.onMethodSelected});

  @override
  Widget build(BuildContext context) {
    final methods = PluginAnalysisMethod.predefinedMethods;

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 380, maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'openai_selectAnalysisMethod'.tr,
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final method in methods)
                          Padding(
                            padding: EdgeInsets.only(bottom: theme.spacing.xs),
                            child: DSListItem(
                              title: method.name,
                              onTap: () {
                                Navigator.pop(context);
                                onMethodSelected(method);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: theme.spacing.md),
                DSButton(
                  label: 'app_cancel'.tr,
                  variant: DSButtonVariant.outline,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
