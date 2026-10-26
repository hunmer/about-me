import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/utils/platform_utils.dart';
import 'package:aboutme/plugins/calendar/calendar_plugin.dart';
import 'package:aboutme/plugins/calendar/models/event.dart';
import 'package:aboutme/plugins/calendar/services/system_calendar_settings.dart';
import 'package:aboutme/plugins/calendar/widgets/event_detail_card.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_builders.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';

/// 活动列表（日历插件"活动"tab 内容）
///
/// 手绘纸墨风：墨线卡片 + 挂载描画入场；已完成活动不再单独成页，
/// 通过多条件过滤栏的状态过滤（全部/未完成/已完成）在列表内切换。
/// 右滑完成（仅未完成）、左滑删除。
class EventListPage extends StatefulWidget {
  final List<CalendarEvent> events;
  final List<CalendarEvent> completedEvents;
  final Function(CalendarEvent) onEventUpdated;
  final Function(CalendarEvent) onEventCompleted;
  final Function(CalendarEvent) onEventDeleted;

  const EventListPage({
    super.key,
    required this.events,
    required this.completedEvents,
    required this.onEventUpdated,
    required this.onEventCompleted,
    required this.onEventDeleted,
  });

  @override
  State<EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  late List<CalendarEvent> _events;

  /// 状态过滤：null = 全部，'active' = 未完成，'completed' = 已完成
  String? _statusFilter;

  /// 是否隐藏节假日（null = 设置尚未加载完成）
  bool? _hideHolidays;

  /// 是否开启了系统日历导入（null = 设置尚未加载完成）
  bool? _systemCalendarEnabled;

  /// 节假日过滤初始值（按已保存设置一次性注入，此后不随用户切换变化，
  /// 避免触发 wrapper 的 initialMultiFilters 重置逻辑清掉其他过滤项）
  Map<String, dynamic>? _initialFilters;

  /// 状态过滤选项（id -> 文案）
  Map<String, String> get _statusOptions => {
    'active': 'calendar_filterActive'.tr,
    'completed': 'calendar_filterCompleted'.tr,
  };

