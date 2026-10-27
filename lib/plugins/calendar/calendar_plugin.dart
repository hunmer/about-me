import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:aboutme/utils/platform_utils.dart';
import 'package:skribble/skribble.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart' as syncfusion;
import 'package:aboutme/widgets/aboutme_sf_calendar/aboutme_sf_calendar.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/core/js_bridge/js_bridge_plugin.dart';
import 'package:aboutme/core/widgets/custom_bottom_bar.dart';
import 'package:aboutme/core/widgets/keep_alive_wrapper.dart';
import 'package:aboutme/plugins/base_plugin.dart';
import './controllers/calendar_controller.dart' as app;
import './models/event.dart';
import './pages/event_edit_page.dart';
import './pages/event_list_page.dart';
import './widgets/event_detail_card.dart';
import './widgets/onboarding_system_calendar_setup.dart';
import 'package:aboutme/core/services/plugin_widget_sync_helper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/core/services/plugin_data_selector/index.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'services/system_calendar_settings.dart';

// UseCase 架构导入
import 'package:shared_models/usecases/calendar/calendar_usecase.dart';
import './repositories/client_calendar_repository.dart';
import 'services/calendar_api_params.dart';

// 代码分离：JS API 和数据选择器
part 'calendar_js_api.dart';
part 'calendar_data_selectors.dart';

class CalendarPlugin extends BasePlugin with JSBridgePlugin {
  static CalendarPlugin? _instance;
  static CalendarPlugin get instance {
    if (_instance == null) {
      _instance =
          PluginManager.instance.getPlugin('calendar') as CalendarPlugin?;
      if (_instance == null) {
        throw StateError('CalendarPlugin has not been initialized');
      }
    }
    return _instance!;
  }

  /// 支持刷新的文件路径前缀
  static const List<String> _refreshableFiles = ['calendar/'];

  @override
  bool supportsFileRefresh(String filePath) {
    return _refreshableFiles.any((f) => filePath.startsWith(f));
  }

  @override
  Future<bool> refreshData([PluginRefreshDataArgs? args]) async {
    try {
      debugPrint('[CalendarPlugin] 开始刷新数据, 文件: ${args?.filePath}');
      // 重新加载日历事件
      await controller.reloadEvents();
      // 同步小组件数据
      syncWidgetData();
      debugPrint('[CalendarPlugin] 数据刷新成功');
      return true;
    } catch (e) {
      debugPrint('[CalendarPlugin] 数据刷新失败: $e');
      return false;
    }
  }

  // 总控制器，管理所有日历相关服务
  late final app.CalendarController controller;
  // SyncFusion日历控制器
  late final syncfusion.CalendarController sfController;
  // UseCase 实例，用于业务逻辑
  late final CalendarUseCase calendarUseCase;

  final List<syncfusion.CalendarView> allowedViews = <syncfusion.CalendarView>[
    syncfusion.CalendarView.day,
    syncfusion.CalendarView.week,
    syncfusion.CalendarView.workWeek,
    syncfusion.CalendarView.timelineDay,
    syncfusion.CalendarView.timelineWeek,
    syncfusion.CalendarView.timelineWorkWeek,
    syncfusion.CalendarView.month,
    syncfusion.CalendarView.schedule,
  ];

  @override
  String get id => 'calendar';

  @override
  Color get color => const Color.fromARGB(255, 211, 91, 91);

  @override
  IconData get icon => Icons.calendar_month;

  @override
  Future<void> initialize() async {
    // 初始化总控制器
    controller = app.CalendarController(storageManager);
    sfController = syncfusion.CalendarController();

    // 初始化 UseCase
    final repository = ClientCalendarRepository(
      controller: controller,
      pluginColor: color,
    );
    calendarUseCase = CalendarUseCase(repository);

    // 从存储中读取上次使用的视图
    await controller.reloadEvents();
    final viewData = await controller.getPreferences();
    final String? lastView = viewData['view'] as String?;
    if (lastView != null) {
      sfController.view = _getCalendarViewFromString(lastView);
    } else {
      sfController.view = syncfusion.CalendarView.month;
    }

    // 注册数据选择器
    _registerDataSelectors();

    await registerJSAPI();
  }

