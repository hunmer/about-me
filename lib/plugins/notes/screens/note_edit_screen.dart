import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/models/note.dart';
import 'package:aboutme/plugins/notes/models/note_style_selection.dart';
import 'package:aboutme/plugins/notes/notes_plugin.dart';
import 'package:aboutme/plugins/notes/widgets/note_color_picker.dart';
import 'package:aboutme/widgets/rich_editor_screen.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 笔记编辑屏：通用富文本编辑屏 + 笔记特有逻辑
/// （notes_refresh 同步刷新、路由上下文）
class NoteEditScreen extends StatefulWidget {
  final Note? note;
  final Function(String title, String content, List<String> tags) onSave;

  const NoteEditScreen({super.key, this.note, required this.onSave});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late final EventManager _eventManager;
  Note? _currentNote;
  int _contentVersion = 0; // 内容版本号，外部同步刷新时递增以触发编辑器重载

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    _eventManager = EventManager.instance;
    // 订阅同步刷新事件
    _eventManager.subscribe('notes_refresh', _handleSyncRefresh);
    // 初始化时设置路由上下文
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateRouteContext();
    });
  }

  @override
  void dispose() {
    _eventManager.unsubscribe('notes_refresh', _handleSyncRefresh);
    super.dispose();
  }

  /// 处理同步刷新事件
  void _handleSyncRefresh(EventArgs args) {
    // 仅在编辑现有笔记时处理
    if (_currentNote == null) return;

    // 从 controller 获取最新的笔记数据
    final updatedNote = NotesPlugin.instance.controller.getNoteById(_currentNote!.id);
    if (updatedNote != null && mounted) {
      debugPrint('[NoteEditScreen] 检测到笔记更新: ${updatedNote.title}');
      // 更新当前笔记引用并增加版本号以触发编辑器重载
      setState(() {
        _currentNote = updatedNote;
        _contentVersion++;
      });
    }
  }

  /// 更新路由上下文，使"询问当前上下文"功能能获取到当前正在编辑的笔记信息
  void _updateRouteContext() {
    final isNew = _currentNote == null;
    final noteTitle = _currentNote?.title ?? '新建笔记';
    final params = <String, String>{
      'isNew': isNew.toString(),
      'noteTitle': noteTitle,
    };

    // 如果是编辑现有笔记，添加笔记ID
    if (!isNew) {
      params['noteId'] = _currentNote!.id;
    }

    final title = isNew ? '新建笔记' : '编辑笔记 - $noteTitle';

    RouteHistoryManager.updateCurrentContext(
      pageId: '/note_edit',
      title: title,
      params: params,
    );
  }

  /// 样式设置抽屉（背景风格 / 颜色 / 图标），仅编辑已有笔记时提供
  void _showStyleSheet() {
    final note = _currentNote;
    if (note == null) return;
    final style = NoteStyleSelection(
      color: note.color,
      bgStyle: note.bgStyle,
      icon: note.icon,
    );
    SmoothBottomSheet.show(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'notes_styleSettings'.tr,
                style: DsTypography.title,
              ),
              const SizedBox(height: 12),
              NoteColorPickerRow(
                selected: style.color,
                selectedStyle: style.bgStyle,
                selectedIcon: style.icon,
                onChanged: (color) =>
                    setSheetState(() => style.color = color),
                onStyleChanged: (value) =>
                    setSheetState(() => style.bgStyle = value),
                onIconChanged: (icon) =>
                    setSheetState(() => style.icon = icon),
              ),
              const SizedBox(height: 12),
              DSButton(
                label: 'app_save'.tr,
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  note.color = style.color;
                  note.bgStyle = style.bgStyle;
                  note.icon = style.icon;
                  await NotesPlugin.instance.controller.updateNote(note);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final note = _currentNote;
    return RichEditorScreen(
      reloadToken: _contentVersion,
      onOpenStyleSettings: _currentNote != null ? _showStyleSheet : null,
      initialTitle: note?.title ?? '',
      initialContent: note?.content ?? '',
      initialTags: note?.tags ?? const [],
      eyebrow: note != null
          ? DateFormat.yMMMMd(
              Localizations.localeOf(context).toString(),
            ).format(note.updatedAt)
          : null,
      texts: RichEditorTexts(
        untitled: 'notes_untitled'.tr,
        emptyContent: 'notes_emptyContent'.tr,
        editTooltip: 'app_edit'.tr,
        deleteTooltip: 'notes_delete'.tr,
        confirmDeleteTitle: 'notes_deleteNote'.tr,
        confirmDeleteMessage: 'notes_deleteNoteConfirm'.tr,
        confirmDelete: 'notes_delete'.tr,
        save: 'app_save'.tr,
        titleHint: 'notes_titleHint'.tr,
        contentHint: 'notes_contentHint'.tr,
      ),
      onSave: (title, content, tags) async {
        await widget.onSave(title, content, tags);
      },
      onDelete: note != null
          ? () => NotesPlugin.instance.controller.deleteNote(note.id)
          : null,
    );
  }
}
