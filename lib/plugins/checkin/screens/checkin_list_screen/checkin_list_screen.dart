import 'package:get/get.dart';
import 'package:aboutme/plugins/checkin/models/checkin_item.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';
import 'package:aboutme/widgets/common/checkin_item_card.dart' show CheckinWeekdayHeader;
import 'package:aboutme/plugins/checkin/services/group_sort_service.dart';
import 'package:aboutme/plugins/checkin/controllers/checkin_list_controller.dart';
import 'package:aboutme/plugins/checkin/widgets/checkin_record_dialog.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'components/empty_state.dart';
import 'components/checkin_item_card.dart';

class CheckinListScreen extends StatefulWidget {
  final CheckinListController controller;

  /// 可选的打卡项目ID，用于从小组件跳转时自动打开打卡记录对话框
  final String? initialItemId;

  /// 可选的目标日期（格式：YYYY-MM-DD），用于打开指定日期的打卡记录
  final String? targetDate;

  const CheckinListScreen({
    super.key,
    required this.controller,
    this.initialItemId,
    this.targetDate,
  });

  @override
  State<CheckinListScreen> createState() => _CheckinListScreenState();
}

class _CheckinListScreenState extends State<CheckinListScreen> {
  late CheckinListController controller;
  final _eventManager = EventManager.instance;

