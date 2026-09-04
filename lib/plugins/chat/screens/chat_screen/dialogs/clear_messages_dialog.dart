import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

class ClearMessagesDialog extends StatelessWidget {
  final Function() onConfirm;
  final Function() onCancel;

  const ClearMessagesDialog({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          return DSDialog(
            title: 'chat_clearAllMessages'.tr,
            message: 'chat_confirmClearAllMessages'.tr,
            cancelText: 'app_cancel'.tr,
            confirmText: 'app_save'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onCancel: onCancel,
            onConfirm: onConfirm,
          );
        },
      ),
    );
  }
}
