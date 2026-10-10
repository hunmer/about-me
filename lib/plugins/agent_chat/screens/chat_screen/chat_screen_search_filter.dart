part of 'chat_screen.dart';

/// 消息搜索 / 过滤 / 标签
extension _ChatScreenSearchFilterExt on _ChatScreenState {
  /// 搜索回调
  void _handleSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFiltersAndSearch();
    });
  }

  /// 过滤回调
  void _handleFilterChanged(Map<String, dynamic> filters) {
    filters.forEach((key, value) {
      _filterState.setValue(key, value);
    });
    _applyFiltersAndSearch();
  }

  /// 应用搜索与过滤（发送人/日期/标签）
  void _applyFiltersAndSearch() {
    List<ChatMessage> result = List.from(_controller.messages);

    // 应用搜索（仅匹配消息内容）
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result
          .where((m) => m.content.toLowerCase().contains(query))
          .toList();
    }

    // 应用发送人过滤（我 / AI）
    final selectedSender = _filterState.getValue('sender');
    if (selectedSender == 'me') {
      result = result.where((m) => m.isUser).toList();
    } else if (selectedSender == 'ai') {
      result = result.where((m) => !m.isUser).toList();
    }

    // 应用日期范围过滤
    final dateRange = _filterState.getValue('dateRange');
    if (dateRange != null && dateRange is Map<String, DateTime?>) {
      final startDate = dateRange['start'];
      final endDate = dateRange['end'];
      result = result.where((m) {
        if (startDate != null && m.timestamp.isBefore(startDate)) {
          return false;
        }
        if (endDate != null) {
          final endOfDay = DateTime(
            endDate.year,
            endDate.month,
            endDate.day,
            23,
            59,
            59,
          );
          if (m.timestamp.isAfter(endOfDay)) return false;
        }
        return true;
      }).toList();
    }

    // 应用标签过滤
    final selectedTags = _filterState.getValue('tags');
    if (selectedTags != null &&
        selectedTags is List &&
        selectedTags.isNotEmpty) {
      result = result.where((m) {
        final tags = m.metadata?['tags'] as List<String>?;
        if (tags == null || tags.isEmpty) return false;
        return selectedTags.any((tag) => tags.contains(tag));
      }).toList();
    }

    setState(() {
      _filteredMessages = result;
    });
  }

  /// 构建过滤项配置（发送人/日期/标签）
  List<FilterItem> _buildFilterItems() {
    final hasTags = _controller.messages.any(
      (m) => (m.metadata?['tags'] as List?)?.isNotEmpty == true,
    );

    return [
      // 发送人过滤（我 / AI）
      FilterItem(
        id: 'sender',
        title: '发送人',
        type: FilterType.custom,
        builder: (context, currentValue, onChanged) {
          return Wrap(
            spacing: 8,
            children: [
              DSChip(
                label: '我',
                selected: currentValue == 'me',
                onSelected: (selected) => onChanged(selected ? 'me' : null),
              ),
              DSChip(
                label: 'AI',
                selected: currentValue == 'ai',
                onSelected: (selected) => onChanged(selected ? 'ai' : null),
              ),
            ],
          );
        },
        getBadge: (value) => value == 'me'
            ? '我'
            : value == 'ai'
            ? 'AI'
            : null,
      ),

      // 日期范围过滤
      FilterItem(
        id: 'dateRange',
        title: '日期',
        type: FilterType.dateRange,
        builder: (context, currentValue, onChanged) {
          final Map<String, DateTime?> range =
              currentValue ?? {'start': null, 'end': null};
          final startDate = range['start'];
          final endDate = range['end'];

          Widget dateChip({
            required String label,
            required DateTime? current,
            required bool isStart,
          }) {
            return DSThemeBridge(
              child: Builder(
                builder: (context) {
                  final theme = DSThemeBridge.resolve(context);
                  return DSChip(
                    icon: DsIconKind.calendar,
                    label: current == null
                        ? label
                        : DateFormat('MM/dd').format(current),
                    onSelected: (_) async {
                      final picked = await showDSDatePickerDialog(
                        context: context,
                        theme: theme,
                        initial: current ?? DateTime.now(),
                      );
                      if (picked != null) {
                        onChanged({
                          'start': isStart ? picked : startDate,
                          'end': isStart ? endDate : picked,
                        });
                      }
                    },
                  );
                },
              ),
            );
          }

          return Wrap(
            spacing: 8,
            children: [
              dateChip(label: '开始日期', current: startDate, isStart: true),
              dateChip(label: '结束日期', current: endDate, isStart: false),
              if (startDate != null || endDate != null)
                DSThemeBridge(
                  child: Builder(
                    builder: (context) {
                      final theme = DSThemeBridge.resolve(context);
                      return DSIconButton(
                        icon: DsIconKind.close,
                        size: 32,
                        color: theme.surfaceAlt,
                        iconColor: theme.textSub,
                        onPressed: () => onChanged(null),
                      );
                    },
                  ),
                ),
            ],
          );
        },
        getBadge: (value) {
          if (value == null) return null;
          final Map<String, DateTime?> range = value;
          final start = range['start'];
          final end = range['end'];
          if (start != null && end != null) {
            return '${DateFormat('MM/dd').format(start)}-${DateFormat('MM/dd').format(end)}';
          } else if (start != null) {
            return '从${DateFormat('MM/dd').format(start)}';
          } else if (end != null) {
            return '至${DateFormat('MM/dd').format(end)}';
          }
          return null;
        },
      ),

      // 标签过滤（仅存在标签时显示）
      if (hasTags)
        FilterItem(
          id: 'tags',
          title: '标签',
          type: FilterType.tagsMultiple,
          builder: (context, currentValue, onChanged) {
            final tags = _getAllMessageTags();
            final List<String> selectedTags = currentValue ?? [];
            return Wrap(
              spacing: 8,
              children: tags.map((tag) {
                final isSelected = selectedTags.contains(tag);
                return DSChip(
                  label: tag,
                  selected: isSelected,
                  onSelected: (selected) {
                    final newTags = List<String>.from(selectedTags);
                    if (selected) {
                      newTags.add(tag);
                    } else {
                      newTags.remove(tag);
                    }
                    onChanged(newTags.isEmpty ? null : newTags);
                  },
                );
              }).toList(),
            );
          },
          getBadge: (value) {
            if (value == null || (value as List).isEmpty) return null;
            final tags = value as List<String>;
            return tags.length == 1 ? tags[0] : '${tags.length}个标签';
          },
        ),
    ];
  }

  /// 获取所有消息标签（去重排序）
  List<String> _getAllMessageTags() {
    final tags = <String>{};
    for (final message in _controller.messages) {
      final messageTags = message.metadata?['tags'] as List?;
      if (messageTags != null) {
        for (final tag in messageTags) {
          if (tag is String) tags.add(tag);
        }
      }
    }
    return tags.toList()..sort();
  }
}
