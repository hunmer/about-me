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

/// 单卡高度（基准 px，需容纳信息行 + 正文 + 照片堆）
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
        // 连线卡片：组件仅提供交错布局 + 贝塞尔连线，卡面由 cardBuilder 外置
        LinkedTaskFlowCardWidget(
          backgroundFrom: Colors.transparent,
          backgroundTo: Colors.transparent,
          cardColor: theme.surface,
          connectorColor: theme.primary,
          showStripes: false,
          cardHeight: _entryCardHeight,
          items: [
            // cardBuilder 模式下仅作条目元数据（计数与宽度轮换）
            for (final entry in entries)
              LinkedTaskItemData(title: entry.title, assignee: ''),
          ],
          onItemTap: (index) => onTap(entries[index]),
          cardBuilder:
              (context, index) => _buildEntryCardFace(context, entries[index]),
        ),
      ],
    );
  }

  /// 日记卡面（手绘墨盒）：心情脸 + 标题 / 信息徽章 / 正文摘要 / 照片堆
  Widget _buildEntryCardFace(BuildContext context, CalendarEntry entry) {
    final theme = DSThemeBridge.resolve(context);
    final chips = <Widget>[
      if (entry.location != null)
        DSBadge(label: entry.location!, autoColor: true, fontSize: 10),
      if (entry.weather != null)
        DSBadge(
          label: 'calendar_album_weather_${entry.weather!.toLowerCase()}'.tr,
          autoColor: true,
          fontSize: 10,
        ),
      ...entry.tags.take(2).map(
        (tag) => DSBadge(label: tag, autoColor: true, fontSize: 10),
      ),
    ];

    return JellyBox(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (entry.mood != null) ...[
                DiaryMoodFaceCircle(
                  spec: diaryMoodSpecOf(
                    _moodEmojiMap[entry.mood!] ?? entry.mood!,
                  ),
                  size: 28,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: chips),
          ],
          if (entry.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              entry.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
          ],
          // 该日记的照片堆：一图一卡，可拖拽切换
          if (entry.imageUrls.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(child: FittedBox(child: _buildPhotoStack(entry))),
              ),
            ),
        ],
      ),
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
      // 图片卡圆角（含角标一起裁剪）
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
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
      ),
    );
  }
}
