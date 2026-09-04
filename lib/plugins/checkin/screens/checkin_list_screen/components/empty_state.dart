import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_box_outline_blank, size: 64, color: theme.textSub),
          const SizedBox(height: 16),
          Text(
            'checkin_noRecords'.tr,
            style: DsTypography.heading.copyWith(color: theme.text),
          ),
          const SizedBox(height: 8),
          Text(
            'checkin_createCheckin'.tr,
            style: DsTypography.body.copyWith(color: theme.textSub),
          ),
        ],
      ),
    );
  }
}
