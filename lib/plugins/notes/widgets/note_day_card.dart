import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/widgets/day_card_header.dart';
import 'package:aboutme/plugins/notes/models/note.dart';

/// 笔记单日卡片 - 展示某一天创建/修改的笔记
///
/// 供主页笔记日卡使用：标题/时间，
/// 点击笔记进入编辑（与插件页一致）。
class NoteDayCard extends StatelessWidget {
  /// 卡片对应的日期
  final DateTime date;

  /// 该日的笔记列表（由调用方按日期过滤并排序）
  final List<Note> notes;

  /// 点击笔记回调（打开编辑）
  final Function(Note note) onNoteTap;

  /// 新建笔记回调，为 null 时不显示 ＋ 按钮
  final VoidCallback? onAddNote;

  /// 头部主题色
  final Color color;

  const NoteDayCard({
    super.key,
    required this.date,
    required this.notes,
    required this.onNoteTap,
    this.onAddNote,
    this.color = const Color.fromARGB(255, 61, 204, 185),
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    // 手绘墨线卡片容器(design.md §9),裁剪改外包 ClipRRect(参考 date_view_grid._buildCard)
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surface,
          radius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DayCardHeader(
              color: color,
              date: date,
              count: notes.length,
              onAdd: onAddNote,
            ),
            Expanded(
              child: notes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DsIcon(
                            DsIconKind.book,
                            size: 32,
                            color: theme.textSub.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'notes_dayCardEmpty'.tr,
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        return _buildNoteItem(context, notes[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 单条笔记行：图标 + 标题/标签 + 时间
  Widget _buildNoteItem(BuildContext context, Note note) {
    final theme = DSThemeBridge.resolve(context);

    return InkWell(
      onTap: () => onNoteTap(note),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            DsIcon(DsIconKind.book, size: 18, color: theme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                note.title.isNotEmpty ? note.title : 'notes_dayCardUntitled'.tr,
                style: DsTypography.caption.copyWith(
                  color: theme.text,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (note.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '#${note.tags.first}',
                  style: DsTypography.caption.copyWith(
                    fontSize: 10,
                    color: theme.textSub,
                  ),
                ),
              ),
            Text(
              _formatTime(note.updatedAt),
              style: DsTypography.caption.copyWith(
                fontSize: 11,
                color: theme.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
