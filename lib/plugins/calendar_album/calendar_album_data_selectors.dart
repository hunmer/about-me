part of 'calendar_album_plugin.dart';

/// 注册数据选择器
///
/// 两步选择：有记录的日期 -> 当日条目
void _registerDataSelectors() {
  pluginDataSelectorService.registerSelector(
    SelectorDefinition(
      id: 'calendar_album.entry',
      pluginId: CalendarAlbumPlugin.instance.id,
      name: '选择相册记录',
      icon: CalendarAlbumPlugin.instance.icon,
      color: CalendarAlbumPlugin.instance.color,
      searchable: true,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'date',
          title: '选择日期',
          viewType: SelectorViewType.list,
          isFinalStep: false,
          dataLoader: (_) async {
            final entries =
                CalendarAlbumPlugin.instance.calendarController?.entries ??
                    const <DateTime, List<CalendarEntry>>{};
            if (entries.isEmpty) {
              return [
                SelectableItem(
                  id: 'empty',
                  title: '暂无相册记录',
                  icon: Icons.info_outline,
                  selectable: false,
                ),
              ];
            }
            final dates = entries.keys.toList()
              ..sort((a, b) => b.compareTo(a));
            const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
            return dates.map((date) {
              final imageCount = entries[date]!
                  .fold<int>(0, (sum, e) => sum + e.imageUrls.length);
              return SelectableItem(
                id:
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                title:
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} 周${weekdays[date.weekday - 1]}',
                subtitle: '${entries[date]!.length} 条记录 · $imageCount 张图片',
                icon: Icons.photo_library,
                rawData: entries[date]!,
              );
            }).toList();
          },
        ),
        SelectorStep(
          id: 'entry',
          title: '选择记录',
          viewType: SelectorViewType.list,
          isFinalStep: true,
          dataLoader: (previousSelections) async {
            final dayEntries =
                previousSelections['date'] as List<CalendarEntry>? ?? const [];
            return dayEntries.map((entry) {
              final parts = [
                if (entry.imageUrls.isNotEmpty) '${entry.imageUrls.length}图',
                if (entry.tags.isNotEmpty) entry.tags.take(3).join('/'),
                if (entry.mood != null && entry.mood!.isNotEmpty) entry.mood!,
              ];
              return SelectableItem(
                id: entry.id,
                title: entry.title.isEmpty ? '无标题' : entry.title,
                subtitle: parts.isEmpty ? null : parts.join(' · '),
                icon: Icons.photo,
                rawData: entry,
              );
            }).toList();
          },
          searchFilter: (items, query) {
            if (query.isEmpty) return items;
            final lowerQuery = query.toLowerCase();
            return items.where((item) {
              final entry = item.rawData as CalendarEntry;
              return item.title.toLowerCase().contains(lowerQuery) ||
                  entry.content.toLowerCase().contains(lowerQuery) ||
                  entry.tags.any((t) => t.toLowerCase().contains(lowerQuery));
            }).toList();
          },
        ),
      ],
    ),
  );
}
