part of 'reminder_plugin.dart';

/// 注册数据选择器
void _registerDataSelectors() {
  pluginDataSelectorService.registerSelector(
    SelectorDefinition(
      id: 'reminder.item',
      pluginId: ReminderPlugin.instance.id,
      name: '选择提醒',
      icon: ReminderPlugin.instance.icon,
      color: ReminderPlugin.instance.color,
      searchable: true,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'item',
          title: '选择提醒',
          viewType: SelectorViewType.list,
          isFinalStep: true,
          dataLoader: (_) async {
            final reminders = ReminderPlugin.instance.service.reminders;
            return reminders
                .map((r) => SelectableItem(
                      id: r.id,
                      title: r.title,
                      subtitle:
                          '${r.getFrequencyDisplayText()}${r.isEnabled ? '' : ' · 已停用'}',
                      icon: r.isEnabled ? Icons.alarm : Icons.alarm_off,
                      rawData: r,
                    ))
                .toList();
          },
          searchFilter: (items, query) {
            if (query.isEmpty) return items;
            final lowerQuery = query.toLowerCase();
            return items.where((item) {
              final reminder = item.rawData as Reminder;
              return item.title.toLowerCase().contains(lowerQuery) ||
                  reminder.content.toLowerCase().contains(lowerQuery);
            }).toList();
          },
        ),
      ],
    ),
  );
}
