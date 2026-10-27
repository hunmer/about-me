part of 'scrapbook_plugin.dart';

/// 注册数据选择器
void _registerDataSelectors() {
  pluginDataSelectorService.registerSelector(
    SelectorDefinition(
      id: 'scrapbook.page',
      pluginId: ScrapbookPlugin.instance.id,
      name: '选择手账页面',
      icon: ScrapbookPlugin.instance.icon,
      color: ScrapbookPlugin.instance.color,
      searchable: true,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'page',
          title: '选择手账页面',
          viewType: SelectorViewType.list,
          isFinalStep: true,
          dataLoader: (_) async {
            final pages = await ScrapbookRepository.instance.getList();
            return pages
                .map((p) => SelectableItem(
                      id: p.id,
                      title: p.title,
                      subtitle:
                          '更新于 ${p.updatedAt.year}-${p.updatedAt.month.toString().padLeft(2, '0')}-${p.updatedAt.day.toString().padLeft(2, '0')}',
                      icon: Icons.auto_stories,
                      rawData: p,
                    ))
                .toList();
          },
          searchFilter: (items, query) {
            if (query.isEmpty) return items;
            final lowerQuery = query.toLowerCase();
            return items.where((item) {
              final page = item.rawData as ScrapbookPage;
              return item.title.toLowerCase().contains(lowerQuery) ||
                  page.summary.toLowerCase().contains(lowerQuery);
            }).toList();
          },
        ),
      ],
    ),
  );
}
