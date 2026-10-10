import 'package:flutter/material.dart';
import 'package:aboutme/core/services/plugin_data_selector/index.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme_nfc/aboutme_nfc.dart';
import 'package:get/get.dart';
import '../widgets/nfc_action_card.dart';
import '../widgets/nfc_waiting_dialog.dart';
import 'base_card_handler.dart';

/// 物品使用记录卡片处理器
class GoodsUsageCardHandler extends BaseCardHandler {
  @override
  String get name => 'nfc_cardGoods_name'.tr;

  @override
  String get description => 'nfc_cardGoods_desc'.tr;

  @override
  IconData get icon => Icons.inventory_2;

  @override
  Color get color => Colors.orange;

  @override
  Future<List<Map<String, String>>?> getRecordsForPreview(BuildContext context) async {
    // 打开物品选择器
    final result = await pluginDataSelectorService.showSelector(
      context,
      'goods.item',
    );

    if (result == null || result.cancelled) {
      return null;
    }

    // 获取选择的物品 ID
    final itemId = result.path.isNotEmpty ? result.path.last.selectedItem.id : null;

    if (itemId == null) {
      Toast.error('nfc_errorNoSelection'.tr);
      return null;
    }

    // 构建深度链接 URL
    final deepLinkUrl = 'aboutme://goods/usage?itemId=$itemId&action=add_usage';

    // 返回NFC记录数据
    return [
      {'type': 'URI', 'data': deepLinkUrl},
      {'type': 'AAR', 'data': 'github.hunmer.aboutme'},
    ];
  }

  @override
  Future<void> executeWrite(BuildContext context) async {
    // 获取NFC记录数据
    final records = await getRecordsForPreview(context);

    if (records == null || records.isEmpty) {
      return;
    }

    // 提取itemName用于提示
    final deepLinkUrl = records[0]['data'] ?? '';
    final itemNameMatch = RegExp(r'itemId=([^&]+)').firstMatch(deepLinkUrl);
    final itemName = itemNameMatch?.group(1) ?? 'nfc_unknownItem'.tr;

    // 显示等待对话框
    if (!context.mounted) return;

    showNfcWaitingDialog(
      context,
      detail: 'nfc_writingGoodsUsage'.trParams({'item': itemName}),
    );

    try {
      final nfc = AboutmeNfc();
      // 使用已构建的records进行写入
      final writeResult = await nfc.writeNfcRecords(records);

      // 关闭等待对话框
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (writeResult.success) {
        Toast.success(
          'nfc_writeGoodsSuccess'.trParams({'item': itemName}),
        );
      } else {
        Toast.error(writeResult.error ?? 'nfc_writeFailed'.tr);
      }
    } catch (e) {
      // 关闭等待对话框
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      Toast.error('nfc_writeError'.trParams({'error': e.toString()}));
    }
  }

  @override
  Widget buildCard(BuildContext context, bool isEnabled, bool isWriting) {
    return NfcActionCard(
      name: name,
      description: description,
      icon: icon,
      accentColor: color,
      isEnabled: isEnabled,
      isWorking: isWriting,
      workingLabel: 'nfc_cardWriting'.tr,
      onTap: () => executeWrite(context),
      onPreview: () => showDataPreview(context),
    );
  }
}