  @override
  void initState() {
    super.initState();
    // 合并未完成与已完成活动，按开始时间排序
    _syncEvents();

    _loadSystemCalendarSettings();

    // 初始化时设置路由上下文
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateRouteContext();
    });
  }

  /// 读取系统日历导入设置，决定是否显示节假日过滤项及其初始值
  Future<void> _loadSystemCalendarSettings() async {
    final settings = await SystemCalendarSettings.load();
    if (!mounted) return;
    setState(() {
      _systemCalendarEnabled = settings.enabled;
      _hideHolidays = !settings.includeHolidays;
      if (settings.enabled &&
          PlatformUtils.isMobile &&
          !settings.includeHolidays) {
        _initialFilters = const {'holidays': 'hide'};
      }
    });
  }

  /// 节假日显隐切换：写入设置并重载系统日历事件（日历视图立即生效）
  Future<void> _applyHolidaysVisibility(bool includeHolidays) async {
    final settings = await SystemCalendarSettings.load();
    if (settings.includeHolidays == includeHolidays) return;
    settings.includeHolidays = includeHolidays;
    await settings.save();
    await CalendarPlugin.instance.controller.loadSystemEvents();
  }

  @override
  void didUpdateWidget(EventListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 控制器数据变化时（父级 ListenableBuilder 重建）同步列表
    if (oldWidget.events != widget.events ||
        oldWidget.completedEvents != widget.completedEvents) {
      _syncEvents();
    }
  }

  void _syncEvents() {
    _events = [...widget.events, ...widget.completedEvents]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// 状态过滤后的活动列表
  List<CalendarEvent> get _filteredEvents {
    if (_statusFilter == null) return _events;
    return _events.where((event) {
      return _statusFilter == 'completed'
          ? event.completedTime != null
          : event.completedTime == null;
    }).toList();
  }

  /// 更新路由上下文,使"询问当前上下文"功能能获取到当前页面状态
  void _updateRouteContext() {
    RouteHistoryManager.updateCurrentContext(
      pageId: '/calendar_event_list',
      title: '所有日历事件',
      params: {
        'totalCount': _events.length.toString(),
        'listType': '所有事件',
        if (_statusFilter != null) 'statusFilter': _statusFilter!,
      },
    );
  }

  String _getReminderText(int minutes) {
    if (minutes >= 1440) {
      return 'calendar_reminderAheadDays'.trParams({'days': '${minutes ~/ 1440}'});
    } else if (minutes >= 60) {
      return 'calendar_reminderAheadHours'.trParams({'hours': '${minutes ~/ 60}'});
    } else {
      return 'calendar_reminderAheadMinutes'.trParams({
        'minutes': '$minutes',
      });
    }
  }

  String _formatEventTime(CalendarEvent event) {
    final startFormat = DateFormat('MM-dd HH:mm');
    final endFormat = DateFormat('MM-dd HH:mm');

    String timeText = startFormat.format(event.startTime);
    if (event.endTime != null) {
      // 如果是同一天，只显示一次日期
      if (event.startTime.year == event.endTime!.year &&
          event.startTime.month == event.endTime!.month &&
          event.startTime.day == event.endTime!.day) {
        timeText += ' - ${DateFormat('HH:mm').format(event.endTime!)}';
      } else {
        timeText += ' - ${endFormat.format(event.endTime!)}';
      }
    }
    return timeText;
  }

  void _showEventDetails(CalendarEvent event) {
    // 手绘弹窗挂在根导航，调用点可能不在 AppTheme 树内，显式传主题
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => EventDetailCard(
            event: event,
            onEdit: () {
              Navigator.pop(context);
              // 编辑事件的逻辑在父组件中处理
              widget.onEventUpdated(event);
            },
            onComplete: () {
              Navigator.pop(context);
              widget.onEventCompleted(event);
            },
            onDelete: () {
              Navigator.pop(context);
              widget.onEventDeleted(event);
            },
          ),
    );
  }

  /// 构建过滤项（状态单选 + 移动端节假日显隐）
  List<FilterItem> _buildFilterItems() {
    return [
      FilterItem(
        id: 'status',
        title: 'calendar_filterStatus'.tr,
        type: FilterType.tagsSingle,
        builder: (context, value, onChanged) {
          // 过滤栏经根 Overlay 展示，DS 组件需包 DSThemeBridge
          return DSThemeBridge(
            child: FilterBuilders.buildSingleChoiceFilter(
              context: context,
              currentValue: value,
              onChanged: onChanged,
              options: _statusOptions,
              allItemsKey: 'all',
              allItemsLabel: 'calendar_filterAll'.tr,
            ),
          );
        },
        getBadge: (value) => FilterBuilders.singleChoiceBadge(
          value,
          _statusOptions,
        ),
      ),
      // 节假日显隐：仅在移动端且开启系统日历导入时显示
      if (_systemCalendarEnabled == true && PlatformUtils.isMobile)
        FilterItem(
          id: 'holidays',
          title: 'calendar_filterHolidays'.tr,
          type: FilterType.tagsSingle,
          builder: (context, value, onChanged) {
            return DSThemeBridge(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DSChip(
                    label: 'calendar_holidaysShow'.tr,
                    selected: value != 'hide',
                    onSelected: (_) => onChanged(null, done: true),
                  ),
                  DSChip(
                    label: 'calendar_holidaysHide'.tr,
                    selected: value == 'hide',
                    onSelected: (_) => onChanged('hide', done: true),
                  ),
                ],
              ),
            );
          },
          getBadge: (value) =>
              value == 'hide' ? 'calendar_holidaysHide'.tr : null,
        ),
    ];
  }

  /// MultiFilterBar 过滤变更：提取状态过滤选中项与节假日显隐
  void _onMultiFilterChanged(Map<String, dynamic> filters) {
    final hideHolidays = filters['holidays'] == 'hide';
    // 设置加载完成后才响应用户切换（加载前的初始化回写不落盘）
    final holidaysChanged =
        _hideHolidays != null && _hideHolidays != hideHolidays;
    setState(() {
      final status = filters['status'];
      _statusFilter =
          status is String && status != 'all' ? status : null;
      _hideHolidays = hideHolidays;
    });
    if (holidaysChanged) {
      _applyHolidaysVisibility(!hideHolidays);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final filtered = _filteredEvents;

    return SuperCupertinoNavigationWrapper(
      title: Text('calendar_allEvents'.tr),
      largeTitle: 'calendar_allEvents'.tr,
      enableLargeTitle: true,
      enableMultiFilter: true,
      multiFilterItems: _buildFilterItems(),
      initialMultiFilters: _initialFilters,
      onMultiFilterChanged: _onMultiFilterChanged,
      body:
          filtered.isEmpty
              ? Center(
                child: DSEmptyState(
                  emoji: '🗓️',
                  title: 'calendar_noEvents'.tr,
                ),
              )
              : ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final event = filtered[index];
                  return _buildEventItem(event, theme);
                },
              ),
    );
  }

  /// 单个活动卡片：右滑完成（仅未完成）、左滑删除
  Widget _buildEventItem(CalendarEvent event, AppThemeData theme) {
    final isCompleted = event.completedTime != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // 挂载即描画入场
      child: WiredDraw(
        child: Dismissible(
          key: Key(event.id),
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.85),
              borderRadius: theme.radii.xl,
            ),
            child: DsIcon(DsIconKind.check, color: theme.onPrimary),
          ),
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: theme.danger.withValues(alpha: 0.85),
              borderRadius: theme.radii.xl,
            ),
            child: DsIcon(DsIconKind.trash, color: theme.onPrimary),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // 已完成的活动不可再完成
              if (isCompleted) return false;
              // 右滑完成
              widget.onEventCompleted(event);
              return true;
            } else if (direction == DismissDirection.endToStart) {
              // 左滑删除
              widget.onEventDeleted(event);
              return true;
            }
            return false;
          },
          onDismissed: (direction) {
            setState(() {
              _events.remove(event);
            });
          },
          child: DSCard(
            onTap: () => _showEventDetails(event),
            child: Opacity(
              // 已完成活动整体降不透明度区分
              opacity: isCompleted ? 0.6 : 1.0,
              child: Row(
                children: [
                  _buildIconBadge(event, theme),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: DsTypography.title.copyWith(
                            color: theme.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            DsIcon(
                              DsIconKind.clock,
                              size: 14,
                              color: theme.textSub,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _formatEventTime(event),
                                style: DsTypography.caption.copyWith(
                                  color: theme.textSub,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (event.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            event.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                              height: 1.5,
                            ),
                          ),
                        ],
                        if (event.reminderMinutes != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              DsIcon(
                                DsIconKind.bell,
                                size: 14,
                                color: theme.textSub,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getReminderText(event.reminderMinutes!),
                                style: DsTypography.caption.copyWith(
                                  color: theme.textSub,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  DsIcon(
                    isCompleted ? DsIconKind.check : DsIconKind.chevronRight,
                    size: 20,
                    color: isCompleted ? theme.primary : theme.textSub,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 活动图标徽章：墨线圆底 + 手绘图标本体（活动自带动态 IconData，走 WiredIcon）
  Widget _buildIconBadge(CalendarEvent event, AppThemeData theme) {
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
}
