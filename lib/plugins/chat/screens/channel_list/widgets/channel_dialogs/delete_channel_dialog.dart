import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';

class DeleteChannelDialog extends StatelessWidget {
  final Channel channel;
  final Function(String) onDeleteChannel;

  const DeleteChannelDialog({
    super.key,
    required this.channel,
    required this.onDeleteChannel,
  });

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: DSDialog(
        title: 'chat_deleteChannel'.tr,
        message: 'chat_deleteChannelConfirmation'.tr,
        confirmText: 'app_delete'.tr,
        cancelText: 'app_cancel'.tr,
        confirmVariant: DSButtonVariant.destructive,
        onConfirm: () {
          onDeleteChannel(channel.id);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
