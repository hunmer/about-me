import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/js_bridge/js_bridge_plugin.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/services/plugin_data_selector/index.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/lazy_indexed_stack.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:get/get.dart';
import 'screens/diary_calendar_screen.dart';
import 'screens/diary_editor_screen.dart';
import 'screens/diary_stats_screen.dart';
import 'models/diary_entry.dart';
import 'widgets/diary_query_guard.dart';
import 'utils/diary_utils.dart';
import 'repositories/client_diary_repository.dart';
import 'package:shared_models/usecases/diary/diary_usecase.dart';

part 'diary_js_api.dart';
part 'diary_data_selectors.dart';

/// 日记创建事件参数
class DiaryEntryCreatedEventArgs extends EventArgs {
  final DiaryEntry entry;

  DiaryEntryCreatedEventArgs(this.entry) : super('diary_entry_created');
}

/// 日记更新事件参数
class DiaryEntryUpdatedEventArgs extends EventArgs {
  final DiaryEntry entry;

  DiaryEntryUpdatedEventArgs(this.entry) : super('diary_entry_updated');
}

/// 日记删除事件参数
class DiaryEntryDeletedEventArgs extends EventArgs {
  final DateTime date;

  DiaryEntryDeletedEventArgs(this.date) : super('diary_entry_deleted');
}

/// 日记缓存更新事件参数（携带数据，性能优化）
class DiaryCacheUpdatedEventArgs extends EventArgs {
  /// 本月日记条目列表（日期, 条目）
  final List<(DateTime, DiaryEntry)> entries;

  /// 当前月份
  final DateTime month;

  /// 条目数量
  final int count;
  final bool hasSnapshot;
  final Object? error;
  bool get isStale => hasSnapshot && error != null;

  DiaryCacheUpdatedEventArgs({
    required this.entries,
    required this.month,
    this.hasSnapshot = true,
    this.error,
  }) : count = entries.length,
       super('diary_cache_updated');
}

/// 日记插件主视图
class DiaryMainView extends StatefulWidget {
  final DateTime? initialDate;

  const DiaryMainView({super.key, this.initialDate});

  @override
  State<DiaryMainView> createState() => _DiaryMainViewState();
}

class _DiaryMainViewState extends State<DiaryMainView> {
  late DiaryPlugin _plugin;

  // 当前 tab：0 日历 / 1 统计
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _plugin = PluginManager.instance.getPlugin('diary') as DiaryPlugin;
    // 初始化时设置路由上下文
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateRouteContext());
  }

  /// 更新路由上下文，使"询问当前上下文"功能能获取到当前tab状态
  void _updateRouteContext() {
    if (!mounted) return;
    RouteHistoryManager.updateCurrentContext(
      pageId: _currentTab == 1 ? '/diary_stats' : '/diary',
      title: _currentTab == 1 ? '日记统计' : '日记日历',
      params: {'tabIndex': _currentTab},
    );
  }

  /// subbar 右侧圆钮：新建/编辑今日日记（编辑选中日走详情 sheet 的编辑按钮）
  Future<void> _createTodayDiary() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DiaryEntry? entry;
    for (final cached in _plugin.getMonthlyDiaryEntriesSync()) {
      if (cached.$1.isAtSameMomentAs(today)) {
        entry = cached.$2;
        break;
      }
    }
    await NavigationHelper.push(
      context,
      DiaryEditorScreen(
        date: today,
        storage: _plugin.storage,
        initialTitle: entry?.title ?? '',
        initialContent: entry?.content ?? '',
      ),
    );
    if (mounted) {
      // 日历 tab 订阅该事件重新加载条目（原 FAB 的 .then 刷新由这里接管）
      EventManager.instance.broadcast('diary_refresh', EventArgs());
    }
  }

  /// 底部弧形圆盘导航栏：日历/统计双 tab，subbar 右侧圆钮为新建入口
  Widget _buildBottomBar() {
    final theme = DSThemeBridge.resolve(context);
    return SafeArea(
      top: false,
      child: DSBottomNavigation(
        items: [
          DSNavItem(icon: DsIconKind.calendar, label: '日历'),
          DSNavItem(icon: DsIconKind.chart, label: '统计'),
        ],
        currentIndex: _currentTab,
        // onTap 不能为 null：null 会触发内部 IgnorePointer 包裹整个导航栏，
        // 连同 trailingAction 圆钮的点击一起被吞掉
        onTap: (index) {
          setState(() => _currentTab = index);
          _updateRouteContext();
        },
        trailingAction: DsIcon(DsIconKind.plus, size: 20, color: theme.text),
        onTrailingTap: _createTodayDiary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LazyIndexedStack(
          index: _currentTab,
          children: [
            DiaryCalendarScreen(
              storage: _plugin.storage,
              initialDate: widget.initialDate,
            ),
            const DiaryStatsScreen(),
          ],
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomBar()),
      ],
    );
  }
}

