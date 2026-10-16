import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/plugins/day/controllers/day_controller.dart';
import 'package:aboutme/plugins/day/widgets/sketch_milestone_card.dart';
import 'package:aboutme/plugins/day/screens/memorial_day_detail_screen.dart';
import 'package:aboutme/plugins/day/widgets/edit_memorial_day_dialog/edit_memorial_day_page.dart';
import 'package:aboutme/plugins/day/models/memorial_day.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';

/// 纪念日主页（v2 · Warm Paper Sketch 手绘里程碑网格）
///
/// 列表 UI 复刻设计稿 stitch_design_system_framework：
/// 2 列卡片网格 + 墨线错位底影 + 淡彩晕染 + 幽灵涂鸦图标。
class DayHomeScreenV2 extends StatefulWidget {
  const DayHomeScreenV2({super.key});

  @override
  State<DayHomeScreenV2> createState() => _DayHomeScreenV2State();
}

class _DayHomeScreenV2State extends State<DayHomeScreenV2> {
  // 搜索查询状态
  String _searchQuery = '';

  late DayController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DayController();
    _initializeController();
    // 订阅同步刷新事件
    EventManager.instance.subscribe('day_refresh', _handleSyncRefresh);
  }

  @override
  void dispose() {
    // 取消订阅，避免内存泄漏
    EventManager.instance.unsubscribe('day_refresh', _handleSyncRefresh);
    super.dispose();
  }

  /// 处理同步刷新事件
  void _handleSyncRefresh(EventArgs args) {
    debugPrint('[DayHomeScreenV2] 收到同步刷新事件');
    _controller.reloadData();
  }

  Future<void> _initializeController() async {
    await _controller.initialize();
    if (mounted) setState(() {});

    // 初始化时设置路由上下文
    _updateRouteContext();
  }

  /// 更新路由上下文,使"询问当前上下文"功能能获取到当前状态
  void _updateRouteContext() {
    final count = _controller.memorialDays.length;
    RouteHistoryManager.updateCurrentContext(
      pageId: "/day_list",
      title: '纪念日列表（共 $count 个）',
      params: {'count': count.toString()},
    );
  }

  Future<void> _showEditDialog(
    BuildContext context, [
    MemorialDay? memorialDay,
  ]) async {
    if (!mounted) return;

    // 新建/编辑：表单底部弹层（保存/删除经 DialogResult 返回）
    VoidCallback? saveMemorialDay;
    final result = await SmoothBottomSheet.showForm<DialogResult>(
      context: context,
      title: memorialDay == null
          ? 'day_addMemorialDay'.tr
          : 'day_editMemorialDay'.tr,
      child: EditMemorialDayPage(
        memorialDay: memorialDay,
        embedInSheet: true,
        onReady: (save) => saveMemorialDay = save,
      ),
      onSave: () => saveMemorialDay?.call(),
    );

    if (result == null) return; // 页面被异常关闭
    if (!mounted) return;

    switch (result.action) {
      case DialogAction.save:
        if (result.memorialDay != null) {
          if (memorialDay != null) {
            await _controller.updateMemorialDay(result.memorialDay!);
          } else {
            await _controller.addMemorialDay(result.memorialDay!);
          }
        }
        break;

      case DialogAction.delete:
        if (memorialDay != null) {
          await _controller.deleteMemorialDay(memorialDay.id);
        }
        break;

      case DialogAction.cancel:
        // 用户取消操作，不做任何处理
        break;
    }
  }

  /// 点击卡片进入详情页（笔记列表 + 新增笔记）
  Future<void> _openDetail(
    BuildContext context,
    MemorialDay memorialDay,
  ) async {
    await NavigationHelper.push(
      context,
      MemorialDayDetailScreen(
        memorialDay: memorialDay,
        controller: _controller,
      ),
    );
  }

  /// 长按卡片弹出操作菜单（编辑/删除）
  void _showCardMenu(MemorialDay memorialDay) {
    showDSBottomSheet(
      context: context,
      title: memorialDay.title,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DSSheetAction(
            icon: DsIconKind.edit,
            label: 'day_editMemorialDay'.tr,
            onTap: () {
              Navigator.pop(sheetContext);
              _showEditDialog(context, memorialDay);
            },
          ),
          DSSheetAction(
            icon: DsIconKind.trash,
            label: 'day_deleteMemorialDay'.tr,
            destructive: true,
            onTap: () {
              Navigator.pop(sheetContext);
              _controller.deleteMemorialDay(memorialDay.id);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<DayController>(
        builder: (context, controller, child) {
          return SuperCupertinoNavigationWrapper(
            title: Text('day_memorialDays'.tr),
            largeTitle: 'day_memorialDaysListTitle'.tr,

            // 启用搜索栏
            enableSearchBar: true,
            searchPlaceholder: 'day_searchPlaceholder'.tr,
            onSearchChanged: (query) {
              setState(() {
                _searchQuery = query;
              });
            },
            onSearchSubmitted: (query) {
              // 搜索提交时的逻辑
            },
            searchBody: _buildSearchResults(controller),
            // SuperAppBar 的 actions 经 Overlay 渲染,DS 组件需自带 DSThemeBridge
            actions: [_buildSortAction(controller)],
            body: DSThemeBridge(
              child: Builder(
                builder: (context) {
                  return Stack(
                    children: [
                      _buildBody(context, controller),
                      // FAB 覆盖层
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: DSIconButton(
                          icon: DsIconKind.plus,
                          size: 56,
                          onPressed: () => _showEditDialog(context),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// 排序菜单（DSPopover 经根 Overlay 展示,需 DSThemeBridge 包裹）
  Widget _buildSortAction(DayController controller) {
    return DSThemeBridge(
      child: Builder(
        builder: (buildContext) {
          final theme = DSThemeBridge.resolve(buildContext);
          return DSPopover(
            width: 190,
            contentBuilder: (popoverContext, close) {
              final popoverTheme = DSThemeBridge.resolve(popoverContext);

              Widget menuRow(SortMode value, String label) {
                return Pressable(
                  onPressed: () {
                    close();
                    controller.setSortMode(value);
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
                            controller.sortMode == value
                                ? DsIconKind.check
                                : DsIconKind.sort,
                            size: 18,
                            color: popoverTheme.text,
                          ),
                          SizedBox(width: popoverTheme.spacing.sm),
                          Text(
                            label,
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
                  menuRow(SortMode.upcoming, 'day_upcomingSort'.tr),
                  menuRow(SortMode.recent, 'day_recentSort'.tr),
                  menuRow(SortMode.manual, 'day_manualSort'.tr),
                ],
              );
            },
            child: JellyBox(
              width: 36,
              height: 36,
              radius: theme.radii.circle,
              color: theme.surfaceAlt,
              child: Center(
                child: DsIcon(DsIconKind.sort, size: 18, color: theme.textSub),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, DayController controller) {
    if (controller.memorialDays.isEmpty) {
      return Center(
        child: DSEmptyState(
          emoji: '🗓️',
          title: 'day_noMemorialDays'.tr,
          actionLabel: 'day_addMemorialDay'.tr,
          onAction: () => _showEditDialog(context),
        ),
      );
    }

    return _buildGrid(context, controller.memorialDays, controller.isDraggable);
  }

  /// 2 列里程碑卡片网格（手动排序模式下支持拖拽）
  Widget _buildGrid(
    BuildContext context,
    List<MemorialDay> days,
    bool allowReorder,
  ) {
    final delegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      // ≥ 贴条出血,避免上一行贴条压盖
      mainAxisSpacing: 16,
      crossAxisSpacing: 14,
      mainAxisExtent: 192,
    );
    final padding = EdgeInsets.only(
      left: 16,
      right: 16,
      top: 16,
      // 底部让位 FAB
      bottom: MediaQuery.paddingOf(context).bottom + 90,
    );

    Widget cardBuilder(BuildContext context, int index) {
      // 手绘便签:随机倾斜 + 贴条(角度由 id 哈希确定);
      // key 上移供 ReorderableGridView 拖拽排序
      return HandDrawnStickyItem(
        key: ValueKey(days[index].id),
        tiltKey: days[index].id,
        child: SketchMilestoneCard(
          memorialDay: days[index],
          index: index,
          isDraggable: allowReorder,
          onTap: () => _openDetail(context, days[index]),
          onLongPress: () => _showCardMenu(days[index]),
        ),
      );
    }

    if (!allowReorder) {
      return GridView.builder(
        padding: padding,
        gridDelegate: delegate,
        itemCount: days.length,
        itemBuilder: cardBuilder,
      );
    }

    return ReorderableGridView.builder(
      padding: padding,
      gridDelegate: delegate,
      itemCount: days.length,
      itemBuilder: cardBuilder,
      onReorder: (oldIndex, newIndex) async {
        await _controller.reorderMemorialDays(oldIndex, newIndex);
      },
      // 自定义拖拽装饰，移除边框
      dragWidgetBuilder: (index, child) {
        return Material(
          color: Colors.transparent,
          elevation: 0,
          child: Transform.scale(scale: 1.05, child: child),
        );
      },
    );
  }

  /// 构建搜索结果（与主界面同款网格，不支持拖拽）
  Widget _buildSearchResults(DayController controller) {
    if (_searchQuery.isEmpty) {
      return _searchHint(
        icon: DsIconKind.search,
        title: 'day_searchHintTitle'.tr,
        subtitle: 'day_searchHintSubtitle'.tr,
      );
    }

    final query = _searchQuery.toLowerCase();
    final filteredDays = controller.memorialDays.where((memorialDay) {
      final titleMatch = memorialDay.title.toLowerCase().contains(query);
      final notesMatch = memorialDay.notes.any(
        (note) => note.toLowerCase().contains(query),
      );
      return titleMatch || notesMatch;
    }).toList();

    if (filteredDays.isEmpty) {
      return _searchHint(
        icon: DsIconKind.calendarCheck,
        title: 'day_searchNoResult'.tr,
        subtitle: 'day_searchNoResultHint'.tr,
      );
    }

    return DSThemeBridge(
      child: Builder(
        builder: (context) => _buildGrid(context, filteredDays, false),
      ),
    );
  }

  Widget _searchHint({
    required DsIconKind icon,
    required String title,
    required String subtitle,
  }) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DsIcon(icon, size: 56, color: theme.textSub),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: DsTypography.heading.copyWith(color: theme.textSub),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: DsTypography.caption.copyWith(
                    color: theme.textSub.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