  @override
  List<PluginOnboardingStep> getOnboardingSteps(BuildContext context) => [
    PluginOnboardingStep(
      icon: Icons.calendar_month,
      title: 'calendar_onboardingWelcomeTitle'.tr,
      description: 'calendar_onboardingWelcomeDesc'.tr,
    ),
    // 系统日历导入仅移动端可用
    if (PlatformUtils.isMobile)
      PluginOnboardingStep(
        icon: Icons.sync,
        title: 'calendar_onboardingSystemCalendarTitle'.tr,
        description: 'calendar_onboardingSystemCalendarDesc'.tr,
        builder: (context, values) =>
            OnboardingSystemCalendarSetup(values: values),
      ),
  ];

  /// 应用引导收集的系统日历导入设置并立即生效
  ///
  /// 跳过引导（values 未收集）时保持默认设置不变
  @override
  Future<void> onOnboardingComplete(
    BuildContext context,
    Map<String, dynamic> values,
  ) async {
    final importSystemCalendar = values['importSystemCalendar'] as bool?;
    if (importSystemCalendar != null) {
      final settings = await SystemCalendarSettings.load()
        ..enabled = importSystemCalendar
        ..includeHolidays = (values['importHolidays'] as bool?) ?? true;
      await settings.save();
    }
    await controller.loadSystemEvents();
  }

  @override
  VoidCallback? buildCreatedDetailOpener(
    BuildContext context,
    String method,
    Map<String, dynamic> created,
  ) {
    if (method != 'createEvent') return null;
    final eventId = created['id'] as String?;
    if (eventId == null) return null;
    return () {
      final event = controller.events.firstWhereOrNull((e) => e.id == eventId);
      if (event == null) return;
      showEventDetails(context, event);
    };
  }

  @override
  Map<String, Function> defineJSAPI() {
    return {
      // 事件查询
      'getEvents': _jsGetEvents,
      'getTodayEvents': _jsGetTodayEvents,
      'getEventsByDateRange': _jsGetEventsByDateRange,
      'getUpcoming': _jsGetUpcoming,

      // 事件操作
      'createEvent': _jsCreateEvent,
      'updateEvent': _jsUpdateEvent,
      'deleteEvent': _jsDeleteEvent,
      'completeEvent': _jsCompleteEvent,

      // 已完成事件
      'getCompletedEvents': _jsGetCompletedEvents,

      // 事件查找方法
      'findEventBy': _jsFindEventBy,
      'findEventById': _jsFindEventById,
      'findEventByTitle': _jsFindEventByTitle,
    };
  }

  syncfusion.CalendarView _getCalendarViewFromString(String viewString) {
    switch (viewString) {
      case 'day':
        return syncfusion.CalendarView.day;
      case 'week':
        return syncfusion.CalendarView.week;
      case 'workWeek':
        return syncfusion.CalendarView.workWeek;
      case 'month':
        return syncfusion.CalendarView.month;
      case 'timelineDay':
        return syncfusion.CalendarView.timelineDay;
      case 'timelineWeek':
        return syncfusion.CalendarView.timelineWeek;
      case 'timelineWorkWeek':
        return syncfusion.CalendarView.timelineWorkWeek;
      case 'schedule':
        return syncfusion.CalendarView.schedule;
      default:
        return syncfusion.CalendarView.month;
    }
  }

  String _getStringFromCalendarView(syncfusion.CalendarView view) {
    switch (view) {
      case syncfusion.CalendarView.day:
        return 'day';
      case syncfusion.CalendarView.week:
        return 'week';
      case syncfusion.CalendarView.workWeek:
        return 'workWeek';
      case syncfusion.CalendarView.month:
        return 'month';
      case syncfusion.CalendarView.timelineDay:
        return 'timelineDay';
      case syncfusion.CalendarView.timelineWeek:
        return 'timelineWeek';
      case syncfusion.CalendarView.timelineWorkWeek:
        return 'timelineWorkWeek';
      case syncfusion.CalendarView.schedule:
        return 'schedule';
      default:
        return 'month';
    }
  }

