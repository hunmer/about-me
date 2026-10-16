part of 'habits_plugin.dart';

/// 注册数据选择器
void _registerDataSelectors() {
  // 习惯选择器
  PluginDataSelectorService.instance.registerSelector(
    SelectorDefinition(
      id: 'habits.habit',
      pluginId: HabitsPlugin.instance.id,
      name: '选择习惯',
      icon: HabitsPlugin.instance.icon,
      color: HabitsPlugin.instance.color,
      searchable: true,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'habit',
          title: '选择习惯',
          viewType: SelectorViewType.list,
          isFinalStep: true,
          dataLoader: (_) async {
            final habits = HabitsPlugin.instance._habitController.getHabits();
            final List<SelectableItem> items = [];

            for (final habit in habits) {
              // 获取累计时长和完成次数作为副标题
              final duration = await HabitsPlugin.instance._recordController
                  .getTotalDuration(habit.id);
              final count = await HabitsPlugin.instance._recordController
                  .getCompletionCount(habit.id);

              items.add(
                SelectableItem(
                  id: habit.id,
                  title: habit.title,
                  subtitle: '$duration 分钟 · $count 次完成',
                  icon:
                      habit.icon != null
                          ? dynamicIconData(
                            int.parse(habit.icon!),
                            fontFamily: 'MaterialIcons',
                          )
                          : Icons.auto_awesome,
                  rawData: habit,
                ),
              );
            }

            return items;
          },
          searchFilter: (items, query) {
            if (query.isEmpty) return items;
            final lowerQuery = query.toLowerCase();
            return items
                .where(
                  (item) =>
                      item.title.toLowerCase().contains(lowerQuery) ||
                      (item.rawData as Habit).group?.toLowerCase().contains(
                            lowerQuery,
                          ) ==
                          true ||
                      (item.rawData as Habit).tags.any(
                        (tag) => tag.toLowerCase().contains(lowerQuery),
                      ),
                )
                .toList();
          },
        ),
      ],
    ),
  );

  // 活动统计配置选择器
  PluginDataSelectorService.instance.registerSelector(
    SelectorDefinition(
      id: 'habits.activity_stats.config',
      pluginId: HabitsPlugin.instance.id,
      name: '配置活动统计',
      icon: Icons.analytics,
      color: HabitsPlugin.instance.color,
      searchable: false,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'config',
          title: '配置活动统计',
          viewType: SelectorViewType.customForm,
          dataLoader: (_) async => [],
          isFinalStep: true,
          customFormBuilder: (context, previousSelections, onComplete) {
            return _ActivityStatsConfigForm(
              onComplete: (config) {
                onComplete(config);
              },
            );
          },
        ),
      ],
    ),
  );

  // 习惯统计配置选择器
  PluginDataSelectorService.instance.registerSelector(
    SelectorDefinition(
      id: 'habits.habit_stats.config',
      pluginId: HabitsPlugin.instance.id,
      name: '配置习惯统计',
      icon: Icons.trending_up,
      color: HabitsPlugin.instance.color,
      searchable: false,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'config',
          title: '配置习惯统计',
          viewType: SelectorViewType.customForm,
          dataLoader: (_) async => [],
          isFinalStep: true,
          customFormBuilder: (context, previousSelections, onComplete) {
            return _HabitStatsConfigForm(
              onComplete: (config) {
                onComplete(config);
              },
            );
          },
        ),
      ],
    ),
  );
}

/// 活动统计配置表单
class _ActivityStatsConfigForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onComplete;

  const _ActivityStatsConfigForm({required this.onComplete});

  @override
  State<_ActivityStatsConfigForm> createState() =>
      _ActivityStatsConfigFormState();
}

class _ActivityStatsConfigFormState extends State<_ActivityStatsConfigForm> {
  String _dateRange = 'week';
  int _maxCount = 5;

  final List<Map<String, dynamic>> _dateRangeOptions = [
    {'value': 'today', 'label': '本日', 'icon': Icons.today},
    {'value': 'week', 'label': '本周', 'icon': Icons.date_range},
    {'value': 'month', 'label': '本月', 'icon': Icons.calendar_month},
    {'value': 'year', 'label': '本年', 'icon': Icons.calendar_today},
  ];

