import 'package:flutter/material.dart';
import 'package:aboutme/design_system/design_system.dart';

import '../models/media_item.dart';
import 'media_cover.dart';

/// 瀑布流媒体卡片：封面（错落旋转）+ 标题/类型行
///
/// 迁移自 ai_picks_demo 的 _BookCard。
class MediaItemCard extends StatelessWidget {
  const MediaItemCard({
    super.key,
    required this.item,
    required this.seed,
    required this.rotation,
    required this.onTap,
    this.onLongPress,
  });

  final MediaItem item;
  final int seed;
  final double rotation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Pressable(
      onPressed: onTap,
      onLongPress: onLongPress,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return AnimatedScale(
          scale: pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          child: Transform.rotate(
            angle: rotation,
            child: Container(
              decoration: dsSketchDecoration(
                theme: theme,
                radius: DsRadii.md,
                seed: seed,
              ),
              child: ClipRRect(
                borderRadius: DsRadii.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 1 / item.aspect,
                      child: MediaCover(style: item.cover),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Row(
                        children: [
                          DsIcon(
                            item.kind == MediaKind.reading
                                ? DsIconKind.book
                                : DsIconKind.play,
                            size: 14,
                            color: theme.textSub,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DsTypography.body.copyWith(
                                color: theme.text,
                              ),
                            ),
                          ),
                          if (item.isFinished)
                            DsIcon(
                              DsIconKind.check,
                              size: 14,
                              color: theme.success,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 点评卡片：时间戳 + 评分 + 内容
///
/// 迁移自 ai_picks_demo 详情页的 _ReviewCard。
class MediaReviewCard extends StatelessWidget {
  const MediaReviewCard({
    super.key,
    required this.review,
    required this.seed,
    required this.onTap,
  });

  final MediaReview review;
  final int seed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final dateText =
        '${review.timestamp.year}-${review.timestamp.month.toString().padLeft(2, '0')}-${review.timestamp.day.toString().padLeft(2, '0')} '
        '${review.timestamp.hour.toString().padLeft(2, '0')}:${review.timestamp.minute.toString().padLeft(2, '0')}';

    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return AnimatedScale(
          scale: pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          child: DsSketchPanel(
            theme: theme,
            radius: DsRadii.lg,
            seed: seed,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateText,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ),
                    if (review.rating != null)
                      DSRating(value: review.rating!, size: 13),
                  ],
                ),
                if (review.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    review.text,
                    style: DsTypography.body.copyWith(color: theme.textSub),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
