import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/nfc_action_card.dart';
import '../widgets/nfc_write_dialog.dart';
import 'base_card_handler.dart';

/// 自定义写入卡片处理器
class CustomWriteCardHandler extends BaseCardHandler {
  final Function(List<Map<String, String>>) onWrite;

  CustomWriteCardHandler({required this.onWrite});

  @override
  String get name => 'nfc_cardCustom_name'.tr;

  @override
  String get description => 'nfc_cardCustom_desc'.tr;

  @override
  IconData get icon => Icons.edit;

  @override
  Color get color => Colors.orange;

  @override
  Future<List<Map<String, String>>?> getRecordsForPreview(BuildContext context) async {
    // 自定义写入通过面板输入数据，不需要单独的预览功能
    return null;
  }

  @override
  Future<void> executeWrite(BuildContext context) async {
    NfcWriteDialog.show(context, onWrite: onWrite);
  }

  @override
  Widget buildCard(BuildContext context, bool isEnabled, bool isWriting) {
    return Expanded(
      child: NfcActionCard(
        name: name,
        description: description,
        icon: icon,
        accentColor: color,
        isEnabled: isEnabled,
        isWorking: isWriting,
        workingLabel: 'nfc_cardWriting'.tr,
        compact: true,
        onTap: () => executeWrite(context),
      ),
    );
  }
}
