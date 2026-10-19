import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/calendar_album/models/calendar_entry.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/swipe_action/index.dart';

class EntryList extends StatelessWidget {
  Widget _buildDefaultCover(BuildContext context) {
    final theme = AppTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        borderRadius: theme.radii.sm,
      ),
      child: Center(child: DsIcon(DsIconKind.image, color: theme.textSub)),
    );
  }

  Widget _buildImage(BuildContext context, String url) {
    if (url.isEmpty) {
      return _buildDefaultCover(context);
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return ClipRRect(
        borderRadius: AppTheme.of(context).radii.sm,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading network image: $error');
            return _buildDefaultCover(context);
          },
        ),
      );
    }

    return FutureBuilder<String>(
      future: ImageUtils.getAbsolutePath(url),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final file = File(snapshot.data!);
          if (file.existsSync()) {
            return ClipRRect(
              borderRadius: AppTheme.of(context).radii.sm,
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Error loading local image: $error');
                  return _buildDefaultCover(context);
                },
              ),
            );
          }
        }
        return _buildDefaultCover(context);
      },
    );
  }

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
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Padding(
          // 垂直间距 ≥16，给滑动贴条出血留空间
          padding: const EdgeInsets.only(bottom: 16),
          child: SwipeActionWrapper(
            key: ValueKey('entry_${entry.id}'),
            leadingActions: [
              SwipeActionPresets.edit(onTap: () => onEdit(entry)),
            ],
            trailingActions: [
              SwipeActionPresets.delete(onTap: () => onDelete(entry)),
            ],
            child: _buildEntryCard(context, entry),
          ),
        );
      },
    );
  }

  /// 日记卡片：手绘纸卡 + 心情/天气/标签胶囊（按文本稳定取色）
  Widget _buildEntryCard(BuildContext context, CalendarEntry entry) {
    final theme = AppTheme.of(context);

    return DSCard(
      onTap: () => onTap(entry),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.title,
                  style: DsTypography.heading.copyWith(color: theme.text),
                ),
              ),
              if (entry.mood != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: DSBadge(
                    label: entry.mood!,
                    autoColor: true,
                    fontSize: 10,
                  ),
                ),
              if (entry.weather != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: DSBadge(
                    label: entry.weather!,
                    autoColor: true,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          if (entry.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: entry.imageUrls.length,
              itemBuilder: (context, index) {
                return _buildImage(context, entry.imageUrls[index]);
              },
            ),
          ],
          if (entry.content.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              entry.content,
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
          ],
          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...entry.tags.map(
                  (tag) => DSBadge(label: tag, autoColor: true, fontSize: 10),
                ),
              ],
            ),
          ],
          if (entry.location != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DsIcon(DsIconKind.pin, size: 14, color: theme.textSub),
                const SizedBox(width: 4),
                Text(
                  entry.location!,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
