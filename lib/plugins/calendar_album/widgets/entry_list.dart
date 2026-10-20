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

/// 图片堆卡片缩放（基准卡 282×348，适配抽屉宽度）
const double _photoStackScale = 0.5;

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // 连线卡片：心情表情 + 名称胶囊 + 信息胶囊（主题配色，不用橘色默认）
          Expanded(
            child: LinkedTaskFlowCardWidget(
              inline: true,
              backgroundFrom: theme.surfaceAlt,
              backgroundTo: theme.surfaceAlt,
              cardColor: theme.surface,
              connectorColor: theme.primary,
              showStripes: false,
              items: [
                for (final entry in entries)
                  LinkedTaskItemData(
                    title: '',
                    assignee: '',
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
                  ),
              ],
              onItemTap: (index) => onTap(entries[index]),
            ),
          ),
          if (_hasPhotos) ...[
            const SizedBox(height: 12),
            _buildPhotoStack(),
          ],
        ],
      ),
    );
  }

  /// 当天是否有图片可堆叠
  bool get _hasPhotos => entries.any((e) => e.imageUrls.isNotEmpty);

  /// 照片堆叠卡（参考 ImageStackMessageWidget）：当天全部图片一图一卡，
  /// 拖拽顶层卡切换，点击图片卡打开所属日记
  Widget _buildPhotoStack() {
    // 卡片 id -> (所属日记, 图片路径)
    final cardMeta = <String, MapEntry<CalendarEntry, String>>{};
    final cards = <WalkStackCardData>[];
    for (final entry in entries) {
      for (var i = 0; i < entry.imageUrls.length; i++) {
        final id = 'album_${entry.id}_$i';
        cardMeta[id] = MapEntry(entry, entry.imageUrls[i]);
        cards.add(
          WalkStackCardData(id: id, quote: '', imagePaths: [entry.imageUrls[i]]),
        );
      }
    }
    final total = cards.length;

    return WalkStackCardWidget(
      cards: cards,
      size: const SmallSize(scale: _photoStackScale),
      // 抽屉底为纯色，磨砂意义不大且省 BackdropFilter 开销
      frosted: false,
      cardBuilder: (context, card) {
        final meta = cardMeta[card.id]!;
        return _buildPhotoCardFace(
          meta.value,
          total,
          () => onTap(meta.key),
        );
      },
    );
  }

  /// 图片卡面：图片铺满 + 左下 "+N" 照片数角标
  Widget _buildPhotoCardFace(
    String path,
    int total,
    VoidCallback onTap,
  ) {
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
                  child: const Center(
                    child: DsIcon(DsIconKind.image, size: 24),
                  ),
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
