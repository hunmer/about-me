import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/models/note.dart';
import 'package:aboutme/plugins/notes/models/todo_item.dart';
import 'package:aboutme/widgets/quill_viewer/quill_viewer.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// 待办卡片勾选回调（index 对应条目位置），为 null 时仅展示
  final ValueChanged<int>? onToggle;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onToggle,
  });

  /// 显示底部抽屉菜单
  void _showBottomSheet(BuildContext context) {
    SmoothBottomSheet.show(
      context: context,
      builder:
          (context) => DSThemeBridge(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DSSheetAction(
                  icon: DsIconKind.copy,
                  label: 'app_copy'.tr,
                  onTap: () {
                    Navigator.pop(context);
                    _copyNoteContent();
                  },
                ),
                DSSheetAction(
                  icon: DsIconKind.edit,
                  label: 'app_edit'.tr,
                  onTap: () {
                    Navigator.pop(context);
                    if (onEdit != null) {
                      onEdit!();
                    } else {
                      onTap();
                    }
                  },
                ),
                DSSheetAction(
                  icon: DsIconKind.trash,
                  label: 'app_delete'.tr,
                  destructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    onDelete?.call();
                  },
                ),
              ],
            ),
          ),
    );
  }

  /// 复制笔记内容到剪贴板
  void _copyNoteContent() {
    final textToCopy = '${note.title}\n\n${note.content}';
    Clipboard.setData(ClipboardData(text: textToCopy));
    Toast.success('已复制到剪贴板');
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    // 环境描画动画（列表项外层 WiredDraw 注入）；null = 已画完
    final progress = WiredDrawTransition.progressOf(context);
    // 墨迹按笔记稳定变化（rebuild 不抖变）
    final seed = note.id.hashCode & 0x7fffffff;

    // 待办进度统计
    final todoItems = note.isTodo ? TodoItem.parseList(note.content) : null;
    final doneCount = todoItems?.where((item) => item.checked).length ?? 0;
    final allDone = todoItems != null && todoItems.isNotEmpty && doneCount == todoItems.length;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showBottomSheet(context),
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(14),
        padding: const EdgeInsets.all(12),
        seed: seed,
        progress: progress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.title.isEmpty ? 'notes_untitled'.tr : note.title,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
            const SizedBox(height: 4),
            // 待办类型渲染勾选清单，普通笔记用 QuillViewer 只读渲染富文本
            if (note.isTodo)
              ..._buildTodoItems(theme, seed, progress)
            else
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 200, // 限制最大高度，模拟 maxLines: 8
                ),
                child: ClipRect(
                  child: DefaultTextStyle(
                    style: DsTypography.body.copyWith(color: theme.textSub),
                    child: QuillViewer(
                      data: note.content,
                      selectable: false,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (todoItems != null)
                  _buildChip(
                    theme: theme,
                    icon: allDone ? DsIconKind.check : DsIconKind.calendarCheck,
                    label: '$doneCount/${todoItems.length}',
                    seed: seed,
                    progress: progress,
                    highlighted: allDone,
                  ),
                if (note.tags.isNotEmpty)
                  ...note.tags.take(3).map(
                    (tag) => _buildChip(
                      theme: theme,
                      icon: DsIconKind.tag,
                      label: tag,
                      seed: seed,
                      progress: progress,
                    ),
                  ),
                if (note.tags.isEmpty && todoItems == null)
                  _buildChip(
                    theme: theme,
                    icon: DsIconKind.calendar,
                    label: DateFormat('MMM d').format(note.updatedAt),
                    seed: seed,
                    progress: progress,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 待办清单渲染：最多显示 6 条，超出部分显示剩余数量
  List<Widget> _buildTodoItems(
    AppThemeData theme,
    int seed,
    Animation<double>? progress,
  ) {
    final items = TodoItem.parseList(note.content);
    final visible = items.take(6).toList();
    return [
      for (var i = 0; i < visible.length; i++)
        _buildTodoRow(theme, visible[i], seed, progress,
            onToggle: onToggle != null ? () => onToggle!(i) : null),
      if (items.length > visible.length)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'notes_todoMoreItems'.trParams(
                {'count': '${items.length - visible.length}'}),
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ),
    ];
  }

  Widget _buildTodoRow(
    AppThemeData theme,
    TodoItem item,
    int seed,
    Animation<double>? progress, {
    VoidCallback? onToggle,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(top: 1),
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: item.checked ? theme.primary : null,
                radius: BorderRadius.circular(5),
                strokeWidth: 1.6,
                seed: seed,
                progress: progress,
              ),
              child: item.checked
                  ? Center(
                      child: DsIcon(
                        DsIconKind.check,
                        size: 12,
                        color: theme.onPrimary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DsTypography.body.copyWith(
                  color: theme.textSub,
                  decoration: item.checked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 手绘徽章：胶囊实底 + 墨线描边
  Widget _buildChip({
    required AppThemeData theme,
    required DsIconKind icon,
    required String label,
    required int seed,
    Animation<double>? progress,
    bool highlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: highlighted ? theme.primary : theme.surfaceAlt,
        radius: BorderRadius.circular(999),
        strokeWidth: 1.4,
        seed: seed,
        progress: progress,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIcon(
            icon,
            size: 13,
            color: highlighted ? theme.onPrimary : theme.textSub,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: DsTypography.caption.copyWith(
              fontWeight: FontWeight.w500,
              color: highlighted ? theme.onPrimary : theme.textSub,
            ),
          ),
        ],
      ),
    );
  }
}
