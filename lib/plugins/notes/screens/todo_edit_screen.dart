import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/models/note.dart';
import 'package:aboutme/plugins/notes/models/todo_item.dart';
import 'package:aboutme/plugins/notes/widgets/note_color_picker.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 待办编辑底部抽屉：标题 + 勾选清单条目（支持拖拽排序）
class TodoEditSheet extends StatefulWidget {
  final Note? note;
  final Function(
    String title,
    List<TodoItem> items,
    TodoMeta meta,
    Color? color,
    int bgStyle,
  ) onSave;

  const TodoEditSheet({super.key, this.note, required this.onSave});

  /// 显示待办编辑底部抽屉（新建/编辑统一入口）
  static Future<void> show({
    required BuildContext context,
    Note? note,
    required Future<void> Function(
      String title,
      List<TodoItem> items,
      TodoMeta meta,
      Color? color,
      int bgStyle,
    ) onSave,
  }) {
    return SmoothBottomSheet.show(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: TodoEditSheet(note: note, onSave: onSave),
      ),
    );
  }

  @override
  State<TodoEditSheet> createState() => _TodoEditSheetState();
}

class _TodoEditSheetState extends State<TodoEditSheet> {
  late final TextEditingController _titleController;
  late List<TextEditingController> _itemControllers;
  late List<bool> _checkedStates;
  late List<FocusNode> _itemFocusNodes;
  late TodoMeta _meta;
  Color? _pickedColor;
  int _bgStyle = 0;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    final items = TodoItem.parseList(widget.note?.content ?? '');
    if (items.isEmpty) items.add(TodoItem(text: ''));
    _itemControllers = items.map((item) => TextEditingController(text: item.text)).toList();
    _checkedStates = items.map((item) => item.checked).toList();
    _itemFocusNodes = List.generate(items.length, (_) => FocusNode());
    _meta = TodoMeta.parse(widget.note?.meta);
    _pickedColor = widget.note?.color;
    _bgStyle = widget.note?.bgStyle ?? 0;
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var controller in _itemControllers) {
      controller.dispose();
    }
    for (var node in _itemFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _itemControllers.add(TextEditingController());
      _checkedStates.add(false);
      _itemFocusNodes.add(FocusNode());
    });
  }

  /// 回车快速录入：在 [index] 条目后插入空行并聚焦（空条目回车不新建）
  void _insertItemAfter(int index) {
    if (_itemControllers[index].text.trim().isEmpty) return;
    setState(() {
      _itemControllers.insert(index + 1, TextEditingController());
      _checkedStates.insert(index + 1, false);
      _itemFocusNodes.insert(index + 1, FocusNode());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _itemFocusNodes[index + 1].requestFocus();
    });
  }

  void _removeItemAt(int index) {
    setState(() {
      _itemControllers.removeAt(index).dispose();
      _checkedStates.removeAt(index);
      _itemFocusNodes.removeAt(index).dispose();
    });
    if (_itemControllers.isEmpty) _addItem();
  }

  void _reorderItem(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final controller = _itemControllers.removeAt(oldIndex);
      _itemControllers.insert(newIndex, controller);
      final checked = _checkedStates.removeAt(oldIndex);
      _checkedStates.insert(newIndex, checked);
      final node = _itemFocusNodes.removeAt(oldIndex);
      _itemFocusNodes.insert(newIndex, node);
    });
  }

  void _toggleItem(int index) {
    setState(() {
      _checkedStates[index] = !_checkedStates[index];
      final text = _itemControllers[index].text.trim();
      if (text.isNotEmpty) {
        if (_checkedStates[index]) {
          _meta.markDone(text, DateTime.now());
        } else {
          _meta.doneAt.remove(text);
        }
      }
    });
  }

  void _save() async {
    final items = <TodoItem>[];
    for (var i = 0; i < _itemControllers.length; i++) {
      final text = _itemControllers[i].text.trim();
      if (text.isEmpty) continue;
      items.add(TodoItem(text: text, checked: _checkedStates[i]));
    }
    // 清理已删除条目的完成时间记录
    _meta.retainTexts(items.map((item) => item.text).toSet());
    await widget.onSave(_titleController.text, items, _meta, _pickedColor, _bgStyle);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'notes_editTodo'.tr : 'notes_newTodo'.tr,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                    ),
                    DSIconButton(
                      icon: DsIconKind.check,
                      size: 36,
                      color: theme.surface,
                      iconColor: theme.text,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _titleController,
                  autofocus: !_isEditing,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) {
                    // 标题回车流转到第一个条目
                    if (_itemFocusNodes.isNotEmpty) {
                      _itemFocusNodes.first.requestFocus();
                    }
                  },
                  style: DsTypography.title.copyWith(color: theme.text),
                  decoration: InputDecoration(
                    hintText: 'notes_todoTitleHint'.tr,
                    hintStyle: DsTypography.title.copyWith(color: theme.disabled),
                    border: InputBorder.none,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                  itemCount: _itemControllers.length,
                  onReorder: _reorderItem,
                  proxyDecorator: (child, index, animation) => Material(
                    color: Colors.transparent,
                    child: ScaleTransition(scale: animation.drive(Tween(begin: 1.02, end: 1.0)), child: child),
                  ),
                  itemBuilder: (context, index) => _buildItemRow(context, index),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: NoteColorPickerRow(
                  selected: _pickedColor,
                  selectedStyle: _bgStyle,
                  onChanged: (color) => setState(() => _pickedColor = color),
                  onStyleChanged: (style) => setState(() => _bgStyle = style),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: DSButton(
                  label: 'notes_todoAddItem'.tr,
                  icon: DsIconKind.plus,
                  variant: DSButtonVariant.outline,
                  size: DSButtonSize.sm,
                  onPressed: _addItem,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, int index) {
    final theme = DSThemeBridge.resolve(context);
    final doneAt = _meta.doneAtOf(_itemControllers[index].text.trim());
    return Container(
      key: ValueKey(_itemControllers[index]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: DsIcon(DsIconKind.list, size: 18, color: theme.disabled),
            ),
          ),
          DSCheckbox(
            value: _checkedStates[index],
            onChanged: (_) => _toggleItem(index),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _itemControllers[index],
                  focusNode: _itemFocusNodes[index],
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _insertItemAfter(index),
                  style: DsTypography.body.copyWith(
                    color: theme.textSub,
                    decoration: _checkedStates[index] ? TextDecoration.lineThrough : null,
                  ),
                  decoration: InputDecoration(
                    hintText: 'notes_todoItemHint'.tr,
                    hintStyle: DsTypography.body.copyWith(color: theme.disabled),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
                if (_checkedStates[index] && doneAt != null)
                  Text(
                    'notes_todoDoneAt'.trParams({
                      'time': '${doneAt.month}/${doneAt.day} ${doneAt.hour.toString().padLeft(2, '0')}:${doneAt.minute.toString().padLeft(2, '0')}',
                    }),
                    style: DsTypography.caption.copyWith(color: theme.disabled),
                  ),
              ],
            ),
          ),
          DSIconButton(
            icon: DsIconKind.trash,
            size: 30,
            color: Colors.transparent,
            iconColor: theme.textSub,
            onPressed: () => _removeItemAt(index),
          ),
        ],
      ),
    );
  }
}
