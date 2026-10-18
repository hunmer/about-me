import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/models/note.dart';
import 'package:aboutme/plugins/notes/models/note_style_selection.dart';
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
    NoteStyleSelection style,
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
      NoteStyleSelection style,
    ) onSave,
  }) {
    return SmoothBottomSheet.show(
      context: context,
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
  late NoteStyleSelection _style;

  /// 当前展开的样式选择器面板；null = 全部收起
  _StylePanel? _stylePanel;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    // 过滤历史脏数据里的空条目（如仅剩勾选标记的行）
    var items = TodoItem.parseList(widget.note?.content ?? '')
        .where((item) => item.text.trim().isNotEmpty)
        .toList();
    if (items.isEmpty) items.add(TodoItem(text: ''));
    _itemControllers = items.map((item) => TextEditingController(text: item.text)).toList();
    _checkedStates = items.map((item) => item.checked).toList();
    _itemFocusNodes = List.generate(items.length, (_) => FocusNode());
    _meta = TodoMeta.parse(widget.note?.meta);
    _style = NoteStyleSelection(
      color: widget.note?.color,
      bgStyle: widget.note?.bgStyle ?? 0,
      icon: widget.note?.icon,
    );
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
      // 空白条目直接跳过，不参与提交
      if (text.isEmpty) continue;
      final checked = i < _checkedStates.length && _checkedStates[i];
      items.add(TodoItem(text: text, checked: checked));
    }
    // 清理已删除条目的完成时间记录
    _meta.retainTexts(items.map((item) => item.text).toSet());
    try {
      await widget.onSave(_titleController.text.trim(), items, _meta, _style);
    } catch (e) {
      debugPrint('TodoEditSheet save error: $e');
    } finally {
      // 保存异常也要关闭抽屉，避免提交卡死
      if (mounted) Navigator.of(context).pop();
    }
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
                child: DSButton(
                  label: 'notes_todoAddItem'.tr,
                  icon: DsIconKind.plus,
                  variant: DSButtonVariant.outline,
                  size: DSButtonSize.sm,
                  onPressed: _addItem,
                ),
              ),
              // 样式选择器面板：底部栏点击图标后在表单下方互斥展开
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _stylePanel == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: _buildStylePanel(context),
                      ),
              ),
              // 底部样式切换栏：颜色 / 背景 / 图标
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    _buildPanelToggle(
                      context,
                      _StylePanel.color,
                      DsIconKind.palette,
                      'notes_color'.tr,
                    ),
                    const SizedBox(width: 8),
                    _buildPanelToggle(
                      context,
                      _StylePanel.background,
                      DsIconKind.grid,
                      'notes_bgStyle'.tr,
                    ),
                    const SizedBox(width: 8),
                    _buildPanelToggle(
                      context,
                      _StylePanel.icon,
                      DsIconKind.mood,
                      'notes_icon'.tr,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 当前展开的样式选择器内容（同一时刻只显示一个）
  Widget _buildStylePanel(BuildContext context) {
    switch (_stylePanel) {
      case _StylePanel.color:
        return NoteColorSwatchRow(
          selected: _style.color,
          onChanged: (color) => setState(() => _style.color = color),
        );
      case _StylePanel.background:
        return DsSketchFillPickerRow(
          selected: _style.bgStyle,
          labelKey: null,
          onChanged: (style) => setState(() => _style.bgStyle = style ?? 0),
        );
      case _StylePanel.icon:
        return NoteIconPickerRow(
          selectedIcon: _style.icon,
          onChanged: (icon) => setState(() => _style.icon = icon),
        );
      case null:
        return const SizedBox.shrink();
    }
  }

  /// 底部样式切换按钮：手绘描边块，选中项主题色实底 + 反色内容
  Widget _buildPanelToggle(
    BuildContext context,
    _StylePanel panel,
    DsIconKind icon,
    String label,
  ) {
    final theme = DSThemeBridge.resolve(context);
    final active = _stylePanel == panel;
    return Expanded(
      child: GestureDetector(
        // 再次点击当前面板则收起
        onTap: () => setState(() => _stylePanel = active ? null : panel),
        child: Container(
          height: 38,
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: active ? theme.primary : null,
            radius: BorderRadius.circular(12),
            strokeWidth: active ? 2.2 : 1.5,
            seed: 300 + panel.index,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DsIcon(
                icon,
                size: 15,
                color: active ? theme.onPrimary : theme.textSub,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: DsTypography.caption.copyWith(
                  color: active ? theme.onPrimary : theme.textSub,
                ),
              ),
            ],
          ),
        ),
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

/// 样式选择器面板类型：颜色 / 背景填充 / 水印图标
enum _StylePanel { color, background, icon }
