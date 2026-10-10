import 'package:flutter/material.dart';
import 'package:aboutme/core/services/plugin_data_selector/index.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme_nfc/aboutme_nfc.dart';
import 'package:get/get.dart';
import '../widgets/nfc_action_card.dart';
import '../widgets/nfc_waiting_dialog.dart';
import 'base_card_handler.dart';

/// 目标追踪进度卡片处理器
class TrackerProgressCardHandler extends BaseCardHandler {
  @override
  String get name => 'nfc_cardTracker_name'.tr;

  @override
  String get description => 'nfc_cardTracker_desc'.tr;

  @override
  IconData get icon => Icons.track_changes;

  @override
  Color get color => Colors.red;

  @override
  Future<List<Map<String, String>>?> getRecordsForPreview(BuildContext context) async {
    // 打开目标选择器
    final result = await pluginDataSelectorService.showSelector(
      context,
      'tracker.goal',
    );

    if (result == null || result.cancelled) {
      return null;
    }

    // 获取选择的目标 ID 和名称
    final goalId = result.path.isNotEmpty ? result.path.last.selectedItem.id : null;
    final goalName = result.path.isNotEmpty ? result.path.last.selectedItem.title : null;

    if (goalId == null) {
      Toast.error('nfc_errorNoSelection'.tr);
      return null;
    }

    // 显示对话框让用户输入增加的值
    if (!context.mounted) return null;

    final valueController = TextEditingController();
    final value = await showDSDialog<double>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) {
        final theme = DSThemeBridge.resolve(dialogContext);
        return DSDialog(
          title: 'nfc_trackerValueTitle'.tr,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'nfc_trackerValueGoal'.trParams({'goal': goalName ?? ''}),
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
              SizedBox(height: theme.spacing.md),
              DSInput(
                controller: valueController,
                label: 'nfc_trackerValueLabel'.tr,
                hint: 'nfc_trackerValueHint'.tr,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              SizedBox(height: theme.spacing.sm),
              Text(
                'nfc_trackerValueNote'.trParams({'goal': goalName ?? ''}),
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ],
          ),
          cancelText: 'nfc_cancel'.tr,
          confirmText: 'nfc_confirm'.tr,
          onConfirm: () {
            final text = valueController.text.trim();
            final parsedValue = double.tryParse(text);
            if (parsedValue == null || parsedValue <= 0) {
              Toast.error('nfc_trackerValueInvalid'.tr);
              return;
            }
            Navigator.of(dialogContext).pop(parsedValue);
          },
        );
      },
    );

    // 用户取消或未输入有效值
    if (value == null) {
      return null;
    }

    // 构建深度链接 URL
    final deepLinkUrl = 'aboutme://tracker/progress?goalId=$goalId&value=$value';

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

    // 提取goalName和value用于提示
    final deepLinkUrl = records[0]['data'] ?? '';
    final goalNameMatch = RegExp(r'goalId=([^&]+)').firstMatch(deepLinkUrl);
    final goalName = goalNameMatch?.group(1) ?? 'nfc_unknownItem'.tr;
    final valueMatch = RegExp(r'value=([^&]+)').firstMatch(deepLinkUrl);
    final value = valueMatch?.group(1) ?? '0';

    // 显示等待对话框
    if (!context.mounted) return;

    showNfcWaitingDialog(
      context,
      detail: 'nfc_writingTracker'.trParams({'goal': goalName, 'value': value}),
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
          'nfc_writeTrackerSuccess'.trParams({'goal': goalName, 'value': value}),
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
