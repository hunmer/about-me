part of 'media_log_plugin.dart';

/// 注册数据选择器
void _registerDataSelectors() {
  pluginDataSelectorService.registerSelector(
    SelectorDefinition(
      id: 'media_log.item',
      pluginId: MediaLogPlugin.instance.id,
      name: '选择媒体记录',
      icon: MediaLogPlugin.instance.icon,
      color: MediaLogPlugin.instance.color,
      searchable: true,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'item',
          title: '选择媒体记录',
          viewType: SelectorViewType.list,
          isFinalStep: true,
          dataLoader: (_) async {
            final items = MediaLogPlugin.instance.items;
            return items
                .map((m) {
                  final kindText = m.kind == MediaKind.reading ? '阅读' : '观影';
                  final parts = [
                    if (m.author != null && m.author!.isNotEmpty) m.author,
                    kindText,
                    if (m.rating != null) '${m.rating}分',
                  ];
                  return SelectableItem(
                    id: m.id,
                    title: m.title,
                    subtitle: parts.join(' · '),
                    icon: m.kind == MediaKind.reading
                        ? Icons.menu_book
                        : Icons.movie,
                    rawData: m,
                  );
                })
                .toList();
          },
          searchFilter: (items, query) {
            if (query.isEmpty) return items;
            final lowerQuery = query.toLowerCase();
            return items.where((item) {
              final media = item.rawData as MediaItem;
              return item.title.toLowerCase().contains(lowerQuery) ||
                  (media.author?.toLowerCase().contains(lowerQuery) ?? false) ||
                  media.tags.any((t) => t.toLowerCase().contains(lowerQuery));
            }).toList();
          },
        ),
      ],
    ),
  );
}
