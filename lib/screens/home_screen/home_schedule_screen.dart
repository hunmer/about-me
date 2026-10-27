import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/managers/home_date_controller.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/screens/home_screen/widgets/date_view_grid.dart';
import 'package:aboutme/screens/home_screen/widgets/home_date_bar.dart';
import 'package:aboutme/screens/home_screen/widgets/quick_create_dialog.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';

/// 日程页（日期数据视图）
///
/// 与主屏幕（看板，[HomeScreenView]）完全独立：
/// 导航栏统一走 [SuperCupertinoNavigationWrapper]，
/// 卡片类型筛选与排序收敛到其多条件过滤栏（排序为过滤栏尾部圆钮），
/// 日期横条固定在 body 顶部，选中日期与排序方式统一存放在
/// [HomeDateController]。
///
/// 本页为 `/jelly_home` 路由下的 tab 内嵌页，导航栏不参与路由
/// hero 转场（`transitionBetweenRoutes: false`）。
class HomeScheduleScreen extends StatefulWidget {
  const HomeScheduleScreen({super.key});

  @override
  State<HomeScheduleScreen> createState() => _HomeScheduleScreenState();
}

class _HomeScheduleScreenState extends State<HomeScheduleScreen> {
  /// 多条件过滤状态（卡片类型筛选）
  Map<String, dynamic> _multiFilters = {};

  /// 日期驱动的卡片定义（筛选项来源）
  List<HomeWidget> get _dateWidgets =>
      HomeWidgetRegistry().getAllWidgets().where((w) => w.isDateDriven).toList();

  /// 被筛选隐藏的卡片类型 id（全部取消勾选时不过滤，显示全部）
  Set<String> _hiddenCardIds() {
    final map = _multiFilters['cardTypes'];
    if (map is! Map<String, bool>) return const {};
    if (!map.values.any((v) => v)) return const {};
    return {for (final entry in map.entries) if (!entry.value) entry.key};
  }

  /// 构建多条件过滤项
  List<FilterItem> _buildFilterItems() {
    final options = {for (final w in _dateWidgets) w.id: w.name};

    return [
      // 卡片类型多选过滤（控制日期视图中显示哪几类卡片）
      if (options.isNotEmpty)
        FilterItem(
          id: 'cardTypes',
          title: 'home_filterCardTypes'.tr,
          type: FilterType.checkbox,
          builder: (context, currentValue, onChanged) {
            return FilterBuilders.buildCheckboxFilter(
              context: context,
              currentValue: currentValue,
              onChanged: onChanged,
              options: options,
            );
          },
          getBadge: FilterBuilders.checkboxBadge,
          initialValue: {for (final id in options.keys) id: true},
        ),
    ];
  }

  /// 排序按钮（过滤栏第一层尾部圆形按钮，点击 DSPopover 弹菜单）
  Widget _buildSortButton() {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final dateController = HomeDateController();

          return DSPopover(
            width: 150,
            contentBuilder: (popoverContext, close) {
              final popoverTheme = DSThemeBridge.resolve(popoverContext);
              Widget menuRow(DateViewSortOption option) {
                return Pressable(
                  onPressed: () {
                    close();
                    dateController.setSortOption(option);
                  },
                  builder: (context, states) {
                    final pressed = states.contains(WidgetState.pressed);
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: popoverTheme.spacing.sm,
                        vertical: popoverTheme.spacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: pressed ? popoverTheme.surfaceAlt : null,
                        borderRadius: popoverTheme.radii.sm,
                      ),
                      child: Row(
                        children: [
                          DsIcon(
                            dateController.sortOption == option
                                ? DsIconKind.check
                                : DsIconKind.sort,
                            size: 18,
                            color: popoverTheme.text,
                          ),
                          SizedBox(width: popoverTheme.spacing.sm),
                          Text(
                            _optionLabel(option),
                            style: DsTypography.body.copyWith(
                              color: popoverTheme.text,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final option in DateViewSortOption.values)
                    menuRow(option),
                ],
              );
            },
            child: JellyBox(
              width: 36,
              height: 36,
              radius: theme.radii.circle,
              color: theme.surfaceAlt,
              child: Center(
                child: DsIcon(
                  DsIconKind.sort,
                  size: 18,
                  color: theme.textSub,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _optionLabel(DateViewSortOption option) {
    switch (option) {
      case DateViewSortOption.def:
        return 'home_sortDefault'.tr;
      case DateViewSortOption.priority:
        return 'home_sortPriority'.tr;
      case DateViewSortOption.time:
        return 'home_sortTime'.tr;
    }
  }

  /// 应用多条件过滤（postFrameCallback 避免在 build 阶段 setState）
  void _applyMultiFilters(Map<String, dynamic> filters) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _multiFilters = filters);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SuperCupertinoNavigationWrapper(
      title: Text('home_scheduleTitle'.tr),
      // tab 内嵌页：不参与路由 hero 转场，避免与同路由其他导航栏 tag 冲突
      transitionBetweenRoutes: false,
      enableLargeTitle: false,
      // 锁死外层滚动联动：body 内层网格滚到顶后继续拖不再把
      // body（日期横条）整体顶入导航栏下方，日期横条恒固定显示
      forceCollapsed: true,
      // 卡片类型筛选 + 排序统一收敛到多条件过滤栏（design.md §8）
      enableMultiFilter: true,
      multiFilterItems: _buildFilterItems(),
      onMultiFilterChanged: _applyMultiFilters,
      multiFilterBarTrailing: _buildSortButton(),
      body: Stack(
        children: [
          Column(
            children: [
              // 日期横条：切换当前选中日期，日期卡片跟随刷新
              const HomeDateBar(),
              // 底部留出悬浮导航栏的高度，最后一行卡片可完整滚出遮挡区
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom,
                  ),
                  child: HomeDateViewGrid(hiddenWidgetIds: _hiddenCardIds()),
                ),
              ),
            ],
          ),
          // wrapper 不透传 floatingActionButton，FAB 以 Stack 方式叠加
          Positioned(
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: DSThemeBridge(
              // DSFab 内部取 AppTheme，需包桥
              child: Builder(
                builder: (_) =>
                    DSFab(onPressed: () => _showQuickCreateDialog(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 弹出快速新建对话框
  ///
  /// 编辑界面以日程当前选中日期为默认日期
  void _showQuickCreateDialog(BuildContext context) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => QuickCreateDialog(
            onSelected: (item) {
              item.onCreate(context, HomeDateController().date);
            },
          ),
    );
  }
}
