import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:aboutme/plugins/calendar_album/controllers/calendar_controller.dart';
import 'package:aboutme/plugins/calendar_album/controllers/tag_controller.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'entry_editor_controller.dart';
import 'entry_editor_ui.dart';

/// 日记新建底部弹层（基于通用 [SmoothBottomSheet.showForm]）
class EntryEditorSheet {
  /// 以底部弹层打开新建日记表单，保存成功后自动关闭
  static Future<void> show(
    BuildContext context, {
    DateTime? initialDate,
  }) {
    final calendarController = Provider.of<CalendarController>(
      context,
      listen: false,
    );
    final tagController = Provider.of<TagController>(context, listen: false);

    _EntryEditorSheetBodyState? bodyState;
    return SmoothBottomSheet.showForm(
      context: context,
      title: 'calendar_album_new_post'.tr,
      child: _EntryEditorSheetBody(
        initialDate: initialDate,
        calendarController: calendarController,
        tagController: tagController,
        onStateReady: (state) => bodyState = state,
      ),
      onSave: () => bodyState?.save(),
    );
  }
}

class _EntryEditorSheetBody extends StatefulWidget {
  final DateTime? initialDate;
  final CalendarController calendarController;
  final TagController tagController;
  final ValueChanged<_EntryEditorSheetBodyState> onStateReady;

  const _EntryEditorSheetBody({
    required this.initialDate,
    required this.calendarController,
    required this.tagController,
    required this.onStateReady,
  });

  @override
  State<_EntryEditorSheetBody> createState() => _EntryEditorSheetBodyState();
}

class _EntryEditorSheetBodyState extends State<_EntryEditorSheetBody> {
  late EntryEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EntryEditorController(
      isEditing: false,
      initialDate: widget.initialDate,
    );
    widget.onStateReady(this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 保存日记，成功后关闭弹层
  void save() {
    if (!mounted) return;
    final result = _controller.saveEntry(context);
    if (result != null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.calendarController),
        ChangeNotifierProvider.value(value: widget.tagController),
      ],
      child: EntryEditorForm(
        controller: _controller,
        parentContext: context,
      ),
    );
  }
}
