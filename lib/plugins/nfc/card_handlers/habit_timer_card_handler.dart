import 'package:flutter/material.dart';
import 'package:aboutme/core/services/plugin_data_selector/index.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme_nfc/aboutme_nfc.dart';
import 'package:get/get.dart';
import '../widgets/nfc_action_card.dart';
import '../widgets/nfc_waiting_dialog.dart';
import 'base_card_handler.dart';

/// 习惯计时卡片处理器
class HabitTimerCardHandler extends BaseCardHandler {
  @override
  String get name => 'nfc_cardHabit_name'.tr;

  @override
  String get description => 'nfc_cardHabit_desc'.tr;

  @override
  IconData get icon => Icons.timer;

  @override
  Color get color => Colors.amber;

  @override
  Future<List<Map<String, String>>?> getRecordsForPreview(BuildContext context) async {
    // 打开习惯选择器
    final result = await pluginDataSelectorService.showSelector(
      context,
      'habits.habit',
    );

    if (result == null || result.cancelled) {
      return null;
    }

    // 获取选择的习惯 ID
    final habitId = result.path.isNotEmpty ? result.path.last.selectedItem.id : null;

    if (habitId == null) {
      Toast.error('nfc_errorNoSelection'.tr);
      return null;
    }

    // 构建深度链接 URL
    final deepLinkUrl = 'aboutme://habit/timer?habitId=$habitId&action=start_timer';

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

    // 提取habitName用于提示
    final deepLinkUrl = records[0]['data'] ?? '';
    final habitNameMatch = RegExp(r'habitId=([^&]+)').firstMatch(deepLinkUrl);
    final habitName = habitNameMatch?.group(1) ?? 'nfc_unknownItem'.tr;

    // 显示等待对话框
    if (!context.mounted) return;

    showNfcWaitingDialog(
      context,
      detail: 'nfc_writingHabitTimer'.trParams({'item': habitName}),
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
          'nfc_writeHabitSuccess'.trParams({'item': habitName}),
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
