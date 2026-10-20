import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/calendar_album/models/calendar_entry.dart';
import 'package:aboutme/plugins/diary/widgets/diary_mood_face.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/linked_task_flow_card.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/walk_stack_card.dart';
import 'package:aboutme/utils/image_utils.dart';

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

/// 卡内照片堆缩放（基准卡 282×348，实际由 FittedBox 再自适应卡面）
const double _photoStackScale = 0.3;

/// 内嵌照片堆后调高的单卡高度（基准 px）
const double _entryCardHeight = 240;

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

  Widget _buildList(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        // 连线卡片：心情表情 + 名称胶囊 + 信息胶囊 + 卡内照片堆（主题配色）
        LinkedTaskFlowCardWidget(
          backgroundFrom: theme.surfaceAlt,
          backgroundTo: theme.surfaceAlt,
          cardColor: theme.surface,
          connectorColor: theme.primary,
          showStripes: false,
          cardHeight: _entryCardHeight,
          items: [
            for (final entry in entries)
              LinkedTaskItemData(
                title: '',
                // 日记注释（正文摘要）显示到底部内容行
                assignee: entry.content,
                assignLabel: '',
                showProgress: false,
                // 名称显示到顶部胶囊
                badgeText: entry.title,
                avatar:
                    entry.mood != null
                        ? DiaryMoodFaceCircle(
                          spec: diaryMoodSpecOf(
                            _moodEmojiMap[entry.mood!] ?? entry.mood!,
                          ),
                          size: 38,
                        )
                        : null,
                avatarIcon: entry.mood == null ? Icons.menu_book : null,
                chips: [
                  if (entry.location != null) entry.location!,
                  if (entry.weather != null)
                    'calendar_album_weather_${entry.weather!.toLowerCase()}'
                        .tr,
                  ...entry.tags.take(2),
                ],
                // 卡内照片堆：该日记图片一图一卡，可拖拽切换
                photoStack:
                    entry.imageUrls.isNotEmpty
                        ? _buildPhotoStack(entry)
                        : null,
              ),
          ],
          onItemTap: (index) => onTap(entries[index]),
        ),
      ],
    );
  }

  /// 照片堆叠卡（参考 ImageStackMessageWidget）：一图一卡，
  /// 拖拽顶层卡切换，点击图片卡打开所属日记
  Widget _buildPhotoStack(CalendarEntry entry) {
    final images = entry.imageUrls;

    return WalkStackCardWidget(
      cards: [
        for (var i = 0; i < images.length; i++)
          WalkStackCardData(
            id: 'album_${entry.id}_$i',
            quote: '',
            imagePaths: [images[i]],
          ),
      ],
      size: const SmallSize(scale: _photoStackScale),
      // 纸底已是浅色，磨砂意义不大且省 BackdropFilter 开销
      frosted: false,
      cardBuilder:
          (context, card) => _buildPhotoCardFace(
            card.imagePaths.first,
            images.length,
            () => onTap(entry),
          ),
    );
  }

  /// 图片卡面：图片铺满 + 左下 "+N" 照片数角标
  Widget _buildPhotoCardFace(String path, int total, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: ImageUtils.createImageProvider(path),
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) => ColoredBox(
                  color: Colors.black.withValues(alpha: 0.08),
                  child: const Center(child: DsIcon(DsIconKind.image, size: 24)),
                ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DsIcon(DsIconKind.image, size: 12, color: Colors.white),
                  const SizedBox(width: 3),
                  Text(
                    '+$total',
                    style: DsTypography.caption.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
