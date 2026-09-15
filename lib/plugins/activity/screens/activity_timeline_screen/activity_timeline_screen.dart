import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/picker/calendar_strip_date_picker.dart';
import 'package:aboutme/plugins/activity/services/activity_service.dart';
import 'package:aboutme/plugins/activity/widgets/activity_timeline.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/plugins/activity/screens/activity_calendar_screen.dart';
import 'components/activity_grid_view.dart';
import 'controllers/activity_controller.dart';
import 'controllers/tag_controller.dart';
import 'controllers/view_mode_controller.dart';

class ActivityTimelineScreen extends StatefulWidget {
  const ActivityTimelineScreen({super.key});

  @override
  State<ActivityTimelineScreen> createState() => _ActivityTimelineScreenState();
}

class _ActivityTimelineScreenState extends State<ActivityTimelineScreen> {
  late DateTime _selectedDate;
  late ActivityService _activityService;
  late ActivityController _activityController;
  late TagController _tagController;
  late ViewModeController _viewModeController;
  bool _isInitialized = false;
  final Map<String, bool> _searchFilters = {
    'activity': true,
    'tag': true,
    'comment': true,
  };
  String _searchQuery = '';
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();

    // 监听通知点击事件
    eventManager.subscribe(
      'activity_notification_tapped',
      _onNotificationTapped,
    );

    // 监听活动添加事件
    eventManager.subscribe('activity_added', _onActivityChanged);

    // 监听活动删除事件
    eventManager.subscribe('activity_deleted', _onActivityChanged);

    // 监听活动更新事件(如果存在)
    eventManager.subscribe('activity_updated', _onActivityChanged);

    // 监听同步刷新事件（WebSocket 同步后触发）
    eventManager.subscribe('activity_refresh', _onSyncRefresh);

    _initializeService().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  Future<void> _initializeService() async {
    final storage = StorageManager();
    await storage.initialize();
    _activityService = ActivityService(storage, 'activity');

    _activityController = ActivityController(
      activityService: _activityService,
      onActivitiesChanged: () {
        if (mounted) setState(() {});
      },
    );

    _tagController = TagController(
      activityService: _activityService,
      onTagsChanged: () {
        if (mounted) setState(() {});
      },
    );

    _viewModeController = ViewModeController();
    _viewModeController.addListener(() {
      if (mounted) setState(() {});
    });

    await _tagController.initialize();
    await _activityController.loadActivities(_selectedDate);

    // 初始化时设置当前日期的路由上下文
    _updateRouteContext(_selectedDate);
  }

  void _onDateChanged(DateTime date) {
    if (date == _selectedDate) return;

    setState(() {
      _selectedDate = date;
    });
    _activityController.loadActivities(_selectedDate);

    // 更新路由上下文
    _updateRouteContext(date);
  }

  /// 更新路由上下文,使"询问当前上下文"功能能获取到当前日期
  void _updateRouteContext(DateTime date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    RouteHistoryManager.updateCurrentContext(
      pageId: "/activity_timeline",
      title: '活动时间轴 - $dateStr',
      params: {'date': dateStr},
    );
  }

  @override
  void dispose() {
    // 清理事件监听
    eventManager.unsubscribe(
      'activity_notification_tapped',
      _onNotificationTapped,
    );
    eventManager.unsubscribe('activity_added', _onActivityChanged);
    eventManager.unsubscribe('activity_deleted', _onActivityChanged);
    eventManager.unsubscribe('activity_updated', _onActivityChanged);
    eventManager.unsubscribe('activity_refresh', _onSyncRefresh);

    // 清理控制器
    _viewModeController.dispose();
    super.dispose();
  }

  /// 处理活动变更事件(添加、删除、更新)
  void _onActivityChanged(EventArgs args) {
    debugPrint('[ActivityTimelineScreen] 收到活动变更事件: ${args.eventName}');

    if (!_isInitialized || !mounted) return;

    // 重新加载当前日期的活动列表
    _activityController.loadActivities(_selectedDate);
  }

  /// 处理同步刷新事件（WebSocket 同步后触发）
  void _onSyncRefresh(EventArgs args) {
    debugPrint('[ActivityTimelineScreen] 收到同步刷新事件');

    if (!_isInitialized || !mounted) return;

    // 重新加载当前日期的活动列表
    _activityController.loadActivities(_selectedDate).then((_) {
      if (mounted) setState(() {});
    });
  }

