import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/design_system/design_system.dart';

import '../models/media_item.dart';
import 'media_cover.dart';

/// 媒体记录单列列表行：封面缩略 + 标题/作者 + 评分/完成态（纯展示）
///
/// 滑动操作（编辑/删除）由调用方通过 [SwipeActionWrapper] 包裹注入。
class MediaItemListTile extends StatelessWidget {
  const MediaItemListTile({
    super.key,
    required this.item,
    required this.seed,
    required this.onTap,
  });

  final MediaItem item;
  final int seed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    final tile = Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return AnimatedScale(
          scale: pressed ? 0.99 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: theme.surface,
              radius: DsRadii.lg,
              seed: seed,
            ),
            child: Row(
              children: [
                // 封面缩略
                ClipRRect(
                  borderRadius: DsRadii.sm,
                  child: SizedBox(
                    width: 48,
                    height: 66,
                    child: MediaCoverView(item: item),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                              style: DsTypography.heading.copyWith(
                                fontSize: 14,
                                color: theme.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.author != null && item.author!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.author!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                        ),
                      ],
                      if (item.tags.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final tag in item.tags.take(3))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: dsSketchDecoration(
                                  theme: theme,
                                  fillColor: theme.surfaceAlt,
                                  radius: BorderRadius.circular(6),
                                  seed: seed,
                                ),
                                child: Text(
                                  tag,
                                  style: DsTypography.caption.copyWith(
                                    fontSize: 10,
                                    color: theme.textSub,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 评分 + 完成态
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (item.rating != null)
                      Row(
                        children: [
                          DsIcon(DsIconKind.star, size: 12, color: theme.warning),
                          const SizedBox(width: 3),
                          Text(
                            item.rating!.toStringAsFixed(1),
                            style: DsTypography.body.copyWith(
                              color: theme.text,
                            ),
                          ),
                        ],
                      ),
                    if (item.isFinished)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: DsIcon(
                          DsIconKind.check,
                          size: 14,
                          color: theme.success,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return tile;
  }
}
