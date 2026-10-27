part of 'live2d_plugin.dart';

/// 注册数据选择器
void _registerDataSelectors() {
  pluginDataSelectorService.registerSelector(
    SelectorDefinition(
      id: 'live2d.archive',
      pluginId: Live2DPlugin.instance.id,
      name: '选择 Live2D 存档',
      icon: Live2DPlugin.instance.icon,
      color: Live2DPlugin.instance.color,
      searchable: true,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'archive',
          title: '选择存档',
          viewType: SelectorViewType.list,
          isFinalStep: true,
          dataLoader: (_) async {
            final archives = Live2DPlugin.instance.archives;
            if (archives.isEmpty) {
              return [
                SelectableItem(
                  id: 'empty',
                  title: '暂无存档',
                  subtitle: '请先在 Live2D 插件中创建存档',
                  icon: Icons.info_outline,
                  selectable: false,
                ),
              ];
            }
            return archives
                .map((a) {
                  final selected =
                      a.id == Live2DPlugin.instance.selectedId;
                  final parts = [
                    if (a.modelLabel.isNotEmpty) a.modelLabel,
                    if (a.agentId != null && a.agentId!.isNotEmpty)
                      'agent: ${a.agentId}',
                    if (a.note.isNotEmpty) a.note,
                  ];
                  return SelectableItem(
                    id: a.id,
                    title: a.name,
                    subtitle: parts.isEmpty
                        ? (selected ? '当前使用' : null)
                        : '${parts.join(' · ')}${selected ? ' · 当前使用' : ''}',
                    icon: Icons.face,
                    rawData: a,
                  );
                })
                .toList();
          },
          searchFilter: (items, query) {
            if (query.isEmpty) return items;
            final lowerQuery = query.toLowerCase();
            return items.where((item) {
              final archive = item.rawData as Live2DArchive?;
              if (archive == null) return false;
              return item.title.toLowerCase().contains(lowerQuery) ||
                  archive.modelLabel.toLowerCase().contains(lowerQuery) ||
                  archive.note.toLowerCase().contains(lowerQuery) ||
                  (archive.agentId?.toLowerCase().contains(lowerQuery) ??
                      false);
            }).toList();
          },
        ),
      ],
    ),
  );
}
