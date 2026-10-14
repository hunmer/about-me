import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/store/controllers/store_controller.dart';
import 'package:aboutme/plugins/store/events/point_award_event.dart';
import 'package:aboutme/plugins/store/models/points_log.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/health_score_ring_card.dart';
import 'package:aboutme/widgets/form_fields/event_multi_select_field.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/core/services/toast_service.dart';

/// 排序顺序枚举
enum SortOrder { newestFirst, oldestFirst }

/// 图例中"其他"（非事件奖励）分组的筛选键
const String _kOtherFilterKey = '__other__';

/// 奖励事件的图例配色（环分段 + 进度条共用，循环取色）
const List<Color> _kEventPalette = [
  Color(0xFF6C8EF5),
  Color(0xFF5ABF8A),
  Color(0xFFE8A33D),
  Color(0xFF9B7EDE),
  Color(0xFF4FB3BF),
  Color(0xFFE07A9B),
  Color(0xFF7C9A5E),
  Color(0xFFC97B4A),
  Color(0xFF5E7CC9),
];

/// 奖励事件的图例图标
const Map<String, IconData> _kEventIcons = {
  'activity_added': Icons.celebration,
  'checkin_completed': Icons.check_circle_outline,
  'task_completed': Icons.task_alt,
  'note_added': Icons.edit_note,
  'goods_added': Icons.inventory_2,
  'chat_message_sent': Icons.chat_bubble_outline,
  'onRecordAdded': Icons.monitor_heart,
  'diary_entry_created': Icons.menu_book,
  'bill_added': Icons.receipt_long,
};

class PointsHistory extends StatefulWidget {
  final StoreController controller;

  const PointsHistory({super.key, required this.controller});

  @override
  State<PointsHistory> createState() => _PointsHistoryState();
}

class _PointsHistoryState extends State<PointsHistory> {
  static const int _pageSize = 30;
  int _currentPage = 0;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  List<PointsLog> _displayedLogs = [];

  // 搜索和过滤状态
  String _searchQuery = '';
  Map<String, dynamic> _filters = {};
  SortOrder _sortOrder = SortOrder.newestFirst;
  List<PointsLog> _filteredLogs = []; // 完整的过滤后数据

