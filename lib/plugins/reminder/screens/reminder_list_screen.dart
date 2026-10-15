import 'package:flutter/material.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import '../models/reminder.dart';
import '../controllers/reminder_list_controller.dart';
import 'components/reminder_card.dart';
import 'components/empty_state.dart';
import 'reminder_form_screen.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/form_modal_sheet.dart';

import 'package:get/get.dart';

/// 提醒列表界面
class ReminderListScreen extends StatefulWidget {
  const ReminderListScreen({super.key});

  @override
  State<ReminderListScreen> createState() => _ReminderListScreenState();
}

class _ReminderListScreenState extends State<ReminderListScreen> {
  late ReminderListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ReminderListController();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reminders = _controller.reminders;

    return Scaffold(
      floatingActionButton: DSThemeBridge(
        // DSFab 内部取 AppTheme，需包桥
        child: DSFab(onPressed: _addReminder),
      ),
      body: SuperCupertinoNavigationWrapper(
        title: Text('reminder_scheduledReminders'.tr),
        largeTitle: 'reminder_scheduledReminders'.tr,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addReminder),
        ],
        body: reminders.isEmpty
            ? const EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reminders.length,
                itemBuilder: (context, index) {
                  final reminder = reminders[index];
                  return ReminderCard(
                    reminder: reminder,
                    onToggle: () => _controller.toggleReminder(reminder.id),
                    onEdit: () => _editReminder(reminder),
                    onDelete: () => _deleteReminder(reminder),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _addReminder() async {
    // 新建提醒：smooth_sheets 底部弹层
    final result = await _showReminderForm();
    if (result == true) {
      await _controller.refresh();
    }
  }

  Future<void> _editReminder(Reminder reminder) async {
    final result = await _showReminderForm(reminder);
    if (result == true) {
      await _controller.refresh();
    }
  }

  Future<bool?> _showReminderForm([Reminder? reminder]) {
    VoidCallback? submitReminder;
    return FormModalSheet.show<bool>(
      context: context,
      title: reminder == null
          ? 'reminder_createReminder'.tr
          : 'reminder_editReminder'.tr,
      child: ReminderFormScreen(
        existingReminder: reminder,
        embedInSheet: true,
        onReady: (submit) => submitReminder = submit,
      ),
      onSave: () => submitReminder?.call(),
    );
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('reminder_deleteReminder'.tr),
        content: Text(
          'reminder_deleteConfirm'.trParams({'title': reminder.title}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('app_cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text('app_delete'.tr),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _controller.deleteReminder(reminder.id);
    }
  }
}
