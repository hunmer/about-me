import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/models/note.dart';
import 'package:aboutme/plugins/notes/models/note_style_selection.dart';
import 'package:aboutme/plugins/notes/models/todo_item.dart';
import 'package:aboutme/plugins/notes/widgets/note_color_picker.dart';
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

  /// 长按菜单「颜色」入口回调（改样式后由外部持久化刷新）
  final ValueChanged<NoteStyleSelection>? onEditStyle;

  /// 归档/取消归档回调（null 时不显示菜单项）
  final VoidCallback? onToggleArchive;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onToggle,
    this.onEditStyle,
    this.onToggleArchive,
  });

  /// 显示底部抽屉菜单
  void _showBottomSheet(BuildContext context) {
    SmoothBottomSheet.show(
      context: context,
      builder: (context) => DSThemeBridge(
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
            if (onEditStyle != null)
              DSSheetAction(
                icon: DsIconKind.palette,
                label: 'notes_color'.tr,
                onTap: () {
                  Navigator.pop(context);
                  _showStyleEditor(context);
                },
              ),
            if (onToggleArchive != null)
              DSSheetAction(
                icon: DsIconKind.archive,
                label: note.isArchived
                    ? 'notes_unarchive'.tr
                    : 'notes_archive'.tr,
                onTap: () {
                  Navigator.pop(context);
                  onToggleArchive!();
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

  /// 样式编辑抽屉（标记色 / 背景风格 / 水印图标）
  void _showStyleEditor(BuildContext context) {
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
              Text('notes_color'.tr, style: DsTypography.title),
              const SizedBox(height: 12),
              NoteColorPickerRow(
                selected: style.color,
                selectedStyle: style.bgStyle,
                selectedIcon: style.icon,
                onChanged: (color) => setSheetState(() => style.color = color),
                onStyleChanged: (value) =>
                    setSheetState(() => style.bgStyle = value),
                onIconChanged: (icon) => setSheetState(() => style.icon = icon),
              ),
              const SizedBox(height: 12),
              DSButton(
                label: 'app_save'.tr,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  onEditStyle!(style);
                },
              ),
            ],
          ),
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

    // 背景填充风格（排线/交叉/点/之字/横线/实底）
    final fillStyle = DsSketchFill
        .values[note.bgStyle.clamp(0, DsSketchFill.values.length - 1)];
    // 实底彩色背景下文字按合成亮度切换深墨/纸白，保证可读
    final solidAlpha = theme.isDark ? 0.55 : 0.60;
    final solidBg = (fillStyle == DsSketchFill.solid && note.color != null)
        ? Color.lerp(theme.surface, note.color!, solidAlpha)
        : null;
    final contentText = solidBg == null
        ? theme.text
        : (solidBg.computeLuminance() > 0.5 ? DsColors.text : theme.paper);
    final contentSub = solidBg == null
        ? theme.textSub
        : contentText.withValues(alpha: 0.75);

    // 待办进度统计
    final todoItems = note.isTodo ? TodoItem.parseList(note.content) : null;
    final doneCount = todoItems?.where((item) => item.checked).length ?? 0;
    final allDone =
        todoItems != null &&
        todoItems.isNotEmpty &&
        doneCount == todoItems.length;

    final watermarkIcon = note.iconKind;

    // 参考 DSListItemCard：ClipRRect + Stack（底色 / 填充墨线 / 右上角水印 / 内容），
    // 水印位于内容层之下，溢出被裁剪
    final radius = BorderRadius.circular(14);

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showBottomSheet(context),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // 纸底
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: theme.surface),
              ),
            ),
            // 背景填充 + 墨线框（排线/交叉/点/之字/横线/实底）
            Positioned.fill(
              child: DecoratedBox(
                decoration: dsSketchDecoration(
                  theme: theme,
                  radius: radius,
                  fillStyle: fillStyle,
                  fillColor: fillStyle == DsSketchFill.solid
                      ? (note.color?.withValues(alpha: solidAlpha) ??
                            theme.hatch)
                      : DsColors.transparent,
                  hachureColor: note.color?.withValues(
                    alpha: theme.isDark ? 0.60 : 0.70,
                  ),
                  seed: seed,
                  progress: progress,
                ),
              ),
            ),
            // 右上角图标水印：放大贴角，标记色优先
            if (watermarkIcon != null)
              Positioned(
                right: 0,
                top: 0,
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Opacity(
                      opacity: 0.15,
                      child: DsIcon(
                        watermarkIcon,
                        color: note.color ?? theme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            // 右上角打孔：填充页面背景色模拟挖穿 + 手绘墨线孔缘，贴纸质感
            Positioned(
              right: 10,
              top: 10,
              child: IgnorePointer(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: dsSketchDecoration(
                    theme: theme,
                    fillColor: theme.background,
                    circle: true,
                    strokeWidth: 1.6,
                    seed: seed,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.isEmpty ? 'notes_untitled'.tr : note.title,
                    style: DsTypography.title.copyWith(color: contentText),
                  ),
                  const SizedBox(height: 4),
                  // 待办类型渲染勾选清单，普通笔记用 QuillViewer 只读渲染富文本
                  // 内容底部渐隐（参考便签墙的淡出效果，暗示还有更多内容）
                  if (note.isTodo)
                    ..._buildTodoItems(theme, contentSub, seed, progress)
                  else
                    ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.75, 1.0],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 200, // 限制最大高度，模拟 maxLines: 8
                        ),
                        child: ClipRect(
                          child: DefaultTextStyle(
                            style: DsTypography.body.copyWith(
                              color: contentSub,
                            ),
                            child: QuillViewer(
                              data: note.content,
                              selectable: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // 待办进度 / 标签徽章
                  if (todoItems != null || note.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          if (todoItems != null)
                            _buildChip(
                              theme: theme,
                              icon: allDone
                                  ? DsIconKind.check
                                  : DsIconKind.calendarCheck,
                              label: '$doneCount/${todoItems.length}',
                              seed: seed,
                              progress: progress,
                              highlighted: allDone,
                            ),
                          ...note.tags
                              .take(3)
                              .map(
                                (tag) => _buildChip(
                                  theme: theme,
                                  icon: DsIconKind.tag,
                                  label: tag,
                                  seed: seed,
                                  progress: progress,
                                ),
                              ),
                        ],
                      ),
                    ),
                  // 底部行：左侧日期（便签墙样式），右侧 ··· 呼出菜单
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat(
                            'EEE, d MMM yy',
                          ).format(note.updatedAt).toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DsTypography.caption.copyWith(
                            color: contentSub,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showBottomSheet(context),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: DsIcon(
                            DsIconKind.dots,
                            size: 18,
                            color: contentSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 待办清单渲染：最多显示 6 条，超出部分显示剩余数量
  List<Widget> _buildTodoItems(
    AppThemeData theme,
    Color subColor,
    int seed,
    Animation<double>? progress,
  ) {
    final items = TodoItem.parseList(note.content);
    final visible = items.take(6).toList();
    return [
      for (var i = 0; i < visible.length; i++)
        _buildTodoRow(
          theme,
          visible[i],
          subColor,
          seed,
          progress,
          onToggle: onToggle != null ? () => onToggle!(i) : null,
        ),
      if (items.length > visible.length)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'notes_todoMoreItems'.trParams({
              'count': '${items.length - visible.length}',
            }),
            style: DsTypography.caption.copyWith(color: subColor),
          ),
        ),
    ];
  }

  Widget _buildTodoRow(
    AppThemeData theme,
    TodoItem item,
    Color subColor,
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
                  color: subColor,
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
