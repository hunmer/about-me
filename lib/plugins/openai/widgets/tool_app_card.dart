import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/models/tool_app.dart';

class ToolAppCard extends StatelessWidget {
  final ToolApp app;
  final VoidCallback? onTap;

  const ToolAppCard({super.key, required this.app, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return DSCard(
      padding: const EdgeInsets.all(16.0),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsIcon(DsIconKind.grid, size: 32, color: theme.primary),
          const SizedBox(height: 12),
          Text(
            app.title,
            style: DsTypography.body.copyWith(
              color: theme.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            app.description,
            style: DsTypography.caption.copyWith(color: theme.textSub),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
