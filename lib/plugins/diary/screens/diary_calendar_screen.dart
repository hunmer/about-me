import 'package:get/get.dart';
import 'package:aboutme/plugins/bill/widgets/month_selector.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/widgets/quill_viewer/index.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'diary_editor_screen.dart';
import 'package:aboutme/plugins/diary/models/diary_entry.dart';
import 'package:aboutme/plugins/diary/utils/diary_utils.dart';
import 'package:aboutme/plugins/diary/widgets/diary_entry_card.dart';

class DiaryCalendarScreen extends StatefulWidget {
  final StorageManager storage;
  final DateTime? initialDate;

  const DiaryCalendarScreen({
    super.key,
    required this.storage,
    this.initialDate,
  });

  @override
  State<DiaryCalendarScreen> createState() => _DiaryCalendarScreenState();
}

class _DiaryCalendarScreenState extends State<DiaryCalendarScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  Map<DateTime, DiaryEntry> _diaryEntries = {};
  late CalendarController _calendarController;

  // 搜索相关状态
  String _searchQuery = '';
  List<DiaryEntry> _searchResults = [];

  // GlobalKeys for OpenContainer animation
  final GlobalKey _editButtonKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // 使用 initialDate 或默认为今天
    final initialDay = widget.initialDate ?? DateTime.now();
    _focusedDay = initialDay;
    _selectedDay = DateTime(initialDay.year, initialDay.month, initialDay.day);
    _calendarController = CalendarController();
    _calendarController.displayDate = initialDay;
    _calendarController.selectedDate = _selectedDay;
    _loadDiaryEntries();

    // 订阅同步刷新事件
    EventManager.instance.subscribe('diary_refresh', _handleSyncRefresh);
  }

  @override
  void dispose() {
    // 取消订阅，避免内存泄漏
    EventManager.instance.unsubscribe('diary_refresh', _handleSyncRefresh);
    _calendarController.dispose();
    super.dispose();
  }

  /// 处理同步刷新事件
  void _handleSyncRefresh(EventArgs args) {
    debugPrint('[DiaryCalendarScreen] 收到同步刷新事件');
    _loadDiaryEntries();
  }

  Future<void> _loadDiaryEntries() async {
    final entries = await DiaryUtils.loadDiaryEntries();
    debugPrint('Loaded ${entries.length} diary entries');
    if (mounted) {
      setState(() {
        _diaryEntries = entries;
      });
    }
  }

  /// 处理搜索查询
  Future<void> _handleSearch(String query) async {
    setState(() {
      _searchQuery = query;
    });

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    // 执行搜索
    final results = await DiaryUtils.searchDiaryEntries(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
      });
    }
  }

  void _onDayClicked(DateTime selectedDay, DateTime focusedDay) {
    // 标准化选中的日期，只保留年月日
    final normalizedSelectedDay = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    setState(() {
      _selectedDay = normalizedSelectedDay;
      _focusedDay = focusedDay;
    });

    // 更新路由上下文，使"询问当前上下文"功能能获取到当前日期
    final dateStr =
        '${normalizedSelectedDay.year}-${normalizedSelectedDay.month.toString().padLeft(2, '0')}-${normalizedSelectedDay.day.toString().padLeft(2, '0')}';
    RouteHistoryManager.updateCurrentContext(
      pageId: "/diary_detail",
      title: '日记详情 - $dateStr',
      params: {'date': dateStr},
    );
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<String> _extractImagesFromContent(String content) {
    // Simple regex to find markdown images ![alt](url)
    final regex = RegExp(r'!\[.*?\]\((.*?)\)');
    final matches = regex.allMatches(content);
    return matches.map((m) => m.group(1)!).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: SuperCupertinoNavigationWrapper(
        title: Text('diary_myDiary'.tr),
        largeTitle: 'diary_myDiary'.tr,

        enableSearchBar: true,
        searchPlaceholder: 'diary_searchPlaceholder'.tr,
        onSearchChanged: _handleSearch,
        onSearchSubmitted: _handleSearch,
        // Builder 让视图方法在主题桥之内构建，可读取 AppTheme
        body: Builder(builder: _buildCalendarView),
        searchBody: Builder(builder: _buildSearchResults),
      ),
    );
  }

  /// 构建搜索结果视图
  Widget _buildSearchResults(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Container(
      color: theme.background,
      child:
          _searchResults.isEmpty
              ? Center(
                child: DSEmptyState(
                  emoji: '🔍',
                  title: '没有找到匹配的日记',
                  message: _searchQuery.isNotEmpty ? '搜索词：$_searchQuery' : null,
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final entry = _searchResults[index];
                  return _buildSearchResultCard(context, entry);
                },
              ),
    );
  }

  /// 构建搜索结果卡片
  Widget _buildSearchResultCard(BuildContext context, DiaryEntry entry) {
    final theme = DSThemeBridge.resolve(context);
    return DiaryEntryCard(
      entry: entry,
      primaryColor: theme.primary,
      textColor: theme.text,
      onTap: () => _navigateToEntry(entry),
    );
  }

  /// 跳转到指定日记条目
  void _navigateToEntry(DiaryEntry entry) {
    NavigationHelper.push(
      context,
      DiaryEditorScreen(
        date: entry.date,
        storage: widget.storage,
        initialTitle: entry.title,
        initialContent: entry.content,
      ),
    ).then((_) => _loadDiaryEntries());
  }

  /// 构建日历视图
  Widget _buildCalendarView(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    // 确保_selectedDay也是标准化的
    final normalizedSelectedDay =
        _selectedDay != null
            ? DateTime(
              _selectedDay!.year,
              _selectedDay!.month,
              _selectedDay!.day,
            )
            : null;
    final selectedEntry =
        normalizedSelectedDay != null
            ? _diaryEntries[normalizedSelectedDay]
            : null;
    final textColor = theme.text;
    final primaryColor = theme.primary;

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              // Month Selector
              MonthSelector(
                selectedMonth: _focusedDay,
                maxDate: DateTime.now(), // 限制不能选择未来月份
                onMonthSelected: (month) {
                  setState(() {
                    _focusedDay = DateTime(
                      month.year,
                      month.month,
                      _focusedDay.day,
                    );
                    // 同步更新日历控制器的显示日期
                    _calendarController.displayDate = _focusedDay;
                  });
                },
                getMonthStats: (month) {
                  // For diary plugin, we'll show entry count instead of financial stats
                  final monthEntries =
                      _diaryEntries.entries.where((entry) {
                        return entry.key.year == month.year &&
                            entry.key.month == month.month;
                      }).toList();

                  final entryCount = monthEntries.length;
                  final totalWords = monthEntries.fold(
                    0,
                    (sum, entry) => sum + entry.value.content.length,
                  );

                  return {
                    'income':
                        entryCount.toDouble(), // Use income for entry count
                    'expense':
                        totalWords.toDouble(), // Use expense for word count
                  };
                },
                primaryColor: primaryColor,
                customStatsBuilder: (stats) {
                  final entryCount = stats['income']?.toInt() ?? 0;
                  final wordCount = stats['expense']?.toInt() ?? 0;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$entryCount篇日记',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF2ECC71), // 绿色
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        wordCount >= 1000
                            ? '${(wordCount / 1000).toStringAsFixed(1)}k字'
                            : '$wordCount字',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF3498DB), // 蓝色
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                },
              ),

              // Calendar
              SfCalendar(
                controller: _calendarController,
                view: CalendarView.month,
                initialDisplayDate: _focusedDay,
                minDate: DateTime.utc(2020, 1, 1),
                maxDate: DateTime.now(),
                headerHeight: 0,
                viewHeaderHeight: 40,
                showNavigationArrow: false,
                monthViewSettings: MonthViewSettings(
                  showTrailingAndLeadingDates: false,
                  dayFormat: 'EEE',
                  monthCellStyle: MonthCellStyle(
                    textStyle: TextStyle(
                      color: textColor.withValues(alpha: 0.6),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                cellBorderColor: Colors.transparent,
                selectionDecoration: const BoxDecoration(),
                monthCellBuilder: (
                  BuildContext context,
                  MonthCellDetails details,
                ) {
                  final day = details.date;
                  final normalizedDay = DateTime(day.year, day.month, day.day);
                  final entry = _diaryEntries[normalizedDay];
                  final isToday = _isSameDay(DateTime.now(), day);
                  final isSelected = _isSameDay(_selectedDay, day);

                  return _buildCalendarCellWithMood(
                    day,
                    textColor,
                    isToday || isSelected ? primaryColor : null,
                    entry,
                    isToday: isToday,
                    isSelected: isSelected,
                  );
                },
                onTap: (CalendarTapDetails details) {
                  if (details.date != null) {
                    _onDayClicked(details.date!, details.date!);
                    setState(() {
                      _calendarController.selectedDate = details.date;
                    });
                  }
                },
                onViewChanged: (ViewChangedDetails details) {
                  if (details.visibleDates.isNotEmpty) {
                    final newFocusedDay =
                        details.visibleDates[details.visibleDates.length ~/ 2];
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _focusedDay = newFocusedDay;
                        });
                      }
                    });
                  }
                },
              ),

              const SizedBox(height: 16),

              // Selected Day Details
              if (_selectedDay != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  margin: const EdgeInsets.only(
                    bottom: 80,
                  ), // Add padding for FAB
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 日期和编辑按钮行
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMMM d, yyyy').format(_selectedDay!),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          DSButton(
                            key: _editButtonKey,
                            label:
                                selectedEntry != null
                                    ? 'diary_edit'.tr
                                    : 'diary_create'.tr,
                            icon:
                                selectedEntry != null
                                    ? DsIconKind.edit
                                    : DsIconKind.plus,
                            size: DSButtonSize.sm,
                            onPressed: () {
                              final targetDay = _selectedDay ?? DateTime.now();
                              final normalizedTargetDay = DateTime(
                                targetDay.year,
                                targetDay.month,
                                targetDay.day,
                              );
                              NavigationHelper.openContainerWithHero(
                                context,
                                (_) => DiaryEditorScreen(
                                  date: normalizedTargetDay,
                                  storage: widget.storage,
                                  initialTitle: selectedEntry?.title ?? '',
                                  initialContent: selectedEntry?.content ?? '',
                                ),
                                sourceKey: _editButtonKey,
                                heroTag: 'diary_edit_button',
                                closedColor: primaryColor,
                                closedShape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ).then((_) => _loadDiaryEntries());
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (selectedEntry != null) ...[
                        // Images list (if any)
                        Builder(
                          builder: (context) {
                            final images = _extractImagesFromContent(
                              selectedEntry.content,
                            );
                            if (images.isEmpty) return const SizedBox.shrink();
                            return Container(
                              height: 100,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: images.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    width: 100,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          images[index],
                                        ), // Or FileImage if local
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        Container(
                          constraints: const BoxConstraints(
                            minHeight: 200, // Minimum height for better UX
                          ),
                          child: QuillViewer(
                            data: selectedEntry.content,
                            selectable: true,
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          height: 200,
                          child: Center(
                            child: DSEmptyState(
                              emoji: '📖',
                              title: 'diary_noDiaryForDate'.tr,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                const SizedBox(
                  height: 80,
                ), // Placeholder when no date is selected
            ],
          ),
        ),
        // FAB with container transform animation
        Positioned(
          bottom: 16,
          right: 16,
          child: DSFab(
            key: _fabKey,
            size: 56,
            onPressed: () {
              final targetDay = _selectedDay ?? DateTime.now();
              final normalizedTargetDay = DateTime(
                targetDay.year,
                targetDay.month,
                targetDay.day,
              );
              // 获取当前选中日期的条目
              final entry = _diaryEntries[normalizedTargetDay];
              NavigationHelper.openContainerWithHero(
                context,
                (_) => DiaryEditorScreen(
                  date: normalizedTargetDay,
                  storage: widget.storage,
                  initialTitle: entry?.title ?? '',
                  initialContent: entry?.content ?? '',
                ),
                sourceKey: _fabKey,
                heroTag: 'diary_fab_add',
                closedColor: primaryColor,
                closedShape: const CircleBorder(),
              ).then((_) => _loadDiaryEntries());
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarCellWithMood(
    DateTime day,
    Color textColor,
    Color? borderColor,
    DiaryEntry? entry, {
    bool isToday = false,
    bool isSelected = false,
  }) {
    // SfCalendar 的 monthCellBuilder 在第三方组件内部重建，
    // 其调用链可能位于主题桥之外，用 resolve 永不抛错地取令牌
    final theme = DSThemeBridge.resolve(context);
    final hasEntry = entry != null;

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border:
            (isSelected || isToday)
                ? Border.all(
                  color: borderColor ?? DsColors.transparent,
                  width: 2,
                )
                : null,
        color:
            hasEntry
                ? (theme.isDark
                    ? theme.surfaceAlt.withValues(alpha: 0.35)
                    : theme.surfaceAlt)
                : DsColors.transparent,
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          if (entry != null)
            Positioned(
              top: 4,
              right: 4,
              child:
                  entry.mood != null
                      ? Text(entry.mood!, style: const TextStyle(fontSize: 14))
                      : Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: borderColor ?? textColor,
                          shape: BoxShape.circle,
                        ),
                      ),
            ),
        ],
      ),
    );
  }
}