  /// 处理通知点击事件
  void _onNotificationTapped(EventArgs args) {
    debugPrint('[ActivityTimelineScreen] 收到通知点击事件: ${args.eventName}');

    if (!_isInitialized) {
      // 如果还没初始化完成，延迟处理
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showActivityFormFromNotification();
        }
      });
    } else {
      _showActivityFormFromNotification();
    }
  }

  /// 从通知点击显示活动表单
  void _showActivityFormFromNotification() {
    // 显示一个提示信息
    Toast.show('正在打开活动记录表单...');

    // 延迟一点时间确保SnackBar显示后再打开表单
    Future.delayed(const Duration(milliseconds: 500), () {
      _showQuickActivityForm();
    });
  }

  /// 显示快速活动表单
  void _showQuickActivityForm() async {
    if (!mounted) return;

    try {
      ActivityController.showAddActivityScreen(context);
    } catch (e) {
      debugPrint('[ActivityTimelineScreen] 打开活动表单失败: $e');

      if (mounted) {
        Toast.error('打开表单失败: $e');
      }
    }
  }

  /// 处理搜索过滤器变更
  void _onSearchFilterChanged(Map<String, bool> filters) {
    setState(() {
      _searchFilters.addAll(filters);
    });

    debugPrint('[ActivityTimelineScreen] 搜索过滤器变更: $_searchFilters');

    // 如果有搜索词，重新执行搜索
    if (_searchQuery.isNotEmpty) {
      _performSearch();
    }
  }

  /// 执行搜索
  void _performSearch() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    debugPrint('[ActivityTimelineScreen] 执行搜索: "$_searchQuery"');

    final results = <dynamic>[];

    // 搜索活动标题
    if (_searchFilters['activity'] == true) {
      for (final activity in _activityController.activities) {
        if (activity.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
          results.add({
            'type': 'activity',
            'data': activity,
            'title': activity.title,
            'subtitle': '活动',
          });
        }
      }
    }

    // 搜索标签
    if (_searchFilters['tag'] == true) {
      for (final activity in _activityController.activities) {
        for (final tag in activity.tags) {
          if (tag.toLowerCase().contains(_searchQuery.toLowerCase())) {
            final existing = results.firstWhere(
              (item) => item['data'] == activity,
              orElse: () => null,
            );
            if (existing == null) {
              results.add({
                'type': 'activity_tag',
                'data': activity,
                'title': activity.title,
                'subtitle': '标签匹配',
                'tag': tag,
              });
            }
            break;
          }
        }
      }
    }

    // 搜索注释/描述
    if (_searchFilters['comment'] == true) {
      for (final activity in _activityController.activities) {
        if (activity.description?.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ==
            true) {
          results.add({
            'type': 'activity_comment',
            'data': activity,
            'title': activity.title,
            'subtitle': '注释匹配',
            'description': activity.description,
          });
        }
      }
    }

    setState(() {
      _searchResults = results;
    });

    debugPrint('[ActivityTimelineScreen] 搜索完成，找到 ${results.length} 个结果');
  }

  /// 处理搜索内容变更
  void _onSearchChanged(String value) {
    _searchQuery = value;
    _performSearch();
  }

  /// 构建搜索结果列表
  Widget _buildSearchResults() {
    final theme = DSThemeBridge.resolve(context);

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DsIcon(DsIconKind.search, size: 64, color: theme.disabled),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? '输入关键词搜索' : '未找到匹配结果',
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
            const SizedBox(height: 8),
            Text(
              '尝试调整搜索条件或过滤器',
              style: DsTypography.caption.copyWith(color: theme.disabled),
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
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final activity = result['data'];
        final type = result['type'];
        final title = result['title'];
        final subtitle = result['subtitle'];

        // DSCard 内部取 AppTheme，需包桥
        return DSThemeBridge(
          child: Builder(
            builder: (ctx) {
              final dsTheme = DSThemeBridge.resolve(ctx);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                // 保留点击进入编辑的入口
                child: DSCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () {
                    _activityController.editActivity(context, activity);
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getActivityColor(activity),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: DsIcon(
                            _getResultIcon(type),
                            size: 20,
                            color: dsTheme.surface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: DsTypography.body.copyWith(
                                fontWeight: FontWeight.w500,
                                color: dsTheme.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: DsTypography.caption.copyWith(
                                color: dsTheme.textSub,
                              ),
                            ),
                            if (result['tag'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: dsTheme.surfaceAlt,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    result['tag'],
                                    style: DsTypography.caption.copyWith(
                                      fontSize: 12,
                                      color: dsTheme.textSub,
                                    ),
                                  ),
                                ),
                              ),
                            if (result['description'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  result['description'],
                                  style: DsTypography.caption.copyWith(
                                    fontSize: 12,
                                    color: dsTheme.textSub,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${activity.startTime.hour.toString().padLeft(2, '0')}:${activity.startTime.minute.toString().padLeft(2, '0')}',
                        style: DsTypography.caption.copyWith(
                          color: dsTheme.textSub,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 获取活动颜色
  Color _getActivityColor(dynamic activity) {
    if (activity.color != null) {
      return activity.color;
    }
    return Colors.blue;
  }

  /// 获取搜索结果图标
  DsIconKind _getResultIcon(String type) {
    switch (type) {
      case 'activity':
        return DsIconKind.calendar;
      case 'activity_tag':
        return DsIconKind.tag;
      case 'activity_comment':
        return DsIconKind.chat;
      default:
        return DsIconKind.calendar;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        // DSLoadingDots 内部取 AppTheme，需包桥
        body: Center(
          child: DSThemeBridge(
            child: Builder(builder: (_) => const DSLoadingDots()),
          ),
        ),
      );
    }

    return SuperCupertinoNavigationWrapper(
      title: Text('activity_myActivities'.tr),
      largeTitle: 'activity_myActivities'.tr,
      enableSearchBar: true,
      searchPlaceholder: 'activity_searchPlaceholder'.tr,
      onSearchChanged: _onSearchChanged,
      enableSearchFilter: true,
      onSearchFilterChanged: _onSearchFilterChanged,
      body: Stack(
        children: [
          Column(
            children: [
              // Calendar Strip Date Picker
              CalendarStripDatePicker(
                selectedDate: _selectedDate,
                onDateChanged: _onDateChanged,
                height: 70,
                itemWidth: 54,
                itemSpacing: 12,
                listPadding: const EdgeInsets.only(left: 16, right: 8),
                calendarButtonPadding: const EdgeInsets.only(right: 16),
                showCalendarButton: true,
              ),
              // 根据视图模式显示不同的视图
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (
                    Widget child,
                    Animation<double> animation,
                  ) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child:
                      _viewModeController.isGridMode
                          ? ActivityGridView(
                            key: ValueKey(
                              'grid_${_selectedDate.millisecondsSinceEpoch}',
                            ),
                            activities: _activityController.activities,
                            selectedDate: _selectedDate,
                            onActivityTap:
                                (activity) => _activityController.editActivity(
                                  context,
                                  activity,
                                ),
                            onUnrecordedTimeTap: (start, end) {
                              ActivityController.showAddActivityScreen(
                                context,
                                start: start,
                                end: end,
                              );
                            },
                            onSelectionChanged: (start, end) {
                              if (start != null && end != null) {
                                final minutes = end.difference(start).inMinutes;
                                final hours = minutes ~/ 60;
                                final mins = minutes % 60;
                                final durationText =
                                    hours > 0 ? '$hours小时$mins分钟' : '$mins分钟';
                                Toast.show(
                                  '${DateFormat('H:mm').format(start)} - ${DateFormat('H:mm').format(end)} ($durationText)',
                                  gravity: ToastGravity.BOTTOM,
                                );
                              }
                            },
                          )
                          : ActivityTimeline(
                            key: ValueKey(
                              'timeline_${_selectedDate.millisecondsSinceEpoch}',
                            ),
                            activities: _activityController.activities,
                            onDeleteActivity:
                                _activityController.deleteActivity,
                            onActivityTap:
                                (activity) => _activityController.editActivity(
                                  context,
                                  activity,
                                ),
                            onUnrecordedTimeTap: (start, end) {
                              ActivityController.showAddActivityScreen(context);
                            },
                            getTagIcons: _tagController.getTagIcons,
                            getTagColors: _tagController.getTagColors,
                          ),
                ),
              ),
            ],
          ),
          // FloatingActionButton - 移到右上角作为 actions
        ],
      ),
      // 搜索结果页面
      searchBody: _buildSearchResults(),
      enableLargeTitle: true,
      // SuperAppBar 的 actions 经 Overlay 渲染，DS 组件需自带 DSThemeBridge
      actions: [
        // 日历视图按钮
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.calendar,
                  size: 36,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  tooltip: '日历视图',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ActivityCalendarScreen(
                              activityService: _activityService,
                            ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        // 视图切换按钮
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon:
                      _viewModeController.isGridMode
                          ? DsIconKind.list
                          : DsIconKind.grid,
                  size: 36,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  tooltip:
                      _viewModeController.isGridMode ? '切换到时间轴视图' : '切换到网格视图',
                  onPressed: _viewModeController.toggleViewMode,
                );
              },
            ),
          ),
        ),
        // 标签管理按钮
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.tag,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: '标签管理',
                onPressed: () => _tagController.showTagManagerDialog(context),
              );
            },
          ),
        ),
        // 添加活动的按钮
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: DSThemeBridge(
            child: Builder(
              builder: (context) {
                return DSIconButton(
                  icon: DsIconKind.plus,
                  size: 40,
                  tooltip: '添加活动',
                  onPressed:
                      () => ActivityController.showAddActivityScreen(context),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
