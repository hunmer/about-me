import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/calendar_album/models/calendar_entry.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/linked_task_flow_card.dart';

class EntryList extends StatelessWidget {
  final List<CalendarEntry> entries;
  final Function(CalendarEntry) onTap;
  final Function(CalendarEntry) onEdit;
  final Function(CalendarEntry) onDelete;
  final VoidCallback? onCreateNew;

  const EntryList({
    super.key,
    required this.entries,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder:
            (context) => entries.isEmpty
                ? _buildEmptyState()
                : _buildList(context),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: DSEmptyState(
        icon: DsIconKind.book,
        title: 'calendar_album_no_entries'.tr,
        actionLabel:
            onCreateNew != null ? 'calendar_album_create_new_diary'.tr : null,
        onAction: onCreateNew,
      ),
    );
  }

  /// 连线任务流卡片：每篇日记一张交错卡片，点击打开编辑
  Widget _buildList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LinkedTaskFlowCardWidget(
        inline: true,
        items: [
          for (final entry in entries)
            LinkedTaskItemData(
              title: entry.title,
              assignee: entry.location ?? entry.mood ?? '',
              progress: 100,
            ),
        ],
        onItemTap: (index) => onTap(entries[index]),
      ),
    );
  }
}