  void _confirm() {
    widget.onComplete({'dateRange': _dateRange, 'maxCount': _maxCount});
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  // 标题
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.analytics, color: theme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '配置活动统计',
                            style: DsTypography.title.copyWith(
                              color: theme.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // 配置选项
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // 日期范围选择
                        _buildSectionTitle(context, '日期范围'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              _dateRangeOptions.map((option) {
                                final isSelected =
                                    _dateRange == option['value'] as String;
                                return DSChip(
                                  label: option['label'] as String,
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setState(
                                      () =>
                                          _dateRange =
                                              option['value'] as String,
                                    );
                                  },
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // 显示数量
                        _buildSectionTitle(context, '最多显示数量'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DSSlider(
                                value: (_maxCount - 1) / 9,
                                onChanged: (value) {
                                  setState(
                                    () => _maxCount = (value * 9).round() + 1,
                                  );
                                },
                              ),
                            ),
                            Container(
                              width: 48,
                              alignment: Alignment.center,
                              child: Text(
                                '$_maxCount',
                                style: DsTypography.title.copyWith(
                                  color: theme.text,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 底部按钮
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: DSButton(
                            label: '取消',
                            variant: DSButtonVariant.outline,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DSButton(label: '确认', onPressed: _confirm),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Text(
            title,
            style: DsTypography.body.copyWith(
              color: theme.text,
              fontWeight: FontWeight.bold,
            ),
          );
        },
      ),
    );
  }
}

/// 习惯统计配置表单
class _HabitStatsConfigForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onComplete;

  const _HabitStatsConfigForm({required this.onComplete});

  @override
  State<_HabitStatsConfigForm> createState() => _HabitStatsConfigFormState();
}

class _HabitStatsConfigFormState extends State<_HabitStatsConfigForm> {
  String? _selectedHabitId;
  List<Habit> _habits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  void _loadHabits() {
    final habits = HabitsPlugin.instance._habitController.getHabits();
    setState(() {
      _habits = habits;
      _isLoading = false;
      if (habits.isNotEmpty) {
        _selectedHabitId = habits.first.id;
      }
    });
  }

  void _confirm() {
    if (_selectedHabitId == null) {
      Toast.error('请选择一个习惯');
      return;
    }
    widget.onComplete({'habitId': _selectedHabitId});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: DSThemeBridge(child: Center(child: DSLoadingDots())),
        ),
      );
    }

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  // 标题
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.trending_up, color: theme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '配置习惯统计',
                            style: DsTypography.title.copyWith(
                              color: theme.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // 习惯列表
                  Expanded(
                    child:
                        _habits.isEmpty
                            ? Center(
                              child: Text(
                                'habits_emptyTitle'.tr,
                                style: DsTypography.body.copyWith(
                                  color: theme.textSub,
                                ),
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _habits.length,
                              itemBuilder: (context, index) {
                                final habit = _habits[index];
                                final isSelected = _selectedHabitId == habit.id;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: DSCard(
                                    onTap: () {
                                      setState(
                                        () => _selectedHabitId = habit.id,
                                      );
                                    },
                                    padding: const EdgeInsets.all(12),
                                    color:
                                        isSelected
                                            ? theme.primary.mixWhite(0.92)
                                            : null,
                                    radius: theme.radii.xl,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: theme.primary.withAlpha(30),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            habit.icon != null
                                                ? dynamicIconData(
                                                  int.parse(habit.icon!),
                                                  fontFamily: 'MaterialIcons',
                                                )
                                                : Icons.auto_awesome,
                                            color: theme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                habit.title,
                                                style: DsTypography.body
                                                    .copyWith(
                                                      color: theme.text,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              Text(
                                                habit.group ??
                                                    habit.skillId ??
                                                    '习惯',
                                                style: DsTypography.caption
                                                    .copyWith(
                                                      color: theme.textSub,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          DsIcon(
                                            DsIconKind.check,
                                            color: theme.primary,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                  // 底部按钮
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: DSButton(
                            label: '取消',
                            variant: DSButtonVariant.outline,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DSButton(
                            label: '确认',
                            onPressed:
                                _selectedHabitId != null ? _confirm : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
