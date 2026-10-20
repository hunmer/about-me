import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/calendar_album/models/calendar_entry.dart';
import 'package:aboutme/plugins/diary/widgets/diary_mood_face.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/linked_task_flow_card.dart';

/// 相册英文心情 -> diary 心情 emoji（复用表情图片与配色）
const _moodEmojiMap = {
  'Happy': '😊',
  'Sad': '😢',
  'Excited': '🥳',
  'Tired': '😴',
  'Calm': '😐',
  'Anxious': '😬',
  'Content': '☺️',
  'Angry': '😡',
};

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

  /// 连线任务流卡片：每篇日记一张交错卡片（心情表情 + 照片 + 标题 + 信息胶囊）
  Widget _buildList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LinkedTaskFlowCardWidget(
        inline: true,
        items: [
          for (final entry in entries)
            LinkedTaskItemData(
              title: entry.title,
              assignee: '',
              showProgress: false,
              // 胶囊文字槽：天气（无天气留空）
              badgeText:
                  entry.weather != null
                      ? 'calendar_album_weather_${entry.weather!.toLowerCase()}'
                            .tr
                      : null,
              // 头像槽：心情表情脸
              avatar:
                  entry.mood != null
                      ? DiaryMoodFaceCircle(
                        spec: diaryMoodSpecOf(
                          _moodEmojiMap[entry.mood!] ?? entry.mood!,
                        ),
                        size: 38,
                      )
                      : null,
              avatarIcon:
                  entry.mood == null ? Icons.menu_book : null,
              // 照片槽：首图
              photo:
                  entry.imageUrls.isNotEmpty
                      ? ImageUtils.createImageProvider(entry.imageUrls.first)
                      : null,
              // 文本胶囊槽位：位置 + 标签
              chips: [
                if (entry.location != null) entry.location!,
                ...entry.tags.take(2),
              ],
            ),
        ],
        onItemTap: (index) => onTap(entries[index]),
      ),
    );
  }
}
