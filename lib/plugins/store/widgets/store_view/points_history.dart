import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/store/controllers/store_controller.dart';
import 'package:aboutme/plugins/store/models/points_log.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';
import 'package:aboutme/core/services/toast_service.dart';

/// 排序顺序枚举
enum SortOrder { newestFirst, oldestFirst }

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
    final theme = DSThemeBridge.resolve(context);
    return SuperCupertinoNavigationWrapper(
      title: DsIcon(DsIconKind.clock, color: theme.success, size: 24),
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
    final totalEarned = widget.controller.pointsLogs
        .where((log) => log.type == '获得')
        .fold<int>(0, (sum, log) => sum + log.value);
    final totalSpent = widget.controller.pointsLogs
        .where((log) => log.type == '消耗')
        .fold<int>(0, (sum, log) => sum + log.value);

    return SuperCupertinoNavigationWrapper(
      title: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return DsIcon(DsIconKind.clock, color: theme.success, size: 24);
        },
      ),
      largeTitle: 'store_pointsHistory'.tr,
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return Column(
              children: [
                // 统计信息
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              '当前积分',
                              widget.controller.currentPoints.toString(),
                              theme.primary,
                              DsIconKind.piggy,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              '总获得',
                              '+$totalEarned',
                              theme.success,
                              DsIconKind.plus,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              '总消耗',
                              '-$totalSpent',
                              theme.danger,
                              DsIconKind.minus,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 积分历史列表
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount:
                        _displayedLogs.length +
                        (_currentPage * _pageSize < _filteredLogs.length
                            ? 1
                            : 0),
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
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: DSCard(
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
                  label: '清空',
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

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    Color color,
    DsIconKind icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsIcon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: DsTypography.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(value, style: DsTypography.title.copyWith(color: color)),
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