class DiaryPlugin extends BasePlugin with JSBridgePlugin {
  static DiaryPlugin? _instance;
  static DiaryPlugin get instance {
    if (_instance == null) {
      _instance = PluginManager.instance.getPlugin('diary') as DiaryPlugin?;
      if (_instance == null) {
        throw StateError('DiaryPlugin has not been initialized');
      }
    }
    return _instance!;
  }

  // UseCase 实例
  late final DiaryUseCase _diaryUseCase;

  // 初始化标志

  /// 支持刷新的文件路径前缀
  static const List<String> _refreshableFiles = ['diary/'];

  @override
  bool supportsFileRefresh(String filePath) {
    return _refreshableFiles.any((f) => filePath.startsWith(f));
  }

  @override
  Future<bool> refreshData([PluginRefreshDataArgs? args]) async {
    try {
      debugPrint('[DiaryPlugin] 开始刷新数据, 文件: ${args?.filePath}');
      AboutmeDataService.instance.revalidate();
      debugPrint('[DiaryPlugin] 数据刷新成功');
      return true;
    } catch (e) {
      debugPrint('[DiaryPlugin] 数据刷新失败: $e');
      return false;
    }
  }

  @override
  List<PluginSampleDataGroup> getSampleDataGroups() => [
    PluginSampleDataGroup(
      id: 'entries',
      title: 'diary_sampleEntriesTitle'.tr,
      description: 'diary_sampleEntriesDesc'.tr,
      apply: () => DiaryUtils.createSampleEntries(),
    ),
  ];

  // SDK 快照的 UI 适配；不独立维护权威数据或持久化状态。
  Map<DateTime, DiaryEntry>? _entriesSnapshot;
  Object? _lastQueryError;
  Future<void>? _refreshFuture;
  Object? get queryError => _lastQueryError;
  bool get hasQuerySnapshot => _entriesSnapshot != null;

  void _recordQueryError(Object error) {
    _lastQueryError = error;
    _broadcastSnapshot();
  }

  void _applySnapshot(Map<DateTime, DiaryEntry> entries) {
    _entriesSnapshot = entries;
    _lastQueryError = null;
    _broadcastSnapshot();
  }

  void _broadcastSnapshot() {
    final now = DateTime.now();
    eventManager.broadcast(
      'diary_cache_updated',
      DiaryCacheUpdatedEventArgs(
        entries: _monthlyEntries(),
        month: DateTime(now.year, now.month),
        hasSnapshot: hasQuerySnapshot,
        error: _lastQueryError,
      ),
    );
  }

  Future<void> refreshSnapshot() => _refreshFuture ??= _loadSnapshot();

  Future<void> _loadSnapshot() async {
    try {
      _applySnapshot(await DiaryUtils.loadDiaryEntries());
    } catch (error) {
      _recordQueryError(error);
      rethrow;
    } finally {
      _refreshFuture = null;
    }
  }

  List<(DateTime, DiaryEntry)> _monthlyEntries() {
    final now = DateTime.now();
    return (_entriesSnapshot?.entries ?? <MapEntry<DateTime, DiaryEntry>>[])
        .where(
          (entry) => entry.key.year == now.year && entry.key.month == now.month,
        )
        .map((entry) => (entry.key, entry.value))
        .toList()
      ..sort((a, b) => b.$1.compareTo(a.$1));
  }

  void _requestMissingSnapshot() {
    if (!hasQuerySnapshot && _lastQueryError == null) {
      unawaited(refreshSnapshot().then<void>((_) {}, onError: (Object _) {}));
    }
  }

  @override
  String get id => 'diary';

  @override
  Color get color => Colors.indigo;

  @override
  IconData get icon => Icons.book;

  @override
  String? getPluginName(context) {
    return 'diary_name'.tr;
  }

  Future<int> getTodayWordCount() async {
    await refreshSnapshot();
    return getTodayWordCountSync();
  }

  Future<int> getMonthWordCount() async {
    await refreshSnapshot();
    return getMonthWordCountSync();
  }

  Future<(int, int)> getMonthProgress() async {
    await refreshSnapshot();
    return getMonthProgressSync();
  }

  Future<List<(DateTime, DiaryEntry)>> getMonthlyDiaryEntries() async {
    await refreshSnapshot();
    return _monthlyEntries();
  }

  // 同步 getter 仅供展示；调用方必须结合 hasQuerySnapshot/queryError 展示状态。
  List<(DateTime, DiaryEntry)> getMonthlyDiaryEntriesSync() {
    _requestMissingSnapshot();
    return _monthlyEntries();
  }

  int getTodayWordCountSync() {
    _requestMissingSnapshot();
    final now = DateTime.now();
    final entry = _entriesSnapshot?[DateTime(now.year, now.month, now.day)];
    return entry == null
        ? 0
        : DiaryUtils.contentToPlainText(entry.content).trim().length;
  }

