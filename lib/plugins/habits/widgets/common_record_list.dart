import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

class CommonRecordList<T> extends StatelessWidget {
  final List<T> records;
  final Future<bool> Function(BuildContext, T) confirmDismiss;
  final Future<void> Function(String) onDelete;
  final String Function(T) getDate;
  final String Function(T) getNotes;
  final String Function() getDeleteMessage;
  final Key Function(T) itemKey;

  const CommonRecordList({
    super.key,
    required this.records,
    required this.confirmDismiss,
    required this.onDelete,
    required this.getDate,
    required this.getNotes,
    required this.getDeleteMessage,
    required this.itemKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return ListView.separated(
      itemCount: records.length,
      separatorBuilder:
          (context, index) => Divider(
            height: 1,
            color: theme.stroke.withValues(alpha: theme.isDark ? 0.2 : 0.8),
          ),
      itemBuilder: (context, index) {
        final record = records[index];
        return Dismissible(
          key: itemKey(record),
          background: Container(
            color: theme.danger,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: DsIcon(DsIconKind.trash, color: DsColors.white),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss:
              (direction) async => await confirmDismiss(context, record),
          onDismissed: (direction) async {
            await onDelete(itemKey(record).toString());
            Toast.success(getDeleteMessage());
          },
          child: DSThemeBridge(
            child: DSListItem(
              title: getDate(record).split('.').first,
              subtitle: getNotes(record),
              onTap: () => _showDetailDialog(context, record),
            ),
          ),
        );
      },
    );
  }

  void _showDetailDialog(BuildContext context, T record) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSDialog(
            title: getDate(record).split('.').first,
            message: getNotes(record),
            confirmText: 'app_close'.tr,
          ),
    );
  }
}
