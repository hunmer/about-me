import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/habits/habits_plugin.dart';
import 'package:aboutme/plugins/bill/widgets/month_selector.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/widgets/swipe_action/index.dart';
import 'package:aboutme/plugins/habits/models/completion_record.dart';

/// 习惯月份列表视图
///
/// 显示某个习惯在选中月份的完成记录，类似于账单的月视图
class HabitMonthlyListScreen extends StatefulWidget {
  final String habitId;
  final String habitTitle;

  const HabitMonthlyListScreen({
    super.key,
    required this.habitId,
    required this.habitTitle,
  });

  @override
  State<HabitMonthlyListScreen> createState() => _HabitMonthlyListScreenState();
}

class _HabitMonthlyListScreenState extends State<HabitMonthlyListScreen> {
  late CalendarController _calendarController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Data State
  List<_CompletionRecordModel> _allMonthRecords = [];
  Map<DateTime, _DailyStats> _dailyStats = {};
  List<_CompletionRecordModel> _allRecords = []; // 存储所有历史记录

  late HabitsPlugin _habitsPlugin;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    _calendarController = CalendarController();
    _calendarController.displayDate = DateTime.now();
    _calendarController.selectedDate = DateTime.now();

    _habitsPlugin = PluginManager.instance.getPlugin('habits') as HabitsPlugin;

    // 设置路由上下文
    _updateRouteContext(_focusedDay);

    _loadMonthRecords();
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  Future<void> _loadMonthRecords() async {
    final recordController = _habitsPlugin.getRecordController();
    final records = await recordController.getHabitCompletionRecords(
      widget.habitId,
    );

    debugPrint('HabitMonthlyListScreen: 获取到的总记录数: ${records.length}');

    // 存储所有历史记录（用于 MonthSelector 统计）
    final allModelRecords = <_CompletionRecordModel>[];
    for (final record in records) {
      allModelRecords.add(
        _CompletionRecordModel(
          id: record.id,
          date: record.date,
          duration: record.duration,
          notes: record.notes,
        ),
      );
    }

    // Filter by month (当前选中月份)
    final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final monthEnd = DateTime(
      _focusedDay.year,
      _focusedDay.month + 1,
      0,
      23,
      59,
      59,
    );

    final filteredRecords =
        records
            .where(
              (record) =>
                  record.date.isAfter(
                    monthStart.subtract(const Duration(seconds: 1)),
                  ) &&
                  record.date.isBefore(
                    monthEnd.add(const Duration(seconds: 1)),
                  ),
            )
            .toList();

    debugPrint('过滤后的记录数: ${filteredRecords.length}');

    // Calculate daily stats for current month
    final stats = <DateTime, _DailyStats>{};
    for (var record in filteredRecords) {
      final date = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      if (!stats.containsKey(date)) {
        stats[date] = _DailyStats();
      }
      stats[date]!.count++;
      stats[date]!.totalMinutes += (record.duration.inMinutes as int);
    }

    // Convert to model records for current month
    final modelRecords = <_CompletionRecordModel>[];
    for (final record in filteredRecords) {
      modelRecords.add(
        _CompletionRecordModel(
          id: record.id,
          date: record.date,
          duration: record.duration,
          notes: record.notes,
        ),
      );
    }
    modelRecords.sort((a, b) => b.date.compareTo(a.date));

    if (mounted) {
      setState(() {
        _allRecords = allModelRecords; // 存储所有记录
        _allMonthRecords = modelRecords; // 当前月份记录
        _dailyStats = stats;
      });
    }
  }

  Map<String, double> _getMonthStats(DateTime month) {
    // 从所有记录中统计指定月份的数据
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final filteredRecords = _allRecords.where((record) {
      return record.date.isAfter(
            monthStart.subtract(const Duration(seconds: 1)),
          ) &&
          record.date.isBefore(monthEnd.add(const Duration(seconds: 1)));
    });

    double count = 0.0;
    double totalMinutes = 0.0;

    for (final record in filteredRecords) {
      count++;
      totalMinutes += record.duration.inMinutes;
    }

    return {'count': count, 'totalMinutes': totalMinutes};
  }

