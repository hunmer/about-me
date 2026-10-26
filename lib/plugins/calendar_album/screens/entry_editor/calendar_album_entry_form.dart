import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/calendar_album/controllers/calendar_controller.dart';
import 'package:aboutme/plugins/calendar_album/controllers/tag_controller.dart';
import 'package:aboutme/plugins/calendar_album/models/calendar_entry.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'entry_editor_controller.dart';
import 'entry_editor_ui.dart';

/// 日记编辑底部弹层（基于通用 [SmoothBottomSheet.showForm]，支持新建与编辑）
class CalendarAlbumEntryForm {
  /// 以底部弹层打开日记表单，保存成功后自动关闭
  ///
  /// [entry] 非空为编辑模式（标题栏提供删除，带确认）；否则为新建模式
  /// [initialImages] 新建模式带入的图片（{'url','thumbUrl','liveVideoUrl'}，
  /// 与 ImagePickerDialog 返回结构一致）
  /// [calendarController] / [tagController] 缺省时从 [context] 的 Provider 查询；
  /// 调用处 context 不在 Provider 树内（如 FAB、小组件）时需显式传入
  static Future<void> show(
    BuildContext context, {
    CalendarEntry? entry,
    DateTime? initialDate,
    List<Map<String, dynamic>>? initialImages,
    CalendarController? calendarController,
    TagController? tagController,
  }) {
    // 参数被 onDelete 闭包捕获时空安全不提升，收敛为局部非空变量
    final resolvedCalendarController =
        calendarController ??
        Provider.of<CalendarController>(context, listen: false);
    final resolvedTagController =
        tagController ?? Provider.of<TagController>(context, listen: false);

    _CalendarAlbumEntryFormBodyState? bodyState;
    return SmoothBottomSheet.showForm(
      context: context,
      title:
          entry == null
              ? 'calendar_album_new_post'.tr
              : 'calendar_album_edit_post'.tr,
      child: _CalendarAlbumEntryFormBody(
        entry: entry,
        initialDate: initialDate,
        initialImages: initialImages,
        calendarController: resolvedCalendarController,
        tagController: resolvedTagController,
        onStateReady: (state) => bodyState = state,
      ),
      onSave: () => bodyState?.save(),
      onDelete:
          entry == null
              ? null
              : () => _confirmDelete(
                context,
                entry,
                resolvedCalendarController,
              ),
    );
  }

  /// 删除确认（与日历抽屉删除一致的双步确认）
  static Future<void> _confirmDelete(
    BuildContext context,
    CalendarEntry entry,
    CalendarController calendarController,
  ) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => DSDialog(
        title: 'core_delete'.tr,
        message: '${'core_confirmDelete'.tr} "${entry.title}"?',
        cancelText: 'calendar_album_cancel'.tr,
        confirmText: 'core_delete'.tr,
        confirmVariant: DSButtonVariant.destructive,
        onCancel: () => Navigator.pop(context),
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirmed == true) {
      calendarController.deleteEntry(entry);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _CalendarAlbumEntryFormBody extends StatefulWidget {
  final CalendarEntry? entry;
  final DateTime? initialDate;
  final List<Map<String, dynamic>>? initialImages;
  final CalendarController calendarController;
  final TagController tagController;
  final ValueChanged<_CalendarAlbumEntryFormBodyState> onStateReady;

  const _CalendarAlbumEntryFormBody({
    required this.entry,
    required this.initialDate,
    this.initialImages,
    required this.calendarController,
    required this.tagController,
    required this.onStateReady,
  });

  @override
  State<_CalendarAlbumEntryFormBody> createState() => _CalendarAlbumEntryFormBodyState();
}

class _CalendarAlbumEntryFormBodyState extends State<_CalendarAlbumEntryFormBody> {
  late EntryEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EntryEditorController(
      entry: widget.entry,
      isEditing: widget.entry != null,
      initialDate: widget.initialDate,
      initialImageUrls: [
        for (final r in widget.initialImages ?? const <Map<String, dynamic>>[])
          if (r['url'] != null) r['url'] as String,
      ],
      initialThumbUrls: [
        for (final r in widget.initialImages ?? const <Map<String, dynamic>>[])
          r['thumbUrl'] as String? ?? '',
      ],
      initialLiveVideoUrls: [
        for (final r in widget.initialImages ?? const <Map<String, dynamic>>[])
          r['liveVideoUrl'] as String? ?? '',
      ],
      initialImageDates: [
        for (final r in widget.initialImages ?? const <Map<String, dynamic>>[])
          r['date'] as DateTime?,
      ],
    );
    widget.onStateReady(this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 保存日记，成功后关闭弹层
  Future<void> save() async {
    if (!mounted) return;
    final result = await _controller.saveEntry(widget.calendarController);
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: EntryEditorForm(
          controller: _controller,
          parentContext: context,
        ),
      ),
    );
  }
}
