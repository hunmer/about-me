import 'dart:convert';

import 'package:get/get.dart';
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/js_bridge/js_bridge_plugin.dart';
import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/plugins/tracker/models/goal.dart';
import 'package:aboutme/plugins/tracker/screens/goal_detail_screen.dart';
import 'package:aboutme/plugins/tracker/screens/search_results_screen.dart';
import 'package:aboutme/plugins/tracker/widgets/goal_edit_page.dart';
import 'package:provider/provider.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/core/services/plugin_data_selector/index.dart';
import 'package:shared_models/shared_models.dart';
import 'controllers/tracker_controller.dart';
import 'screens/home_screen.dart';
import 'repositories/client_tracker_repository.dart';

export 'models/goal.dart';
export 'models/record.dart';
export 'controllers/tracker_controller.dart';
export 'widgets/goal_card.dart';
export 'widgets/goal_detail_page.dart';
export 'widgets/goal_edit_page.dart';
export 'widgets/record_dialog.dart';
export 'utils/date_utils.dart';
export 'utils/tracker_notification_utils.dart';

part 'tracker_js_api.dart';
part 'tracker_data_selectors.dart';

/// 目标缓存更新事件参数（携带数据，性能优化）
class TrackerCacheUpdatedEventArgs extends EventArgs {
  /// 所有目标列表
  final List<Goal> goals;

  /// 目标数量
  final int count;

  /// 缓存日期
  final DateTime cacheDate;

  TrackerCacheUpdatedEventArgs({required this.goals, required this.cacheDate})
    : count = goals.length,
      super('tracker_cache_updated');
}

class TrackerMainView extends StatefulWidget {
  final String? initialGoalId;

  const TrackerMainView({super.key, this.initialGoalId});

  @override
  State<TrackerMainView> createState() => _TrackerMainViewState();
}

class _TrackerMainViewState extends State<TrackerMainView> {
  String _searchQuery = '';
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    // 恢复持久化的视图偏好（默认网格）
    _isGridView = TrackerPlugin.instance.settings['is_grid_view'] != false;
    // 如果有 initialGoalId，在初始化后跳转到目标详情
    if (widget.initialGoalId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToGoalDetail(widget.initialGoalId!);
      });
    }
  }

  void _toggleGridView() {
    setState(() => _isGridView = !_isGridView);
    // 持久化视图偏好
    TrackerPlugin.instance.updateSettings({'is_grid_view': _isGridView});
  }

  void _navigateToGoalDetail(String goalId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => GoalDetailScreen(goalId: goalId)),
    );
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return SuperCupertinoNavigationWrapper(
      title: Text(
        'tracker_goalTracking'.tr,
        style: DsTypography.title.copyWith(color: theme.text, fontSize: 16),
      ),
      largeTitle: 'tracker_goalTracking'.tr,

      enableSearchBar: true,
      searchPlaceholder: 'tracker_searchPlaceholder'.tr,
      onSearchChanged: _onSearchChanged,
      actions: [
        // 第三方导航栏回调：DS 组件需包 DSThemeBridge
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                // 显示可切换到的目标视图图标
                icon:
                    _isGridView ? DsIconKind.list : DsIconKind.grid,
                size: 38,
                color: theme.surface,
                iconColor: theme.text,
                tooltip: '切换视图',
                onPressed: () => setState(() => _isGridView = !_isGridView),
              );
            },
          ),
        ),
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.plus,
                size: 38,
                color: theme.surface,
                iconColor: theme.text,
                tooltip: '添加目标',
                onPressed: () {
                  NavigationHelper.openContainerWithHero(
                    context,
                    (context) => GoalEditPage(
                      controller: TrackerPlugin.instance.controller,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
      searchBody: ChangeNotifierProvider.value(
        value: TrackerPlugin.instance.controller,
        child: SearchResultsScreen(searchQuery: _searchQuery),
      ),
      body: ChangeNotifierProvider.value(
        value: TrackerPlugin.instance.controller,
        child: HomeScreen(isGridView: _isGridView),
      ),
    );
  }
}

class TrackerPlugin extends PluginBase with ChangeNotifier, JSBridgePlugin {
  static TrackerPlugin? _instance;

  // 构造函数中初始化实例
  TrackerPlugin() {
    // 首个实例成为单例：BuiltinPlugins.createAll() 可能被重复调用
    // (如设置页枚举插件)，新实例无条件覆盖会导致未注入 storage 的
    // 裸实例替换已注册实例
    _instance ??= this;
  }