  void _updateRouteContext(DateTime date, {DateTime? selectedDay}) {
    String dateStr;
    String title;

    if (selectedDay != null) {
      dateStr =
          '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}';
      title = '${widget.habitTitle} - $dateStr';
    } else {
      dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      title = '${widget.habitTitle} - $dateStr';
    }

    RouteHistoryManager.updateCurrentContext(
      pageId: '/habit_monthly_list',
      title: title,
      params: {'date': dateStr},
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 日历单元格：SfCalendar 的 monthCellBuilder 回调位于主题桥之外，
  /// 必须外包 DSThemeBridge 再取令牌（陷阱 2）
  Widget _buildCalendarCell(DateTime day, bool isSelected) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final date = DateTime(day.year, day.month, day.day);
          final stats = _dailyStats[date];
          final isToday = _isSameDay(DateTime.now(), day);
          final hasRecord = (stats?.count ?? 0) > 0;

          return ConstrainedBox(
            constraints: BoxConstraints.tight(const Size(48, 48)),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isSelected ? theme.primary.withValues(alpha: 0.2) : null,
                border:
                    isToday ? Border.all(color: theme.primary, width: 2) : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Text(
                    '${day.day}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? theme.primary : theme.text,
                    ),
                  ),
                  if (hasRecord)
                    Positioned(
                      top: -6,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: theme.primary.withValues(alpha: 0.5),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          '${stats!.count}',
                          style: TextStyle(
                            fontSize: 7,
                            color: theme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<_CompletionRecordModel> get _selectedDayRecords {
    if (_selectedDay == null) return [];

    final selectedDate = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );

    return _allMonthRecords.where((record) {
      final recordDate = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      return _isSameDay(recordDate, selectedDate);
    }).toList();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatCompactDuration(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return '${h}h${m > 0 ? '${m}m' : ''}';
    }
    return '${minutes}m';
  }

  /// 显示记录详情对话框
  void _showRecordDetail(_CompletionRecordModel record) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder: (ctx) {
                final theme = DSThemeBridge.resolve(ctx);
                return JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            DsIcon(DsIconKind.check, color: theme.primary),
                            const SizedBox(width: 8),
                            Text(
                              '打卡记录详情',
                              style: DsTypography.title.copyWith(
                                color: theme.text,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: theme.spacing.md),
                        _buildDetailRow(
                          ctx,
                          '日期',
                          DateFormat('yyyy年MM月dd日 HH:mm').format(record.date),
                        ),
                        _buildDetailRow(
                          ctx,
                          '时长',
                          _formatDuration(record.duration),
                        ),
                        if (record.notes != null &&
                            record.notes!.isNotEmpty) ...[
                          SizedBox(height: theme.spacing.sm),
                          Text(
                            '备注',
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              record.notes!,
                              style: DsTypography.body.copyWith(
                                color: theme.text,
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: theme.spacing.xl),
                        Row(
                          children: [
                            Expanded(
                              child: DSButton(
                                label: '关闭',
                                variant: DSButtonVariant.outline,
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DSButton(
                                label: '编辑',
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showEditDialog(record);
                                },
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
    );
  }

  /// 显示编辑对话框
  void _showEditDialog(_CompletionRecordModel record) {
    final notesController = TextEditingController(text: record.notes ?? '');
    final durationController = TextEditingController(
      text: record.duration.inMinutes.toString(),
    );

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      barrierDismissible: false,
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder: (ctx) {
                final theme = DSThemeBridge.resolve(ctx);
                return JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '编辑打卡记录',
                          style: DsTypography.title.copyWith(color: theme.text),
                        ),
                        SizedBox(height: theme.spacing.lg),
                        DSInput(
                          controller: durationController,
                          label: '时长（分钟）',
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: theme.spacing.md),
                        DSInput(
                          controller: notesController,
                          label: '备注',
                          maxLines: 3,
                        ),
                        SizedBox(height: theme.spacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: DSButton(
                                label: '取消',
                                variant: DSButtonVariant.outline,
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DSButton(
                                label: '保存',
                                onPressed: () async {
                                  final newMinutes = int.tryParse(
                                    durationController.text,
                                  );
                                  if (newMinutes == null || newMinutes <= 0) {
                                    Toast.error('请输入有效的时长');
                                    return;
                                  }

                                  Navigator.pop(ctx);
                                  await _updateRecord(
                                    record.id,
                                    Duration(minutes: newMinutes),
                                    notesController.text.trim(),
                                  );
                                },
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
    );
  }

  /// 删除记录
  void _deleteRecord(String recordId) async {
    try {
      final recordController = _habitsPlugin.getRecordController();
      await recordController.deleteCompletionRecord(recordId);

      setState(() {
        _allMonthRecords.removeWhere((r) => r.id == recordId);
        _allRecords.removeWhere((r) => r.id == recordId);
      });

      // 更新每日统计
      _updateDailyStats();

      if (mounted) {
        Toast.success('已删除打卡记录');
      }
    } catch (e) {
      if (mounted) {
        Toast.error('删除失败: $e');
      }
    }
  }

  /// 更新记录
  Future<void> _updateRecord(
    String recordId,
    Duration newDuration,
    String newNotes,
  ) async {
    try {
      final recordController = _habitsPlugin.getRecordController();

      // 先删除旧记录
      final oldRecord = _allMonthRecords.firstWhere((r) => r.id == recordId);
      await recordController.deleteCompletionRecord(recordId);

      // 创建新记录
      final newRecord = CompletionRecord(
        id: recordId,
        parentId: widget.habitId,
        date: oldRecord.date,
        duration: newDuration,
        notes: newNotes.isEmpty ? '' : newNotes,
      );
      await recordController.saveCompletionRecord(widget.habitId, newRecord);

      // 重新加载数据
      await _loadMonthRecords();

      if (mounted) {
        Toast.success('已更新打卡记录');
      }
    } catch (e) {
      if (mounted) {
        Toast.error('更新失败: $e');
      }
    }
  }

  /// 更新每日统计
  void _updateDailyStats() {
    final stats = <DateTime, _DailyStats>{};
    for (var record in _allMonthRecords) {
      final date = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      if (!stats.containsKey(date)) {
        stats[date] = _DailyStats();
      }
      stats[date]!.count++;
      stats[date]!.totalMinutes += record.duration.inMinutes;
    }
    setState(() {
      _dailyStats = stats;
    });
  }

  /// 构建详情行
  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = DSThemeBridge.resolve(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: DsTypography.body.copyWith(color: theme.text),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SuperCupertinoNavigationWrapper(
      title: Text(widget.habitTitle),
      largeTitle: widget.habitTitle,
      enableLargeTitle: true,
      body: _buildMainBody(),
    );
  }

  Widget _buildMainBody() {
    final theme = DSThemeBridge.resolve(context);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month Selector
          MonthSelector(
            selectedMonth: _focusedDay,
            onMonthSelected: (month) async {
              setState(() {
                _focusedDay = month;
                _calendarController.displayDate = month;
                _loadMonthRecords();
              });
              _updateRouteContext(month);
            },
            getMonthStats: _getMonthStats,
            primaryColor: theme.primary,
            customStatsBuilder: (stats) {
              final count = stats['count'] ?? 0;
              final totalMinutes = stats['totalMinutes'] ?? 0;
              return Column(
                children: [
                  Text(
                    '$count次',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _formatCompactDuration(totalMinutes.toInt()),
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
            maxDate: DateTime.now(),
          ),

          // Calendar
          SfCalendar(
            controller: _calendarController,
            view: CalendarView.month,
            initialDisplayDate: _focusedDay,
            minDate: DateTime(2020),
            maxDate: DateTime(2030),
            headerHeight: 0,
            viewHeaderHeight: 40,
            showNavigationArrow: false,
            monthViewSettings: const MonthViewSettings(
              showTrailingAndLeadingDates: true,
              dayFormat: 'EEE',
            ),
            cellBorderColor: Colors.transparent,
            selectionDecoration: const BoxDecoration(),
            monthCellBuilder: (BuildContext context, MonthCellDetails details) {
              final day = details.date;
              final isSelected =
                  _selectedDay != null && _isSameDay(day, _selectedDay!);
              return _buildCalendarCell(day, isSelected);
            },
            onTap: (CalendarTapDetails details) {
              if (details.date != null) {
                final newDate = details.date!;
                final currentDisplayMonth = _calendarController.displayDate;
                setState(() {
                  _selectedDay = newDate;
                  _focusedDay = newDate;
                  // 如果点击的日期不在当前显示的月份，更新 calendar controller
                  if (currentDisplayMonth != null &&
                      (newDate.month != currentDisplayMonth.month ||
                          newDate.year != currentDisplayMonth.year)) {
                    _calendarController.displayDate = newDate;
                    _loadMonthRecords();
                  }
                });
                _updateRouteContext(_focusedDay, selectedDay: _selectedDay);
              }
            },
            onViewChanged: (ViewChangedDetails details) {
              if (details.visibleDates.isNotEmpty) {
                final newFocusedDay =
                    details.visibleDates[details.visibleDates.length ~/ 2];
                _focusedDay = newFocusedDay;
                _loadMonthRecords();
                _updateRouteContext(newFocusedDay);
              }
            },
          ),

          // Daily Records List
          if (_selectedDay != null) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  DsIcon(DsIconKind.check, color: theme.primary),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy年MM月dd日').format(_selectedDay!),
                    style: DsTypography.heading.copyWith(
                      color: theme.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${_selectedDayRecords.length}次打卡)',
                    style: DsTypography.body.copyWith(color: theme.textSub),
                  ),
                ],
              ),
            ),
            if (_selectedDayRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    DsIcon(DsIconKind.calendar, size: 64, color: theme.textSub),
                    const SizedBox(height: 16),
                    Text(
                      '这天没有打卡记录',
                      style: DsTypography.body.copyWith(color: theme.textSub),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedDayRecords.length,
                itemBuilder: (context, index) {
                  final record = _selectedDayRecords[index];
                  return SwipeActionWrapper(
                    key: ValueKey(record.id),
                    leadingActions: [
                      SwipeActionOption(
                        label: '编辑',
                        icon: Icons.edit,
                        backgroundColor: theme.primary,
                        onTap: () => _showEditDialog(record),
                      ),
                    ],
                    trailingActions: [
                      SwipeActionOption(
                        label: '删除',
                        icon: Icons.delete,
                        backgroundColor: theme.danger,
                        onTap: () => _deleteRecord(record.id),
                        isDestructive: true,
                      ),
                    ],
                    child: DSThemeBridge(
                      child: Builder(
                        builder: (ctx) {
                          final dsTheme = DSThemeBridge.resolve(ctx);
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: DSCard(
                              padding: const EdgeInsets.all(12),
                              onTap: () => _showRecordDetail(record),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: dsTheme.primary.withValues(
                                        alpha: 0.2,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: DsIcon(
                                      DsIconKind.check,
                                      color: dsTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatDuration(record.duration),
                                          style: DsTypography.body.copyWith(
                                            color: dsTheme.text,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          DateFormat(
                                            'HH:mm',
                                          ).format(record.date),
                                          style: DsTypography.caption.copyWith(
                                            color: dsTheme.textSub,
                                          ),
                                        ),
                                        if (record.notes != null &&
                                            record.notes!.isNotEmpty)
                                          Text(
                                            record.notes!,
                                            style: DsTypography.caption
                                                .copyWith(
                                                  color: dsTheme.textSub,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
          ] else
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  DsIcon(
                    DsIconKind.calendarCheck,
                    size: 64,
                    color: theme.textSub,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '请选择一天查看记录',
                    style: DsTypography.body.copyWith(color: theme.textSub),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CompletionRecordModel {
  final String id;
  final DateTime date;
  final Duration duration;
  final String? notes;

  _CompletionRecordModel({
    required this.id,
    required this.date,
    required this.duration,
    this.notes,
  });
}

class _DailyStats {
  int count = 0;
  int totalMinutes = 0;
}
