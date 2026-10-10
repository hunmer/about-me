import 'package:flutter/material.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:get/get.dart';
import '../models/nfc_record_item.dart';
import '../models/nfc_record_type.dart';

/// NFC 写入底部面板（DS 果冻风）
class NfcWriteDialog extends StatefulWidget {
  final Function(List<Map<String, String>>) onWrite;

  const NfcWriteDialog({super.key, required this.onWrite});

  /// 以 DS 底部面板形式打开
  static Future<void> show(
    BuildContext context, {
    required Function(List<Map<String, String>>) onWrite,
  }) {
    return showDSBottomSheet(
      context: context,
      title: 'nfc_writeNFCData'.tr,
      builder: (context) => NfcWriteDialog(onWrite: onWrite),
    );
  }

  @override
  State<NfcWriteDialog> createState() => _NfcWriteDialogState();
}

class _NfcWriteDialogState extends State<NfcWriteDialog> {
  final List<NfcRecordItem> _records = [];

  @override
  void initState() {
    super.initState();
    // 默认添加一条空记录
    _addRecord();
  }

  @override
  void dispose() {
    for (var record in _records) {
      record.dispose();
    }
    super.dispose();
  }

  void _addRecord() {
    setState(() {
      _records.add(NfcRecordItem());
    });
  }

  void _removeRecord(int index) {
    if (_records.length > 1) {
      setState(() {
        _records[index].dispose();
        _records.removeAt(index);
      });
    }
  }

  String _getHintText(NfcRecordType type) {
    switch (type) {
      case NfcRecordType.uri:
        return 'nfc_hintUri'.tr;
      case NfcRecordType.text:
        return 'nfc_hintText'.tr;
      case NfcRecordType.mime:
        return 'nfc_hintMime'.tr;
      case NfcRecordType.aar:
        return 'nfc_hintAar'.tr;
      case NfcRecordType.external_:
        return 'nfc_hintExternal'.tr;
    }
  }

  void _startWrite() {
    // 过滤空记录
    final records = _records
        .where((r) => r.controller.text.isNotEmpty)
        .map((r) => r.toMap())
        .toList();
    if (records.isEmpty) {
      Toast.error('nfc_errorNoRecords'.tr);
      return;
    }
    Navigator.of(context).pop();
    widget.onWrite(records);
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Padding(
      // 键盘弹起时上移内容，避免输入框被遮挡
      padding: EdgeInsets.only(
        left: theme.spacing.xl,
        right: theme.spacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 提示信息
          Container(
            padding: EdgeInsets.all(theme.spacing.md),
            decoration: BoxDecoration(
              color: theme.surfaceAlt,
              borderRadius: theme.radii.md,
            ),
            child: Row(
              children: [
                DsIcon(DsIconKind.info, size: 18, color: theme.primary),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Text(
                    'nfc_writeTip'.tr,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: theme.spacing.md),
          // 记录列表
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.4,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _records.length,
              itemBuilder: (context, index) =>
                  _buildRecordItem(context, index),
            ),
          ),
          // 添加记录按钮
          DSButton(
            label: 'nfc_addRecord'.tr,
            icon: DsIconKind.plus,
            variant: DSButtonVariant.secondary,
            onPressed: _addRecord,
          ),
          SizedBox(height: theme.spacing.md),
          // 取消 / 开始写入
          Row(
            children: [
              Expanded(
                child: DSButton(
                  label: 'nfc_cancel'.tr,
                  variant: DSButtonVariant.outline,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SizedBox(width: theme.spacing.md),
              Expanded(
                child: DSButton(
                  label: 'nfc_startWriting'.tr,
                  icon: DsIconKind.nfc,
                  onPressed: _startWrite,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建单条记录编辑项
  Widget _buildRecordItem(BuildContext context, int index) {
    final theme = DSThemeBridge.resolve(context);
    final record = _records[index];

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.md),
      child: JellyBox(
        radius: theme.radii.lg,
        raised: false,
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 记录头部：序号 + 删除按钮
            Row(
              children: [
                Expanded(
                  child: Text(
                    'nfc_recordN'.trParams({'n': (index + 1).toString()}),
                    style: DsTypography.caption.copyWith(
                      color: theme.textSub,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_records.length > 1)
                  DSIconButton(
                    icon: DsIconKind.close,
                    size: 28,
                    color: theme.surfaceAlt,
                    iconColor: theme.danger,
                    tooltip: 'nfc_deleteRecord'.tr,
                    onPressed: () => _removeRecord(index),
                  ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            // 类型选择
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.xs,
              children: [
                for (final type in NfcRecordType.values)
                  DSChip(
                    label: type.localizedLabel,
                    selected: record.type == type,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          record.type = type;
                        });
                      }
                    },
                  ),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            // 数据输入框
            DSInput(
              controller: record.controller,
              hint: _getHintText(record.type),
              maxLines: 2,
              minLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