  // 获取插件实例的静态方法
  static TrackerPlugin get instance {
    _instance ??= TrackerPlugin();
    return _instance!;
  }

  late final TrackerController _controller = TrackerController();
  TrackerController get controller => _controller;

  /// 支持刷新的文件路径前缀
  static const List<String> _refreshableFiles = ['tracker/'];

  @override
  bool supportsFileRefresh(String filePath) {
    return _refreshableFiles.any((f) => filePath.startsWith(f));
  }

  @override
  Future<bool> refreshData([PluginRefreshDataArgs? args]) async {
    try {
      debugPrint('[TrackerPlugin] 开始刷新数据, 文件: ${args?.filePath}');
      await _controller.reloadData();
      debugPrint('[TrackerPlugin] 数据刷新成功');
      return true;
    } catch (e) {
      debugPrint('[TrackerPlugin] 数据刷新失败: $e');
      return false;
    }
  }

  // UseCase 实例
  late final TrackerUseCase _trackerUseCase;
  TrackerUseCase get trackerUseCase => _trackerUseCase;
  @override
  String get id => 'tracker';

  @override
  Color get color => Colors.red;

  @override
  IconData get icon => Icons.track_changes;

  @override
  Future<void> initialize() async {
    // 初始化 UseCase（需要 storage）
    _trackerUseCase = TrackerUseCase(
      ClientTrackerRepository(storage: storage, pluginId: id),
    );

    // 不再在插件初始化时初始化通知系统,改为在开始计时时才初始化
    await _controller.loadInitialData();

    // 注册 JS API（最后一步）
    await registerJSAPI();

    // 注册数据选择器
    _registerDataSelectors();
  }

  @override
  Future<void> registerToApp(
    PluginManager pluginManager,
    ConfigManager configManager,
  ) async {
    // 插件已在 initialize() 中完成初始化
    // 这里可以添加额外的应用级注册逻辑
  }

  @override
  Widget buildMainView(BuildContext context) {
    return const TrackerMainView();
  }

  /// 打开目标详情页
  void openGoalDetail(BuildContext context, Goal goal) {
    NavigationHelper.push(
      context,
      ChangeNotifierProvider.value(
        value: _controller,
        child: GoalDetailScreen(goal: goal),
      ),
    );
  }

  // ========== 小组件统计方法 ==========

  /// 获取总目标数量
  int getGoalCount() {
    return _controller.getGoalCount();
  }

  /// 获取进行中的目标数量
  int getActiveGoalCount() {
    return _controller.goals.where((g) => !g.isCompleted).length;
  }

  /// 获取今日新增记录数
  int getTodayRecordCount() {
    return _controller.getTodayRecordCount();
  }

  @override
  String? getPluginName(context) {
    return 'tracker_name'.tr;
  }

  @override
  Widget buildCardView(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final controller = TrackerController();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部图标和标题（icon/color 为插件注册表身份，保留 Material）
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                'tracker_name'.tr,
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 统计信息卡片
          Column(
            children: [
              // 第一行 - 今日完成和本月完成
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 今日完成
                  Column(
                    children: [
                      Text(
                        'tracker_todayComplete'.tr,
                        style: DsTypography.body.copyWith(color: theme.text),
                      ),
                      Text(
                        controller.getTodayCompletedGoals().toString(),
                        style: DsTypography.body.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.success,
                        ),
                      ),
                    ],
                  ),

                  // 本月完成
                  Column(
                    children: [
                      Text(
                        'tracker_thisMonthComplete'.tr,
                        style: DsTypography.body.copyWith(color: theme.text),
                      ),
                      Text(
                        controller.getMonthCompletedGoals().toString(),
                        style: DsTypography.body.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Map<String, Function> defineJSAPI() {
    return {
      // 目标相关
      'getGoals': _jsGetGoals,
      'getGoal': _jsGetGoal,
      'createGoal': _jsCreateGoal,
      'updateGoal': _jsUpdateGoal,
      'deleteGoal': _jsDeleteGoal,

      // 记录相关
      'recordData': _jsRecordData,
      'getRecords': _jsGetRecords,
      'deleteRecord': _jsDeleteRecord,

      // 统计相关
      'getProgress': _jsGetProgress,
      'getStats': _jsGetStats,
    };
  }
}