  void onViewChanged(
    syncfusion.ViewChangedDetails details,
    VoidCallback? updateRouteContext,
  ) async {
    // 保存最后使用的视图
    await controller.setView(_getStringFromCalendarView(sfController.view!));

    // 更新路由上下文
    if (updateRouteContext != null) {
      updateRouteContext();
    }
  }

  @override
  Future<void> registerToApp(
    PluginManager pluginManager,
    ConfigManager configManager,
  ) async {
    // 加载系统日历事件
    await controller.loadSystemEvents();

    // 监听日历事件变化，同步小组件数据
    controller.addListener(() {
      syncWidgetData();
    });

    // 初始同步
    syncWidgetData();

    // 处理小组件中待完成的事件（首次启动时）
    PluginWidgetSyncHelper.instance.syncPendingCalendarEventsOnStartup();
  }

  // ========== 小组件数据同步 ==========

  /// 同步日历月视图小组件数据
  Future<void> syncWidgetData() async {
    // 只在 Android 平台同步
    if (!PlatformUtils.isAndroid) return;

    try {
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

      // 获取本月第一天是星期几 (1=周一, 7=周日)
      int firstWeekday = firstDayOfMonth.weekday;

      // 获取本月所有事件
      final allEvents = controller.getAllEvents();
      final monthEvents = allEvents.where((event) {
        return event.startTime.isAfter(
              firstDayOfMonth.subtract(const Duration(seconds: 1)),
            ) &&
            event.startTime.isBefore(
              lastDayOfMonth.add(const Duration(days: 1)),
            );
      }).toList();

      // 构建每日事件数据
      final Map<String, List<Map<String, dynamic>>> dayEventsMap = {};

      for (var event in monthEvents) {
        final day = event.startTime.day.toString();
        if (!dayEventsMap.containsKey(day)) {
          dayEventsMap[day] = [];
        }
        dayEventsMap[day]!.add({
          'id': event.id,
          'title': event.title,
          'description': event.description,
          'startTime': event.startTime.toIso8601String(),
          'endTime': event.endTime?.toIso8601String(),
          'completed': false,
        });
      }

      // 按开始时间排序每日事件
      for (var day in dayEventsMap.keys) {
        dayEventsMap[day]!.sort((a, b) {
          final aTime = DateTime.parse(a['startTime'] as String);
          final bTime = DateTime.parse(b['startTime'] as String);
          return aTime.compareTo(bTime);
        });
      }

      // 构建完整的小组件数据
      final widgetData = {
        'year': now.year,
        'month': now.month,
        'daysInMonth': lastDayOfMonth.day,
        'firstWeekday': firstWeekday,
        'today': now.day,
        'dayEvents': dayEventsMap,
      };

      // 保存到 HomeWidget
      final jsonString = jsonEncode(widgetData);
      await HomeWidget.saveWidgetData<String>(
        'calendar_month_widget_data',
        jsonString,
      );

      // 更新小组件
      await HomeWidget.updateWidget(
        name: 'CalendarMonthWidgetProvider',
        qualifiedAndroidName:
            'github.hunmer.aboutme.widgets.providers.CalendarMonthWidgetProvider',
      );

      debugPrint('日历小组件数据同步成功: ${monthEvents.length} 个事件');
    } catch (e) {
      debugPrint('日历小组件数据同步失败: $e');
    }
  }

  @override
  String? getPluginName(context) {
    return 'calendar_name'.tr;
  }

