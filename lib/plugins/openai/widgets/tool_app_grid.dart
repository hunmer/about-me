import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/controllers/tool_app_controller.dart';
import 'package:aboutme/plugins/openai/models/tool_app.dart';

class ToolAppGrid extends StatelessWidget {
  const ToolAppGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Consumer<ToolAppController>(
        builder: (context, controller, child) {
          final theme = DSThemeBridge.resolve(context);
          if (controller.isLoading) {
            return const Center(child: DSLoadingDots());
          }

          if (controller.apps.isEmpty) {
            return Center(
              child: Text(
                'openai_noToolsAvailable'.tr,
                style: DsTypography.body.copyWith(color: theme.textSub),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: controller.apps.length,
            itemBuilder: (context, index) {
              final app = controller.apps[index];
              return _buildAppCard(context, app, controller);
            },
          );
        },
      ),
    );
  }

  Widget _buildAppCard(
    BuildContext context,
    ToolApp app,
    ToolAppController controller,
  ) {
    final theme = DSThemeBridge.resolve(context);
    return DSCard(
      padding: const EdgeInsets.all(16),
      onTap: () => controller.handleAppClick(context, app.id),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 应用图标按 appId 动态映射(注册表图标,刻意保留 Material)
          Icon(_getIconForApp(app.id), size: 36, color: theme.primary),
          const SizedBox(height: 8),
          Text(
            app.title,
            style: DsTypography.body.copyWith(color: theme.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            app.description,
            style: DsTypography.caption.copyWith(color: theme.textSub),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  IconData _getIconForApp(String appId) {
    switch (appId) {
      case 'plugin-analysis':
        return Icons.analytics;
      default:
        return Icons.apps;
    }
  }
}
