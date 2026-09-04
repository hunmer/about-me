import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/habits/controllers/completion_record_controller.dart';
import 'package:aboutme/plugins/habits/models/completion_record.dart';
import 'package:aboutme/plugins/habits/widgets/common_record_list.dart';
import 'package:aboutme/core/services/toast_service.dart';

class HabitsHistoryList extends StatefulWidget {
  final String habitId;
  final CompletionRecordController controller;

  const HabitsHistoryList({
    super.key,
    required this.habitId,
    required this.controller,
  });

  @override
  State<HabitsHistoryList> createState() => _HabitsHistoryListState();
}

class _HabitsHistoryListState extends State<HabitsHistoryList> {
  List<CompletionRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final records = await widget.controller.getHabitCompletionRecords(
      widget.habitId,
    );
    if (mounted) {
      setState(() => _records = records);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('habits_history'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showClearAllDialog(context),
          ),
        ],
      ),
      body: CommonRecordList<CompletionRecord>(
        records: _records,
        confirmDismiss: (context, record) => _showDeleteDialog(context, record),
        onDelete: widget.controller.deleteCompletionRecord,
        getDate: (record) => record.date.toString(),
        getNotes: (record) => record.notes,
        getDeleteMessage: () => 'habits_recordDeleted'.tr,
        itemKey: (record) => Key(record.id),
      ),
    );
  }

  Future<bool> _showDeleteDialog(
    BuildContext context,
    CompletionRecord record,
  ) async {
    return await showDSDialog<bool>(
          context: context,
          theme: DSThemeBridge.resolve(context),
          builder:
              (context) => DSDialog(
                title: 'habits_deleteRecord'.tr,
                message: 'habits_deleteRecordMessage'.tr,
                cancelText: 'habits_cancel'.tr,
                confirmText: 'habits_delete'.tr,
                confirmVariant: DSButtonVariant.destructive,
                onConfirm: () async {
                  await widget.controller.deleteCompletionRecord(record.id);
                  Navigator.pop(context, true);
                },
              ),
        ) ??
        false;
  }

  Future<void> _showClearAllDialog(BuildContext context) async {
    final shouldClear =
        await showDSDialog<bool>(
          context: context,
          theme: DSThemeBridge.resolve(context),
          builder:
              (context) => DSDialog(
                title: 'habits_clearAllRecords'.tr,
                message: 'habits_deleteRecordMessage'.tr,
                cancelText: 'habits_cancel'.tr,
                confirmText: 'habits_clearAllRecords'.tr,
                confirmVariant: DSButtonVariant.destructive,
                onConfirm: () => Navigator.pop(context, true),
              ),
        ) ??
        false;

    if (shouldClear && mounted) {
      await widget.controller.clearAllCompletionRecords(widget.habitId);
      Toast.success('habits_clearAllRecords'.tr);
      await _loadRecords();
    }
  }
}