  int getMonthWordCountSync() {
    _requestMissingSnapshot();
    return _monthlyEntries().fold(
      0,
      (sum, entry) =>
          sum + DiaryUtils.contentToPlainText(entry.$2.content).trim().length,
    );
  }

  (int, int) getMonthProgressSync() {
    _requestMissingSnapshot();
    final now = DateTime.now();
    return (_monthlyEntries().length, DateTime(now.year, now.month + 1, 0).day);
  }

  @override
  Map<String, Function> defineJSAPI() {
    return {
      // 日记查询接口
      'getDiaries': _jsGetDiaries,
      'getDiary': _jsGetDiary,

      // 日记操作接口
      'saveDiary': _jsSaveDiary,
      'deleteDiary': _jsDeleteDiary,

      // 统计接口
      'getTodayStats': _jsGetTodayStats,
      'getMonthStats': _jsGetMonthStats,
      'getTodayWordCount': _jsGetTodayWordCount,
      'getMonthWordCount': _jsGetMonthWordCount,
      'getMonthProgress': _jsGetMonthProgress,

      // 日记条目操作接口（直接操作方法）
      'loadDiaryEntry': _jsLoadDiaryEntry,
      'saveDiaryEntry': _jsSaveDiaryEntry,
      'deleteDiaryEntry': _jsDeleteDiaryEntry,
      'hasEntryForDate': _jsHasEntryForDate,
      'getDiaryStats': _jsGetDiaryStats,

      // 日记查找接口
      'findDiaryBy': _jsFindDiaryBy,
      'findDiaryByDate': _jsFindDiaryByDate,
      'findDiaryByTitle': _jsFindDiaryByTitle,
    };
  }

  @override
  VoidCallback? buildCreatedDetailOpener(
    BuildContext context,
    String method,
    Map<String, dynamic> created,
  ) {
    if (method != 'saveDiary' && method != 'saveDiaryEntry') return null;
    final dateValue = created['date'];
    final date = dateValue is String ? DateTime.tryParse(dateValue) : null;
    if (date == null) return null;
    return () async {
      final entry = await DiaryUtils.loadDiaryEntry(date);
      if (entry == null || !context.mounted) return;
      SmoothBottomSheet.showScreen(
        context: context,
        screen: DiaryEditorScreen(
          date: date,
          storage: storage,
          initialTitle: entry.title,
          initialContent: entry.content,
          initialMood: entry.mood,
        ),
      );
    };
  }

  @override
  Future<void> initialize() async {
    // 初始化 UseCase
    final repository = ClientDiaryRepository();
    _diaryUseCase = DiaryUseCase(repository);

    // 注册数据选择器
    _registerDataSelectors();

    // 订阅日记事件以刷新缓存
    _setupEventListeners();

    // 注册 JS API（最后一步）
    await registerJSAPI();

    // 标记为已初始化

    // 初始化完成后主动刷新缓存，确保首次加载有数据；失败保留空缓存
    _requestMissingSnapshot();
  }

  StreamSubscription<Map<DateTime, DiaryEntry>>? _entriesSubscription;

  void _setupEventListeners() {
    _entriesSubscription = DiaryUtils.watchEntries().listen(
      _applySnapshot,
      onError: _recordQueryError,
    );
  }

  @override
  Future<void> registerToApp(
    PluginManager pluginManager,
    ConfigManager configManager,
  ) async {
    // 初始化插件
    // 插件已在 initialize() 中完成初始化
    // 这里可以添加额外的应用级注册逻辑
  }

  Future<void> dispose() async {
    await _entriesSubscription?.cancel();
  }

  @override
  Widget buildMainView(BuildContext context) {
    return DiaryMainView();
  }

  @override
  Widget buildCardView(BuildContext context) {
    final theme = Theme.of(context);

    return DiarySnapshotBuilder(
      builder: (context, entries) {
        final now = DateTime.now();
        final today = entries[DateTime(now.year, now.month, now.day)];
        final todayCount = today == null
            ? 0
            : DiaryUtils.contentToPlainText(today.content).trim().length;
        final monthly = entries.entries.where(
          (entry) => entry.key.year == now.year && entry.key.month == now.month,
        );
        final monthCount = monthly.fold<int>(
          0,
          (sum, entry) =>
              sum +
              DiaryUtils.contentToPlainText(entry.value.content).trim().length,
        );
        final completedDays = monthly.length;
        final totalDays = DateTime(now.year, now.month + 1, 0).day;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部图标和标题
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
                    'diary_name'.tr,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 统计信息卡片
              Column(
                children: [
                  // 第一行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            'diary_todayWordCount'.tr,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            '$todayCount',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: todayCount > 0
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const VerticalDivider(),
                      Column(
                        children: [
                          Text(
                            'diary_monthWordCount'.tr,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            '$monthCount',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 第二行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            'diary_monthProgress'.tr,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            '$completedDays/$totalDays',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: completedDays > 0
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
