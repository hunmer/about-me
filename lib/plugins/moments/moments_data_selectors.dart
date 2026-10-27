part of 'moments_plugin.dart';

/// 注册数据选择器
void _registerDataSelectors() {
  pluginDataSelectorService.registerSelector(
    SelectorDefinition(
      id: 'moments.post',
      pluginId: MomentsPlugin.instance.id,
      name: '选择动态',
      icon: MomentsPlugin.instance.icon,
      color: MomentsPlugin.instance.color,
      searchable: true,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'post',
          title: '选择动态',
          viewType: SelectorViewType.list,
          isFinalStep: true,
          dataLoader: (_) async {
            final posts = MomentsService.instance.posts;
            return posts
                .map((p) {
                  final firstLine = p.text.split('\n').first;
                  final title =
                      firstLine.length > 30 ? '${firstLine.substring(0, 30)}…' : firstLine;
                  final date =
                      '${p.createdAt.year}-${p.createdAt.month.toString().padLeft(2, '0')}-${p.createdAt.day.toString().padLeft(2, '0')}';
                  return SelectableItem(
                    id: p.id,
                    title: title,
                    subtitle: '${p.agentId} · $date · ${p.images.length}图',
                    icon: Icons.photo_camera_outlined,
                    rawData: p,
                  );
                })
                .toList();
          },
          searchFilter: (items, query) {
            if (query.isEmpty) return items;
            final lowerQuery = query.toLowerCase();
            return items.where((item) {
              final post = item.rawData as MomentPost;
              return item.title.toLowerCase().contains(lowerQuery) ||
                  post.text.toLowerCase().contains(lowerQuery) ||
                  post.agentId.toLowerCase().contains(lowerQuery);
            }).toList();
          },
        ),
      ],
    ),
  );
}
