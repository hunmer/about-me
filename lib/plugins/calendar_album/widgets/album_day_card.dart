import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/widgets/day_card_header.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/plugins/calendar_album/models/calendar_entry.dart';

/// 日记相册单日卡片 - 展示某一天的相册条目与照片缩略图
///
/// 供主页相册日卡使用：条目标题/缩略图，
/// 点击条目进入详情（与插件页一致）。
class AlbumDayCard extends StatelessWidget {
  /// 卡片对应的日期
  final DateTime date;

  /// 该日的相册条目
  final List<CalendarEntry> entries;

  /// 点击条目回调（进入详情）
  final Function(CalendarEntry entry) onEntryTap;

  /// 新建条目回调（预填该日日期），为 null 时不显示 ＋ 按钮
  final Function(DateTime)? onAddEntry;

  /// 头部主题色
  final Color color;

  const AlbumDayCard({
    super.key,
    required this.date,
    required this.entries,
    required this.onEntryTap,
    this.onAddEntry,
    this.color = const Color.fromARGB(255, 245, 210, 52),
  });

  @override
  Widget build(BuildContext context) {
    final dsTheme = DSThemeBridge.resolve(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: dsSketchDecoration(
          theme: dsTheme,
          fillColor: dsTheme.surface,
          radius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DayCardHeader(
              color: color,
              date: date,
              count: entries.length,
              onAdd: onAddEntry == null ? null : () => onAddEntry!(date),
            ),
            Expanded(
              child:
                  entries.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DsIcon(
                              DsIconKind.image,
                              size: 32,
                              color: dsTheme.disabled.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'calendar_album_dayCardEmpty'.tr,
                              style: TextStyle(
                                color: dsTheme.disabled.withValues(
                                  alpha: 0.4,
                                ),
                                fontSize: 12,
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
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          return _buildEntryItem(context, entries[index]);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  /// 单条目行：标题 + 缩略图行
  Widget _buildEntryItem(BuildContext context, CalendarEntry entry) {
    final theme = Theme.of(context);
    final dsTheme = DSThemeBridge.resolve(context);
    final images = _imagesFor(entry);

    return InkWell(
      onTap: () => onEntryTap(entry),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (entry.mood != null && entry.mood!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(entry.mood!, style: const TextStyle(fontSize: 14)),
                ],
              ],
            ),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    for (var i = 0; i < images.length && i < 3; i++)
                      Padding(
                        padding: EdgeInsets.only(right: i == 2 ? 0 : 4),
                        child: _buildThumbnail(images[i]),
                      ),
                    if (images.length > 3)
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: dsSketchDecoration(
                          theme: dsTheme,
                          fillColor: dsTheme.surfaceAlt,
                          radius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+${images.length - 3}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: dsTheme.textSub,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 条目图片（优先缩略图，其次原图，与相册页一致）
  List<String> _imagesFor(CalendarEntry entry) {
    // 空字符串缩略图为占位（平台不支持压缩时），需过滤后回退原图
    final thumbs = entry.thumbUrls.where((t) => t.isNotEmpty).toList();
    if (thumbs.isNotEmpty) return thumbs;
    if (entry.imageUrls.isNotEmpty) return entry.imageUrls;
    return entry.extractImagesFromMarkdown();
  }

  /// 单张缩略图（相对路径异步解析为本地文件）
  Widget _buildThumbnail(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FutureBuilder<String>(
        future: ImageUtils.getAbsolutePath(imageUrl),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.file(
              File(snapshot.data!),
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(context),
            );
          }
          return _placeholder(context);
        },
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final dsTheme = DSThemeBridge.resolve(context);
    return Container(
      width: 52,
      height: 52,
      color: dsTheme.surfaceAlt,
      child: DsIcon(DsIconKind.image, size: 18, color: dsTheme.disabled),
    );
  }
}