  @override
  void initState() {
    super.initState();
    controller = widget.controller;
    // 订阅同步刷新事件
    _eventManager.subscribe('checkin_refresh', _handleSyncRefresh);
    // 恢复最后一次排序设置
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.restoreLastSortSetting();
      if (mounted) setState(() {});

      // 初始化时设置路由上下文
      _updateRouteContext();

      // 如果指定了 initialItemId，则自动打开对应的打卡记录对话框
      if (widget.initialItemId != null && mounted) {
        _showCheckinDialogForItem(widget.initialItemId!, widget.targetDate);
      }
    });
  }

  @override
  void dispose() {
    // 取消订阅，避免内存泄漏
    _eventManager.unsubscribe('checkin_refresh', _handleSyncRefresh);
    super.dispose();
  }

  /// 处理同步刷新事件
  void _handleSyncRefresh(EventArgs args) {
    debugPrint('[CheckinListScreen] 收到同步刷新事件');
    if (mounted) {
      setState(() {});
    }
  }

  void _handleStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// 更新路由上下文，使"询问当前上下文"功能能获取到当前选中的分组
  void _updateRouteContext() {
    final group = controller.selectedGroup;
    RouteHistoryManager.updateCurrentContext(
      pageId: "/checkin_list",
      title: '打卡列表 - $group',
      params: {'group': group},
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = controller.filteredItems;
    final searchResults = controller.getSearchResults();

    return SuperCupertinoNavigationWrapper(
      title: Text('checkin_name'.tr),
      largeTitle: 'checkin_checkinListTitle'.tr,
      body: Column(
        children: [
          // 全局星期表头（固定，不随列表滚动）：存在周视图卡片时显示
          if (filteredItems.any(
            (item) => item.cardStyle == CheckinCardStyle.weekly,
          ))
            const CheckinWeekdayHeader(),
          // 打卡项目列表（不包含过滤栏）
          Expanded(
            child:
                filteredItems.isEmpty
                    ? const EmptyState()
                    : SingleChildScrollView(
                      padding: EdgeInsets.only(
                        top: 12, // 贴条顶部出血
                        bottom: MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: StaggeredGrid.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16, // ≥ 贴条出血,避免压盖
                          crossAxisSpacing: 0,
                          children:
                              filteredItems.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                return StaggeredGridTile.fit(
                                  crossAxisCellCount:
                                      item.cardStyle == CheckinCardStyle.small
                                          ? 1
                                          : 2,
                                  // 手绘便签:随机倾斜 + 贴条(角度由 item.id 哈希确定);
                                  // 挂载即描画入场
                                  child: HandDrawnStickyItem(
                                    tiltKey: item.id,
                                    child: WiredDraw(
                                      child: CheckinItemCard(
                                        item: item,
                                        index: index,
                                        itemIndex: index,
                                        controller: controller,
                                        onStateChanged: _handleStateChanged,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
          ),
        ],
      ),
      // ========== 搜索相关配置 ==========
      enableSearchBar: true,
      searchPlaceholder: 'checkin_searchPlaceholder'.tr,
      onSearchChanged: (query) => controller.onSearchChanged(query),
      onSearchSubmitted: (query) => controller.onSearchChanged(query),
      searchBody: _buildSearchResults(searchResults),
      // ========== 多条件过滤栏配置（分组 + 排序） ==========
      enableMultiFilter: true,
      multiFilterItems: _buildFilterItems(),
      onMultiFilterChanged: _handleFilterChanged,
      enableLargeTitle: false,
    );
  }

  /// 构建搜索结果视图
  Widget _buildSearchResults(List<CheckinItem> searchResults) {
    if (controller.isSearching && searchResults.isEmpty) {
      final theme = DSThemeBridge.resolve(context);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DsIcon(DsIconKind.search, size: 64, color: theme.textSub),
            const SizedBox(height: 16),
            Text(
              'checkin_searchEmptyTitle'.tr,
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
            const SizedBox(height: 8),
            Text(
              'checkin_searchEmptyHint'.tr,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
        ),
      );
    }

    if (controller.isSearching && searchResults.isNotEmpty) {
      return Column(
        children: [
          // 全局星期表头（固定，不随列表滚动）
          if (searchResults.any(
            (item) => item.cardStyle == CheckinCardStyle.weekly,
          ))
            const CheckinWeekdayHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: 12, // 贴条顶部出血
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: StaggeredGrid.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 0,
                  mainAxisSpacing: 16, // ≥ 贴条出血,避免压盖
                  children:
                      searchResults.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return StaggeredGridTile.fit(
                          crossAxisCellCount:
                              item.cardStyle == CheckinCardStyle.small ? 1 : 2,
                          // 手绘便签:随机倾斜 + 贴条;挂载即描画入场
                          child: HandDrawnStickyItem(
                            tiltKey: item.id,
                            child: WiredDraw(
                              child: CheckinItemCard(
                                item: item,
                                index: index,
                                itemIndex: index,
                                controller: controller,
                                onStateChanged: _handleStateChanged,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 默认状态（不显示搜索结果）
    return const SizedBox.shrink();
  }

  /// 构建多条件过滤项：分组切换 + 分组排序
  List<FilterItem> _buildFilterItems() {
    final groupOptions = {
      for (var g in controller.groups)
        if (g != '全部') g: g,
    };

    return [
      // 分组切换
      FilterItem(
        id: 'group',
        title: 'checkin_groupFilterTitle'.tr,
        type: FilterType.tagsSingle,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildSingleChoiceFilter(
            context: context,
            currentValue: currentValue,
            // 单选完成即返回第一层
            onChanged: (value) => onChanged(value, done: true),
            options: groupOptions,
            allItemsKey: 'all',
            allItemsLabel: 'checkin_allGroups'.tr,
          );
        },
        getBadge:
            (value) => FilterBuilders.singleChoiceBadge(value, groupOptions),
        // 详情层最右侧的"管理分组"入口
        trailing: DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.layers,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: 'checkin_manageGroupsTitle'.tr,
                onPressed: controller.showGroupManagementDialog,
              );
            },
          ),
        ),
      ),

      // 分组排序
      FilterItem(
        id: 'sort',
        title: 'checkin_sortFilterTitle'.tr,
        type: FilterType.custom,
        initialValue: {
          'type': controller.currentSortType.index,
          'reversed': controller.isReversed,
        },
        getBadge: (value) {
          if (value is Map && value['type'] != null) {
            final type = GroupSortType.values[value['type'] as int];
            return GroupSortService.getSortTypeName(type, context);
          }
          return null;
        },
        builder: (context, currentValue, onChanged) {
          final value = (currentValue as Map<String, dynamic>?) ?? {};
          final sortType = GroupSortType.values[
            value['type'] as int? ?? GroupSortType.upcoming.index
          ];
          final reversed = value['reversed'] as bool? ?? false;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in GroupSortType.values)
                DSChip(
                  label: GroupSortService.getSortTypeName(type, context),
                  icon: type == sortType ? DsIconKind.check : DsIconKind.sort,
                  selected: type == sortType,
                  onSelected: (selected) {
                    if (selected) {
                      onChanged({...value, 'type': type.index}, done: true);
                    }
                  },
                ),
              DSChip(
                label: 'checkin_reverseSort'.tr,
                icon: DsIconKind.sort,
                selected: reversed,
                onSelected: (selected) {
                  onChanged({...value, 'reversed': selected}, done: true);
                },
              ),
            ],
          );
        },
      ),
    ];
  }

  /// 处理多条件过滤栏变化
  void _handleFilterChanged(Map<String, dynamic> values) {
    controller.applyFilters(values);
    _updateRouteContext();
    if (mounted) setState(() {});
  }

  /// 根据 itemId 显示打卡记录对话框
  void _showCheckinDialogForItem(String itemId, [String? targetDate]) {
    // 查找对应的打卡项目
    final item = controller.checkinItems.firstWhere(
      (item) => item.id == itemId,
      orElse: () => throw Exception('未找到ID为 $itemId 的打卡项目'),
    );

    // 解析目标日期，如果未提供则使用当前日期
    DateTime? selectedDate;
    if (targetDate != null && targetDate.isNotEmpty) {
      try {
        final parts = targetDate.split('-');
        if (parts.length == 3) {
          selectedDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      } catch (e) {
        debugPrint('解析日期失败: $targetDate, 错误: $e');
      }
    }
    // 如果没有指定日期，使用当前日期
    selectedDate ??= DateTime.now();

    // 延迟一帧以确保界面完全加载
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      showDSDialog(
        context: context,
        theme: DSThemeBridge.resolve(context),
        builder:
            (context) => CheckinRecordDialog(
              item: item,
              controller: controller,
              onCheckinCompleted: _handleStateChanged,
              selectedDate: selectedDate,
            ),
      );
    });
  }
}