  // 统计区状态：当前查看日期 + 图例筛选的事件键（null = 全部）
  DateTime _selectedDate = DateTime.now();
  String? _eventFilter;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_scrollListener);
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      _loadInitialData();
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading) {
      _loadMoreData();
    }
  }

  void _loadInitialData() {
    setState(() {
      _currentPage = 0;
      _displayedLogs.clear();
      // 更新完整的过滤后数据
      _filteredLogs = _applyFilters(widget.controller.pointsLogs);
    });
    _loadMoreData();
  }

  /// 应用搜索和过滤条件到原始数据
  List<PointsLog> _applyFilters(List<PointsLog> originalLogs) {
    var filtered = List<PointsLog>.from(originalLogs);

    // 搜索过滤（按理由）
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered
              .where(
                (log) => log.reason.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();
    }

    // 类型过滤（获得/消耗）
    final types = _filters['type'] as List<String>?;
    if (types != null && types.isNotEmpty) {
      filtered = filtered.where((log) => types.contains(log.type)).toList();
    }

    // 日期范围过滤
    final dateRange = _filters['dateRange'] as DateTimeRange?;
    if (dateRange != null) {
      filtered =
          filtered
              .where(
                (log) =>
                    !log.timestamp.isBefore(dateRange.start) &&
                    !log.timestamp.isAfter(dateRange.end),
              )
              .toList();
    }

    // 事件（图例）过滤：按奖励事件的 reason 文案匹配
    if (_eventFilter != null) {
      if (_eventFilter == _kOtherFilterKey) {
        final knownReasons = PointAwardEvent.eventReasons.values.toSet();
        filtered =
            filtered.where((log) => !knownReasons.contains(log.reason)).toList();
      } else {
        final reason = PointAwardEvent.eventReasons[_eventFilter];
        if (reason != null) {
          filtered = filtered.where((log) => log.reason == reason).toList();
        }
      }
    }

    // 排序
    switch (_sortOrder) {
      case SortOrder.newestFirst:
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case SortOrder.oldestFirst:
        filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
    }

    return filtered;
  }

  void _loadMoreData() {
    if (_isLoading) return;
    if (_currentPage * _pageSize >= _filteredLogs.length) return;

    setState(() {
      _isLoading = true;
    });

    // 模拟异步加载
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          final start = _currentPage * _pageSize;
          final end =
              (start + _pageSize <= _filteredLogs.length)
                  ? start + _pageSize
                  : _filteredLogs.length;

          if (_currentPage == 0) {
            _displayedLogs = _filteredLogs.sublist(start, end);
          } else {
            _displayedLogs.addAll(_filteredLogs.sublist(start, end));
          }

          _currentPage++;
          _isLoading = false;
        });
      }
    });
  }

  /// 搜索回调
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 0;
      _displayedLogs.clear();
      // 更新完整的过滤后数据
      _filteredLogs = _applyFilters(widget.controller.pointsLogs);
    });
    _loadMoreData();
  }

  /// 多条件过滤回调
  void _onMultiFilterChanged(Map<String, dynamic> filters) {
    setState(() {
      _filters = filters;
      // 从过滤器中获取排序设置
      final sortOrder = filters['sortOrder'] as String?;
      if (sortOrder == 'oldestFirst') {
        _sortOrder = SortOrder.oldestFirst;
      } else {
        _sortOrder = SortOrder.newestFirst;
      }
      _currentPage = 0;
      _displayedLogs.clear();
      // 更新完整的过滤后数据
      _filteredLogs = _applyFilters(widget.controller.pointsLogs);
    });
    _loadMoreData();
  }

  // ========== 今日得分统计 ==========

  /// 今日目标积分（设置页可配）
  double get _dailyTarget {
    final target =
        widget.controller.plugin.settings['dailyPointsTarget'] as int?;
    return (target != null && target > 0 ? target : 50).toDouble();
  }

  /// 插件设置中启用（积分值 > 0）且实际会发奖的事件（有 reason 映射）
  List<String> _enabledAwardEvents() {
    final awards =
        widget.controller.plugin.settings['point_awards']
            as Map<String, dynamic>? ??
        {};
    return PointAwardEvent.eventReasons.keys
        .where((key) => awards[key] is int && awards[key] as int > 0)
        .toList();
  }

  /// 积分记录的 reason 对应的奖励事件键（null = 非事件奖励）
  String? _eventKeyOfReason(String reason) {
    for (final entry in PointAwardEvent.eventReasons.entries) {
      if (entry.value == reason) return entry.key;
    }
    return null;
  }

  /// 奖励事件的显示名称（取自 kDefaultAvailableEvents 的描述）
  String _eventLabel(String eventKey) {
    final option = kDefaultAvailableEvents.firstWhereOrNull(
      (e) => e.eventName == eventKey,
    );
    return option?.description ?? eventKey;
  }

  /// 指定日期当天的记录
  List<PointsLog> _logsOfDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return widget.controller.pointsLogs
        .where(
          (log) => !log.timestamp.isBefore(start) && log.timestamp.isBefore(end),
        )
        .toList();
  }

  /// 构建环形统计项与对应的筛选键（平行数组）
  (List<HealthRingItemData>, List<String>) _buildRingItems(
    List<PointsLog> dayEarnedLogs,
  ) {
    final maxScore = _dailyTarget;
    final dayScores = <String, int>{};
    for (final log in dayEarnedLogs) {
      final key = _eventKeyOfReason(log.reason);
      if (key != null) {
        dayScores[key] = (dayScores[key] ?? 0) + log.value;
      }
    }
    final otherScore = dayEarnedLogs
        .where((log) => _eventKeyOfReason(log.reason) == null)
        .fold<int>(0, (sum, log) => sum + log.value);

    // 只展示当天有得分的事件；全部为 0 时展示所有启用事件
    final enabled = _enabledAwardEvents();
    var shown = enabled.where((key) => (dayScores[key] ?? 0) > 0).toList();
    final showOther = otherScore > 0;
    if (shown.isEmpty && !showOther) {
      shown = enabled;
    }

    final items = <HealthRingItemData>[];
    final filterKeys = <String>[];
    for (var i = 0; i < shown.length; i++) {
      final key = shown[i];
      final score = (dayScores[key] ?? 0).toDouble();
      items.add(
        HealthRingItemData(
          label: _eventLabel(key),
          icon: _kEventIcons[key] ?? Icons.stars,
          color: _kEventPalette[i % _kEventPalette.length],
          score: score,
          maxScore: maxScore,
          value: score,
        ),
      );
      filterKeys.add(key);
    }
    if (showOther) {
      items.add(
        HealthRingItemData(
          label: 'store_otherCategory'.tr,
          icon: Icons.more_horiz,
          color: const Color(0xFF8A93A6),
          score: otherScore.toDouble(),
          maxScore: maxScore,
          value: otherScore.toDouble(),
        ),
      );
      filterKeys.add(_kOtherFilterKey);
    }
    return (items, filterKeys);
  }

  /// 点击图例：筛选/取消筛选对应事件的记录
  void _onLegendTapped(String filterKey) {
    setState(() {
      _eventFilter = _eventFilter == filterKey ? null : filterKey;
      _currentPage = 0;
      _displayedLogs.clear();
      _filteredLogs = _applyFilters(widget.controller.pointsLogs);
    });
    _loadMoreData();
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  /// 构建多条件过滤项
  List<FilterItem> _buildMultiFilterItems() {
    return [
      // 类型过滤（获得/消耗）
      FilterItem(
        id: 'type',
        title: 'store_type'.tr,
        type: FilterType.tagsMultiple,
        initialValue: const ['获得', '消耗'],
        builder: (context, value, onChanged) {
          final selected = value as List<String>? ?? ['获得', '消耗'];
          // 第三方过滤栏回调：DS 组件需包 DSThemeBridge
          return DSThemeBridge(
            child: Wrap(
              spacing: 8,
              children:
                  ['获得', '消耗'].map((type) {
                    final isSelected = selected.contains(type);
                    return DSChip(
                      label: type,
                      selected: isSelected,
                      onSelected: (bool isCurrentlySelected) {
                        final newSelected = List<String>.from(selected);
                        if (isCurrentlySelected) {
                          if (!newSelected.contains(type)) {
                            newSelected.add(type);
                          }
                        } else {
                          newSelected.remove(type);
                        }
                        onChanged(newSelected);
                      },
                    );
                  }).toList(),
            ),
          );
        },
        getBadge: (value) {
          final selected = value as List<String>? ?? [];
          if (selected.length == 2 || selected.isEmpty) return null;
          return selected.length.toString();
        },
      ),
      // 日期范围过滤
      FilterItem(
        id: 'dateRange',
        title: 'store_dateRange'.tr,
        type: FilterType.dateRange,
        initialValue: null,
        builder: (context, value, onChanged) {
          final range = value as DateTimeRange?;
          // 第三方过滤栏回调：DS 组件需包 DSThemeBridge
          return DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSButton(
                    label:
                        range == null
                            ? 'store_selectDateRange'.tr
                            : '${range.start.month}/${range.start.day} - ${range.end.month}/${range.end.day}',
                    icon: DsIconKind.calendar,
                    variant: DSButtonVariant.outline,
                    size: DSButtonSize.sm,
                    onPressed: () async {
                      // DS 暂无日期范围选择器，保留 Material showDateRangePicker
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                        initialDateRange: range,
                        locale: const Locale('zh', 'CN'),
                      );
                      if (picked != null) {
                        onChanged(picked);
                      }
                    },
                  ),
            ),
          );
        },
        getBadge: (value) => value != null ? '1' : null,
      ),
      // 排序选项
      FilterItem(
        id: 'sortOrder',
        title: 'store_sort'.tr,
        type: FilterType.tagsSingle,
        initialValue: 'newestFirst',
        builder: (context, value, onChanged) {
          final selected = value as String? ?? 'newestFirst';
          // 第三方过滤栏回调：DS 组件需包 DSThemeBridge
          return DSThemeBridge(
            child: Wrap(
              spacing: 8,
              children: [
                DSChip(
                  label: 'store_newestFirst'.tr,
                  selected: selected == 'newestFirst',
                  onSelected: (_) => onChanged('newestFirst'),
                ),
                DSChip(
                  label: 'store_oldestFirst'.tr,
                  selected: selected == 'oldestFirst',
                  onSelected: (_) => onChanged('oldestFirst'),
                ),
              ],
            ),
          );
        },
        getBadge: (value) => null,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.pointsLogs.isEmpty) {
      return _buildEmptyView();
    }

    return _buildHistoryView();
  }

  Widget _buildEmptyView() {
    return SuperCupertinoNavigationWrapper(
      title: Text('store_pointsHistory'.tr),
      largeTitle: 'store_pointsHistory'.tr,
      body: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DsIcon(DsIconKind.clock, size: 64, color: theme.textSub),
                const SizedBox(height: 16),
                Text(
                  'store_noRecords'.tr,
                  style: DsTypography.body.copyWith(color: theme.textSub),
                ),
                const SizedBox(height: 8),
                Text(
                  'store_earnPointsTip'.tr,
                  style: DsTypography.caption.copyWith(
                    color: theme.textSub.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      enableLargeTitle: true,
      enableSearchBar: false,
    );
  }

  Widget _buildHistoryView() {
    return SuperCupertinoNavigationWrapper(
      title: Text('store_pointsHistory'.tr),
      largeTitle: 'store_pointsHistory'.tr,
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return Column(
              children: [
                // 今日得分统计（日期切换 + 分段环 + 图例）
                _buildStatsSection(context, theme),
                // 积分历史列表
                Expanded(
                  child: HandDrawnListView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      8, 8, 8, 8 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount:
                        _displayedLogs.length +
                        (_currentPage * _pageSize < _filteredLogs.length
                            ? 1
                            : 0),
                    tiltKeyOf: (index) =>
                        index < _displayedLogs.length
                            ? _displayedLogs[index].id
                            : 'points_history_loading',
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      // 如果是最后一个项目且还有更多数据可加载，显示加载指示器
                      if (index == _displayedLogs.length) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: DSLoadingDots(),
                          ),
                        );
                      }

                      final log = _displayedLogs[index];
                      return DSCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              DSAvatar(
                                size: 36,
                                color:
                                    log.type == '获得'
                                        ? theme.success
                                        : theme.danger,
                                child: DsIcon(
                                  log.type == '获得'
                                      ? DsIconKind.plus
                                      : DsIconKind.minus,
                                  size: 18,
                                  color: theme.onPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'store_pointsHistoryEntry'.tr
                                          .replaceFirst(
                                            '{value}',
                                            log.value.toString(),
                                          )
                                          .replaceFirst('{type}', log.type),
                                      style: DsTypography.body.copyWith(
                                        color: theme.text,
                                      ),
                                    ),
                                    Text(
                                      log.reason,
                                      style: DsTypography.caption.copyWith(
                                        color: theme.textSub,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                                    style: DsTypography.caption.copyWith(
                                      color: theme.textSub,
                                    ),
                                  ),
                                  Text(
                                    '${log.timestamp.month}/${log.timestamp.day}',
                                    style: DsTypography.caption.copyWith(
                                      color: theme.textSub.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      enableLargeTitle: true,
      enableSearchBar: true,
      enableMultiFilter: true,
      multiFilterItems: _buildMultiFilterItems(),
      searchPlaceholder: 'store_searchReason'.tr,
      onSearchChanged: _onSearchChanged,
      onMultiFilterChanged: _onMultiFilterChanged,
      actions: [
        // 第三方导航栏回调：DS 组件需包 DSThemeBridge
        DSThemeBridge(
          child: Builder(
            builder:
                (context) => DSButton(
                  label: 'store_clear'.tr,
                  variant: DSButtonVariant.destructive,
                  size: DSButtonSize.sm,
                  onPressed: () {
                    _showClearLogsDialog(context);
                  },
                ),
          ),
        ),
      ],
    );
  }

  /// 统计区：日期切换行 + 健康得分环卡（按事件分段，图例可点击筛选）
  Widget _buildStatsSection(BuildContext context, AppThemeData theme) {
    final dayLogs = _logsOfDay(_selectedDate);
    final dayEarned = dayLogs.where((log) => log.type == '获得').toList();
    final dayTotal = dayEarned.fold<int>(0, (sum, log) => sum + log.value);
    final (ringItems, ringKeys) = _buildRingItems(dayEarned);

    final filterLabel = _eventFilter == null
        ? 'store_all'.tr
        : (_eventFilter == _kOtherFilterKey
              ? 'store_otherCategory'.tr
              : _eventLabel(_eventFilter!));
    // 今日显示"今日得分"，其他日期显示月/日
    final dayTitle = _isToday
        ? 'store_dailyScoreTitle'.tr
        : '${_selectedDate.month}/${_selectedDate.day}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          // 日期切换
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DSIconButton(
                icon: DsIconKind.chevronLeft,
                size: 34,
                color: theme.surface,
                iconColor: theme.text,
                tooltip: 'store_prevDay'.tr,
                onPressed: () => _changeDate(-1),
              ),
              const SizedBox(width: 8),
              DSButton(
                label: dayTitle,
                icon: DsIconKind.calendar,
                variant: DSButtonVariant.outline,
                size: DSButtonSize.sm,
                onPressed: _pickDate,
              ),
              const SizedBox(width: 8),
              DSIconButton(
                icon: DsIconKind.chevronRight,
                size: 34,
                color: theme.surface,
                iconColor: theme.text,
                tooltip: 'store_nextDay'.tr,
                onPressed: _isToday ? null : () => _changeDate(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 得分环卡（inline 模式需外层固定高度）
          SizedBox(
            height: 320,
            child: HealthScoreRingCardWidget(
              inline: true,
              score: dayTotal.toDouble(),
              title: dayTitle,
              filterLabel: filterLabel,
              items: ringItems,
              onItemTap: ringKeys.isEmpty
                  ? null
                  : (index) => _onLegendTapped(ringKeys[index]),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearLogsDialog(BuildContext context) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'store_clearPointsHistory'.tr,
                    message: 'store_confirmClearPointsHistory'.tr,
                    cancelText: 'store_cancel'.tr,
                    confirmText: '确定',
                    confirmVariant: DSButtonVariant.destructive,
                    onConfirm: () async {
                      Navigator.pop(context);
                      await widget.controller.clearPointsLogs();
                      _loadInitialData();
                      if (mounted) {
                        Toast.success('积分记录已清空');
                      }
                    },
                  ),
            ),
          ),
    );
  }
}
