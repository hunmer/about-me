import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/nfc_action_card.dart';
import 'base_card_handler.dart';

/// 读取 NFC 卡片处理器
class ReadCardHandler extends BaseCardHandler {
  final VoidCallback onRead;

  ReadCardHandler({required this.onRead});

  @override
  String get name => 'nfc_cardRead_name'.tr;

  @override
  String get description => 'nfc_cardRead_desc'.tr;

  @override
  IconData get icon => Icons.nfc;

  @override
  Color get color => Colors.blue;

  @override
  Future<List<Map<String, String>>?> getRecordsForPreview(BuildContext context) async {
    // 读取操作不需要预览功能
    return null;
  }

  @override
  Future<void> executeWrite(BuildContext context) async {
    onRead();
  }

  @override
  Widget buildCard(BuildContext context, bool isEnabled, bool isReading) {
    return Expanded(
      child: NfcActionCard(
        name: name,
        description: description,
        icon: icon,
        accentColor: color,
        isEnabled: isEnabled,
        isWorking: isReading,
        workingLabel: 'nfc_cardRead_working'.tr,
        compact: true,
        onTap: onRead,
      ),
    );
  }
}