  void showEventDetails(BuildContext context, CalendarEvent event) {
    // 更新路由上下文
    final dateStr =
        '${event.startTime.year}-${event.startTime.month.toString().padLeft(2, '0')}-${event.startTime.day.toString().padLeft(2, '0')}';
    RouteHistoryManager.updateCurrentContext(
      pageId: '/calendar_event_detail',
      title: '事件详情 - ${event.title}',
      params: {
        'eventId': event.id,
        'eventTitle': event.title,
        'startDate': dateStr,
        'source': event.source,
      },
    );

    // 手绘弹窗挂在根导航，调用点可能不在 AppTheme 树内，显式传主题
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => EventDetailCard(
        event: event,
        onEdit: () {
          Navigator.pop(context);
          showEventEditPage(context, event);
        },
        onComplete: () {
          Navigator.pop(context);
          controller.completeEvent(event);
        },
        onDelete: () {
          Navigator.pop(context);
          controller.deleteEvent(event);
        },
      ),
    );
  }

  void showEventEditPage(BuildContext context, [CalendarEvent? event]) {
    // 新建/编辑：smooth_sheets 底部弹层
    VoidCallback? submitEvent;
    SmoothBottomSheet.showForm(
      context: context,
      title: event == null ? 'calendar_addEvent'.tr : 'calendar_editEvent'.tr,
      child: EventEditPage(
        event: event,
        initialDate: event?.startTime ?? controller.selectedDate,
        embedInSheet: true,
        onReady: (submit) => submitEvent = submit,
        onSave: (updatedEvent) {
          if (event != null) {
            controller.updateEvent(updatedEvent);
          } else {
            controller.addEvent(updatedEvent);
          }
          // 强制重建界面
          controller.refresh();
        },
      ),
      onSave: () => submitEvent?.call(),
    );
  }

  // 将 CalendarEvent 转换为 Appointment
  List<syncfusion.Appointment> getUserAppointments() {
    // 使用总控制器获取所有事件（包括普通事件和Todo任务事件）
    final List<CalendarEvent> allEvents = controller.getAllEvents();

    return allEvents
        .map(
          (event) => syncfusion.Appointment(
            startTime: event.startTime,
            endTime:
                event.endTime ?? event.startTime.add(const Duration(hours: 1)),
            subject: event.title,
            notes: event.description,
            color: event.color,
            isAllDay: false, // 设置为false，确保显示为横条而不是圆点
            id: event.id,
          ),
        )
        .toList();
  }

  // 处理日历点击事件
  void handleCalendarTap(
    BuildContext context,
    syncfusion.CalendarTapDetails details,
  ) {
    if (details.targetElement == syncfusion.CalendarElement.calendarCell) {
      controller.selectDate(details.date!);
    } else if (details.targetElement ==
        syncfusion.CalendarElement.appointment) {
      final String eventId = details.appointments?.first.id as String;

      // 查找事件（包括系统日历事件）
      final allEvents = controller.getAllEvents();
      try {
        final event = allEvents.firstWhere(
          (event) => event.id == eventId,
          orElse: () => throw Exception('Event not found'),
        );
        showEventDetails(context, event);
      } catch (e) {
        debugPrint('CalendarPlugin: 事件未找到: $eventId');
      }
    }
  }

  @override
  Widget buildMainView(BuildContext context) {
    return CalendarMainView();
  }

  // ========== 小组件统计方法 ==========

  /// 获取今日事件数量
  int getTodayEventCount() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return controller.getAllEvents().where((event) {
      return event.startTime.isAfter(
            today.subtract(const Duration(seconds: 1)),
          ) &&
          event.startTime.isBefore(tomorrow);
    }).length;
  }

  /// 获取本周事件数量
  int getWeekEventCount() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    return controller.getAllEvents().where((event) {
      return event.startTime.isAfter(
            weekStart.subtract(const Duration(seconds: 1)),
          ) &&
          event.startTime.isBefore(weekEnd);
    }).length;
  }

  /// 获取未完成事件数量（开始时间在未来的事件）
  int getPendingEventCount() {
    final now = DateTime.now();
    return controller.getAllEvents().where((event) {
      return event.startTime.isAfter(now);
    }).length;
  }

  // 获取所有活动数量
  int _getEventCount() {
    return controller.getAllEvents().length;
  }

  // 获取7天内的活动数量
  int _getUpcomingEventCount() {
    final now = DateTime.now();
    final sevenDaysLater = now.add(const Duration(days: 7));
    return controller.getAllEvents().where((event) {
      return event.startTime.isAfter(now) &&
          event.startTime.isBefore(sevenDaysLater);
    }).length;
  }

  // 获取过期活动数量
  int _getExpiredEventCount() {
    final now = DateTime.now();
    return controller.getAllEvents().where((event) {
      return event.startTime.isBefore(now);
    }).length;
  }

  @override
  Widget? buildCardView(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
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
                    'calendar_name'.tr,
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
                  // 第一行 - 活动数量和7天活动
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // 活动数量
                      Column(
                        children: [
                          Text(
                            'calendar_eventCount'.tr,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            _getEventCount().toString(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      // 7天活动
                      Column(
                        children: [
                          Text(
                            'calendar_weekEvents'.tr,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            _getUpcomingEventCount().toString(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 第二行 - 过期活动
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Text(
                            'calendar_expiredEvents'.tr,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            _getExpiredEventCount().toString(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
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

  @override
  Future<void> uninstall() async {
    await controller.resetData();
  }
}

/// 日历插件主视图
class CalendarMainView extends StatefulWidget {
  const CalendarMainView({super.key, this.initialDate});

  /// 初始选中日期（如从主页日期视图跳转带入）
  final DateTime? initialDate;

  @override
  State<CalendarMainView> createState() => _CalendarMainViewState();
}

class _CalendarMainViewState extends State<CalendarMainView>
    with SingleTickerProviderStateMixin {
  late CalendarPlugin plugin;
  late TabController _tabController;
  late int _currentPage;
  final GlobalKey _bottomBarKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    plugin = PluginManager.instance.getPlugin('calendar') as CalendarPlugin;

    // 定位到路由带入的日期（选中日 + 聚焦月份）
    final initialDate = widget.initialDate;
    if (initialDate != null) {
      plugin.controller.selectDate(initialDate);
      plugin.controller.setFocusedMonth(
        DateTime(initialDate.year, initialDate.month),
      );
    }

    _currentPage = 0;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.animation?.addListener(() {
      final value = _tabController.animation!.value.round();
      if (value != _currentPage && mounted) {
        setState(() {
          _currentPage = value;
        });
      }
    });

    // ✅ 每次进入日历界面时自动刷新系统事件
    _refreshSystemEvents();

    // 初始化时设置路由上下文
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateRouteContext();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 更新路由上下文,使"询问当前上下文"功能能获取到当前日历视图状态
  void _updateRouteContext() {
    final displayDate = plugin.sfController.displayDate ?? DateTime.now();
    final view = plugin.sfController.view ?? syncfusion.CalendarView.month;

    String viewMode;
    String timeRange;

    switch (view) {
      case syncfusion.CalendarView.day:
        viewMode = '日视图';
        timeRange =
            '${displayDate.year}-${displayDate.month.toString().padLeft(2, '0')}-${displayDate.day.toString().padLeft(2, '0')}';
        break;
      case syncfusion.CalendarView.week:
      case syncfusion.CalendarView.workWeek:
        viewMode = view == syncfusion.CalendarView.week ? '周视图' : '工作周视图';
        final weekStart = displayDate.subtract(
          Duration(days: displayDate.weekday - 1),
        );
        final weekEnd = weekStart.add(const Duration(days: 6));
        timeRange =
            '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')} 至 ${weekEnd.year}-${weekEnd.month.toString().padLeft(2, '0')}-${weekEnd.day.toString().padLeft(2, '0')}';
        break;
      case syncfusion.CalendarView.month:
        viewMode = '月视图';
        timeRange =
            '${displayDate.year}-${displayDate.month.toString().padLeft(2, '0')}';
        break;
      case syncfusion.CalendarView.schedule:
        viewMode = '日程视图';
        timeRange =
            '${displayDate.year}-${displayDate.month.toString().padLeft(2, '0')}';
        break;
      case syncfusion.CalendarView.timelineDay:
        viewMode = '时间轴日视图';
        timeRange =
            '${displayDate.year}-${displayDate.month.toString().padLeft(2, '0')}-${displayDate.day.toString().padLeft(2, '0')}';
        break;
      case syncfusion.CalendarView.timelineWeek:
      case syncfusion.CalendarView.timelineWorkWeek:
        viewMode = view == syncfusion.CalendarView.timelineWeek
            ? '时间轴周视图'
            : '时间轴工作周视图';
        final weekStart = displayDate.subtract(
          Duration(days: displayDate.weekday - 1),
        );
        final weekEnd = weekStart.add(const Duration(days: 6));
        timeRange =
            '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')} 至 ${weekEnd.year}-${weekEnd.month.toString().padLeft(2, '0')}-${weekEnd.day.toString().padLeft(2, '0')}';
        break;
      default:
        viewMode = '未知视图';
        timeRange =
            '${displayDate.year}-${displayDate.month.toString().padLeft(2, '0')}';
    }

    RouteHistoryManager.updateCurrentContext(
      pageId: '/calendar_main',
      title: '日历 - $viewMode',
      params: {'viewMode': viewMode, 'timeRange': timeRange},
    );
  }

  /// 刷新系统日历事件（进入页面时自动执行）
  Future<void> _refreshSystemEvents() async {
    try {
      await plugin.controller.loadSystemEvents();
    } catch (e) {
      debugPrint('CalendarMainView: 刷新系统事件失败: $e');
    }
  }

  /// 搜索事件：基于标题和描述进行模糊搜索
  List<CalendarEvent> _searchEvents(String query) {
    if (query.isEmpty) return [];

    final allEvents = plugin.controller.getAllEvents();
    final lowerQuery = query.toLowerCase();

    return allEvents.where((event) {
      return event.title.toLowerCase().contains(lowerQuery) ||
          event.description.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// 构建搜索结果列表（手绘风：墨线卡片 + 挂载描画入场）
  Widget _buildSearchResults(List<CalendarEvent> events) {
    final theme = DSThemeBridge.resolve(context);

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DsIcon(DsIconKind.search, size: 64, color: theme.textSub),
            const SizedBox(height: 16),
            Text(
              'calendar_noMatchingEvents'.tr,
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          // 挂载即描画入场
          child: WiredDraw(
            child: DSCard(
              onTap: () {
                // 清除搜索并显示事件详情
                setState(() {
                  _searchQuery = '';
                });
                plugin.showEventDetails(context, event);
              },
              child: Row(
                children: [
                  _buildEventIconBadge(event, theme),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: DsTypography.title.copyWith(color: theme.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(event.startTime),
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                        ),
                        if (event.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            event.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  DsIcon(
                    DsIconKind.chevronRight,
                    size: 20,
                    color: theme.textSub,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 活动图标徽章：墨线圆底 + 手绘图标本体（活动自带动态 IconData，走 WiredIcon）
  Widget _buildEventIconBadge(CalendarEvent event, AppThemeData theme) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      // 小控件分档：纯色实底 + 墨线抖动描边
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: event.color.withValues(alpha: 0.2),
        radius: BorderRadius.circular(999),
        strokeWidth: 1.2,
        seed: event.id.hashCode,
      ),
      child: WiredIcon(
        icon: event.icon,
        size: 22,
        color: event.color,
        drawConfig: theme.wired.drawConfig,
      ),
    );
  }

  /// 格式化日期时间显示
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));

    String dateStr;
    if (dateTime.isAtSameMomentAs(today)) {
      dateStr = '今天';
    } else if (dateTime.isAtSameMomentAs(tomorrow)) {
      dateStr = '明天';
    } else if (dateTime.isAtSameMomentAs(yesterday)) {
      dateStr = '昨天';
    } else {
      dateStr = '${dateTime.month}-${dateTime.day}';
    }

    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';

    return '$dateStr $timeStr';
  }

  /// 构建 FAB（新建活动，停靠底部栏子栏右圆钮位置）
  Widget _buildFab() {
    return DSThemeBridge(
      // DSFab 内部取 AppTheme，需包桥
      child: DSFab(
        key: _fabKey,
        onPressed: () => plugin.showEventEditPage(context),
      ),
    );
  }

  /// 日历 tab：大标题 + 搜索 + syncfusion 日历
  Widget _buildCalendarTab(BuildContext context) {
    return SuperCupertinoNavigationWrapper(
      title: Text('calendar_calendar'.tr),
      largeTitle: 'calendar_calendar'.tr,
      enableLargeTitle: true,
      enableSearchBar: true,
      searchPlaceholder: 'calendar_searchPlaceholder'.tr,
      searchBody: _buildSearchResults(_searchEvents(_searchQuery)),
      onSearchChanged: (query) {
        setState(() {
          _searchQuery = query;
        });
      },
      body: Column(
        children: [
          Expanded(
            child: AboutmeSfCalendar(
              view: plugin.sfController.view ?? syncfusion.CalendarView.month,
              controller: plugin.sfController,
              allowedViews: plugin.allowedViews,
              allowViewNavigation: true,
              dataSource: _AppointmentDataSource(plugin.getUserAppointments()),
              initialDisplayDate: plugin.controller.focusedMonth,
              onViewChanged: (details) =>
                  plugin.onViewChanged(details, _updateRouteContext),
              onTap: (details) => plugin.handleCalendarTap(context, details),
              monthViewSettings: const syncfusion.MonthViewSettings(
                showAgenda: true,
                agendaViewHeight: 200,
                appointmentDisplayMode:
                    syncfusion.MonthAppointmentDisplayMode.appointment,
              ),
              timeSlotViewSettings: const syncfusion.TimeSlotViewSettings(
                startHour: 6,
                endHour: 23,
                timeInterval: Duration(minutes: 30),
              ),
              todayHighlightColor: Theme.of(context).primaryColor,
              selectionDecoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      // SuperAppBar 的 actions 经 Overlay 渲染，DS 组件需自带 DSThemeBridge
      actions: [
        // 跳转到今天按钮
        DSThemeBridge(
          child: Builder(
            builder: (buildContext) {
              final theme = DSThemeBridge.resolve(buildContext);
              return DSIconButton(
                icon: DsIconKind.calendar,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: 'calendar_backToToday'.tr,
                onPressed: () {
                  plugin.sfController.displayDate = DateTime.now();
                  // 更新路由上下文
                  _updateRouteContext();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: plugin.controller,
      builder: (context, child) {
        return CustomBottomBar(
          currentIndex: _currentPage,
          tabController: _tabController,
          bottomBarKey: _bottomBarKey,
          body: (context, controller) => TabBarView(
            controller: _tabController,
            dragStartBehavior: DragStartBehavior.start,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Tab0: 日历视图
              KeepAliveWrapper(child: _buildCalendarTab(context)),
              // Tab1: 活动列表（过滤器可切换全部/未完成/已完成）
              KeepAliveWrapper(
                child: EventListPage(
                  events: plugin.controller.events,
                  completedEvents: plugin.controller.completedEvents,
                  onEventUpdated: (event) =>
                      plugin.showEventEditPage(context, event),
                  onEventCompleted: (event) =>
                      plugin.controller.completeEvent(event),
                  onEventDeleted: (event) =>
                      plugin.controller.deleteEvent(event),
                ),
              ),
            ],
          ),
          fab: _buildFab(),
          items: [
            DSNavItem(icon: DsIconKind.calendar, label: 'calendar_calendar'.tr),
            DSNavItem(icon: DsIconKind.list, label: 'calendar_activities'.tr),
          ],
        );
      },
    );
  }
}

class _AppointmentDataSource extends syncfusion.CalendarDataSource {
  _AppointmentDataSource(List<syncfusion.Appointment> appointments) {
    this.appointments = appointments;
  }
}
