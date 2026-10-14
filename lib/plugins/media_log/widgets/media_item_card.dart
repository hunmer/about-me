import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/adaptive_image.dart';

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
    // 环境描画动画（外层 WiredDraw 注入）；null = 已画完
    final drawProgress = WiredDrawTransition.progressOf(context);
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
                progress: drawProgress,
              ),
              child: ClipRRect(
                borderRadius: DsRadii.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero 飞行时圆角随行：ClipRRect 放进 hero child 内
                    Hero(
                      tag: item.coverHeroTag,
                      child: ClipRRect(
                        borderRadius: DsRadii.md,
                        child: AspectRatio(
                          aspectRatio: 1 / item.aspect,
                          child: MediaCoverView(item: item),
                        ),
                      ),
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

/// 点评卡片：头像 + 点评人 + 时间戳 + 评分 + 内容
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

  String get _displayName => review.author ?? 'media_me'.tr;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // 环境描画动画（外层 WiredDraw 注入）；null = 已画完
    final drawProgress = WiredDrawTransition.progressOf(context);
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
            progress: drawProgress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ReviewAvatar(review: review, displayName: _displayName),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName,
                            style: DsTypography.heading.copyWith(
                              fontSize: 13,
                              color: theme.text,
                            ),
                          ),
                          Text(
                            dateText,
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                        ],
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

/// 点评人头像：上传图片（圆形）或首字母墨盒
class _ReviewAvatar extends StatelessWidget {
  const _ReviewAvatar({required this.review, required this.displayName});

  final MediaReview review;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final avatar = review.avatar;
    if (avatar != null && avatar.isNotEmpty) {
      return SizedBox(
        width: 34,
        height: 34,
        child: ClipOval(
          child: AdaptiveImage(
            imagePath: avatar,
            fit: BoxFit.cover,
            borderRadius: 0,
          ),
        ),
      );
    }
    final initial = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().substring(0, 1);
    return JellyBox(
      color: theme.surfaceAlt,
      radius: DsRadii.circle,
      width: 34,
      height: 34,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: DsTypography.heading.copyWith(color: theme.primary),
      ),
    );
  }
}
