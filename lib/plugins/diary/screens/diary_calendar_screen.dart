import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
import 'package:smooth_sheets/smooth_sheets.dart';
import 'diary_editor_screen.dart';
import 'package:aboutme/plugins/diary/models/diary_entry.dart';
import 'package:aboutme/plugins/diary/utils/diary_utils.dart';
import 'package:aboutme/plugins/diary/widgets/diary_calendar_day_cell.dart';
import 'package:aboutme/plugins/diary/widgets/diary_calendar_header.dart';
import 'package:aboutme/plugins/diary/widgets/diary_calendar_palette.dart';
import 'package:aboutme/plugins/diary/widgets/diary_mood_face.dart';
import 'package:aboutme/plugins/diary/widgets/diary_search_result_tile.dart';

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

  // 底部详情 sheet 控制器（smooth_sheets：拖拽吸附，点日期展开）
  final SheetController _sheetController = SheetController();

  // sheet 中档吸附像素（_buildDetailSheet 布局时缓存，供点日期展开使用）
  double _detailSnapPx = 300;

  // 头部心情提示文案（点击表情且今日已记录时显示，选日期时清除）
  String? _moodNotice;

  // 搜索相关状态
  String _searchQuery = '';
  List<DiaryEntry> _searchResults = [];

  // smooth_sheets 0.15.0 的内置拖拽识别器仅接收触摸设备；桌面端鼠标
  // 拖拽通过内容层的指针事件补充，触摸手势仍由 smooth_sheets 处理。
  bool _mouseDragging = false;
  double? _mouseDragOffset;

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
    _sheetController.dispose();
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
      _moodNotice = null;
    });
    // 展开详情 sheet 到中档
    _sheetController.animateTo(
      SheetOffset.absolute(_detailSnapPx),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );

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

  /// 今日（仅年月日）的日记条目
  DiaryEntry? _todayEntry() {
    final now = DateTime.now();
    return _diaryEntries[DateTime(now.year, now.month, now.day)];
  }

  /// 读取 sheet 当前可见比例；sheet 未完成首帧布局前 offset 为 null
  /// （读取会触发空断言），此时返回 null
  double? _safeSheetOffset() {
    try {
      return _sheetController.value;
    } catch (_) {
      return null;
    }
  }

  /// 关闭详情 sheet（完全隐藏）
  void _closeDetailSheet() {
    _sheetController.animateTo(
      const SheetOffset.absolute(0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleMouseDragStart(DragStartDetails details) {
    final offset = _sheetController.value;
    if (offset == null) return;
    _mouseDragging = true;
    _mouseDragOffset = offset;
  }

  void _handleMouseDragUpdate(DragUpdateDetails details) {
    if (!_mouseDragging) return;
    final metrics = _sheetController.metrics;
    final offset = _mouseDragOffset;
    if (metrics == null || offset == null) return;

    final nextOffset = (offset - details.delta.dy).clamp(
      metrics.minOffset,
      metrics.maxOffset,
    );
    _mouseDragOffset = nextOffset;
    _sheetController.animateTo(
      SheetOffset.absolute(nextOffset),
      duration: const Duration(milliseconds: 1),
      curve: Curves.linear,
    );
  }

  void _handleMouseDragEnd(DragEndDetails details) {
    if (!_mouseDragging) return;
    _mouseDragging = false;
    _mouseDragOffset = null;

    final metrics = _sheetController.metrics;
    if (metrics == null) return;
    final stops = <double>[metrics.minOffset, _detailSnapPx, metrics.maxOffset];
    final target = stops.reduce(
      (a, b) =>
          (a - metrics.offset).abs() <= (b - metrics.offset).abs() ? a : b,
    );
    _sheetController.animateTo(
      SheetOffset.absolute(target),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  /// 点击头部表情：今日未记录则带心情打开编辑页，已记录则提示今日心情
  void _onHeaderMoodTap(String emoji) {
    final today = _todayEntry();
    if (today == null) {
      final now = DateTime.now();
      final normalizedToday = DateTime(now.year, now.month, now.day);
      NavigationHelper.push(
        context,
        DiaryEditorScreen(
          date: normalizedToday,
          storage: widget.storage,
          initialContent: '',
          initialMood: emoji,
        ),
      ).then((_) => _loadDiaryEntries());
      return;
    }

    final mood = today.mood;
    setState(() {
      _moodNotice = mood != null
          ? '${'diary_todayMoodPrefix'.tr} $mood ${diaryMoodNameKeys[mood]?.tr ?? ''}'
                .trim()
          : 'diary_todayMoodNone'.tr;
    });
  }

  /// 月份选择回调：选中日可能超出目标月天数（如31日切到2月），取月末兜底
  void _onMonthSelected(DateTime month) {
    setState(() {
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      _focusedDay = DateTime(
        month.year,
        month.month,
        _focusedDay.day.clamp(1, lastDay),
      );
      _calendarController.displayDate = _focusedDay;
    });
  }

  /// 月份统计：日记篇数与总字数（供头部月份选择弹窗展示）
  Map<String, double> _getMonthStats(DateTime month) {
    final monthEntries = _diaryEntries.entries.where((entry) {
      return entry.key.year == month.year && entry.key.month == month.month;
    }).toList();

    final entryCount = monthEntries.length;
    final totalWords = monthEntries.fold(
      0,
      (sum, entry) => sum + entry.value.content.length,
    );

    return {
      'income': entryCount.toDouble(), // Use income for entry count
      'expense': totalWords.toDouble(), // Use expense for word count
    };
  }

  /// 月份统计展示：X篇日记 / X字
  Widget _buildMonthStats(Map<String, double> stats) {
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
  }

  @override
  Widget build(BuildContext context) {
    // 导航栏与头部同色（浅色粉 #FFAAB8 / 深色暗玫瑰）
    final palette = DiaryCalendarPalette.of(
      DSThemeBridge.resolve(context).isDark,
    );
    return DSThemeBridge(
      child: SuperCupertinoNavigationWrapper(
        title: Text('diary_myDiary'.tr),
        largeTitle: 'diary_myDiary'.tr,
        // 标题由粉色头部承载，这里只保留小导航栏 + 搜索
        enableLargeTitle: false,
        backgroundColor: palette.headerPink,

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

  /// 构建搜索结果视图：日记条目列表（无日历）
  Widget _buildSearchResults(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Container(
      color: theme.background,
      child: _searchResults.isEmpty
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DiarySearchResultTile(
                    entry: entry,
                    onTap: () => _navigateToEntry(entry),
                  ),
                );
              },
            ),
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
    final normalizedSelectedDay = _selectedDay != null
        ? DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)
        : null;
    final selectedEntry = normalizedSelectedDay != null
        ? _diaryEntries[normalizedSelectedDay]
        : null;
    final textColor = theme.text;
    final primaryColor = theme.primary;
    final palette = DiaryCalendarPalette.of(theme.isDark);
    final now = DateTime.now();

    return Stack(
      children: [
        Container(
          color: palette.canvas,
          child: Column(
            children: [
              // 粉色圆角头部：标题 + 横滚心情列表 + 悬浮月份胶囊
              DiaryCalendarHeader(
                palette: palette,
                selectedEntry: selectedEntry,
                focusedDay: _focusedDay,
                todayMood: _todayEntry()?.mood,
                noticeText: _moodNotice,
                onMoodTap: _onHeaderMoodTap,
                onMonthSelected: _onMonthSelected,
                getMonthStats: _getMonthStats,
                buildMonthStats: _buildMonthStats,
              ),

              const SizedBox(height: 34),

              // Calendar（填满剩余可用高度）
              Expanded(
                child: SfCalendar(
                  controller: _calendarController,
                  view: CalendarView.month,
                  initialDisplayDate: _focusedDay,
                  minDate: DateTime.utc(2020, 1, 1),
                  maxDate: DateTime.now(),
                  headerHeight: 0,
                  viewHeaderHeight: 36,
                  showNavigationArrow: false,
                  firstDayOfWeek: 1, // 周一开头（与设计稿一致）
                  todayHighlightColor: Colors.transparent,
                  viewHeaderStyle: ViewHeaderStyle(
                    backgroundColor: palette.canvas,
                    dayTextStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: palette.textMuted,
                    ),
                  ),
                  monthViewSettings: const MonthViewSettings(
                    showTrailingAndLeadingDates: true,
                    dayFormat: 'EEE',
                  ),
                  cellBorderColor: Colors.transparent,
                  selectionDecoration: const BoxDecoration(),
                  monthCellBuilder:
                      (BuildContext context, MonthCellDetails details) {
                        final day = details.date;
                        return DiaryCalendarDayCell(
                          palette: palette,
                          day: day,
                          entry:
                              _diaryEntries[DateTime(
                                day.year,
                                day.month,
                                day.day,
                              )],
                          isSelected: _isSameDay(_selectedDay, day),
                          isToday: _isSameDay(now, day),
                          isOtherMonth:
                              day.year != _focusedDay.year ||
                              day.month != _focusedDay.month,
                          isFuture: day.isAfter(
                            DateTime(now.year, now.month, now.day),
                          ),
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
                      final newFocusedDay = details
                          .visibleDates[details.visibleDates.length ~/ 2];
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
              ),
            ],
          ),
        ),
        // 底部详情 sheet（smooth_sheets：拖拽吸附，选中日期时展开）
        _buildDetailSheet(theme, selectedEntry, textColor, primaryColor),

        // FAB with container transform animation（sheet 展开时随偏移淡出避让）
        Positioned(
          bottom: 16,
          right: 16,
          child: AnimatedBuilder(
            animation: _sheetController,
            builder: (context, child) {
              // controller.value 为 sheet 可见高度（像素），弹出后渐隐；
              // sheet 首帧布局完成前 offset 不可读，视为隐藏态（FAB 可见）
              final offset = _safeSheetOffset() ?? 0;
              final progress = (offset / 120).clamp(0.0, 1.0);
              final opacity = 1 - progress;
              return IgnorePointer(
                ignoring: opacity < 0.5,
                child: Opacity(opacity: opacity, child: child),
              );
            },
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
        ),
      ],
    );
  }

  /// 底部详情 sheet（对齐 airbnb 示例结构：SheetSize.fit + 固定内容高度）：
  /// 三档吸附（收起露把手/中档详情/全屏），内容滚动与拖拽协调
  Widget _buildDetailSheet(
    AppThemeData theme,
    DiaryEntry? selectedEntry,
    Color textColor,
    Color primaryColor,
  ) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.maxHeight;
        final detailPx = viewportHeight * 0.45;
        // 缓存中档像素，供点日期展开使用
        _detailSnapPx = detailPx;

        return SheetViewport(
          child: Sheet(
            controller: _sheetController,
            // 默认完全隐藏（可见高度 0），点选日期后弹出
            initialOffset: SheetOffset.absolute(0),
            snapGrid: SheetSnapGrid(
              snaps: [
                const SheetOffset.absolute(0),
                SheetOffset.absolute(detailPx),
                SheetOffset.absolute(viewportHeight),
              ],
            ),
            // 内容滚动到底后再拖动才会收起 sheet
            scrollConfiguration: const SheetScrollConfiguration(),
            // 把整个面板设为拖拽区域，避免只能从可滚动内容区域拖动
            dragConfiguration: const SheetDragConfiguration(
              hitTestBehavior: HitTestBehavior.opaque,
            ),
            decoration: MaterialSheetDecoration(
              size: SheetSize.fit,
              color: theme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              shadowColor: Colors.black.withValues(alpha: 0.18),
            ),
            // 固定内容高度 = viewport 高，fit 模式下与三档吸附配合；
            // 注意：设置 scrollConfiguration 后 sheet 只对 scrollable 内容
            // 响应拖拽，因此把手/日期行也放进 ListView（整体可拖）
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              supportedDevices: const {PointerDeviceKind.mouse},
              onVerticalDragStart: _handleMouseDragStart,
              onVerticalDragUpdate: _handleMouseDragUpdate,
              onVerticalDragEnd: _handleMouseDragEnd,
              child: SizedBox(
                height: viewportHeight,
                child: ListView(
                  padding: EdgeInsets.only(bottom: bottomInset + 16),
                  children: [
                    // 把手
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.stroke,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // 日期和编辑按钮行（收起态仍可见）
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDay != null
                                ? DateFormat(
                                    'MMMM d, yyyy',
                                  ).format(_selectedDay!)
                                : '',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 关闭图标：完全隐藏 sheet
                              IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: textColor,
                                ),
                                tooltip: 'app_close'.tr,
                                onPressed: _closeDetailSheet,
                              ),
                              DSButton(
                                key: _editButtonKey,
                                label: selectedEntry != null
                                    ? 'diary_edit'.tr
                                    : 'diary_create'.tr,
                                icon: selectedEntry != null
                                    ? DsIconKind.edit
                                    : DsIconKind.plus,
                                size: DSButtonSize.sm,
                                onPressed: () {
                                  final targetDay =
                                      _selectedDay ?? DateTime.now();
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
                                      initialContent:
                                          selectedEntry?.content ?? '',
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 内容
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: selectedEntry != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Images list (if any)
                                Builder(
                                  builder: (context) {
                                    final images = extractImagesFromContent(
                                      selectedEntry.content,
                                    );
                                    if (images.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Container(
                                      height: 100,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: images.length,
                                        itemBuilder: (context, index) {
                                          return Container(
                                            width: 100,
                                            margin: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                QuillViewer(
                                  data: selectedEntry.content,
                                  selectable: true,
                                ),
                              ],
                            )
                          : SizedBox(
                              height: 160,
                              child: Center(
                                child: DSEmptyState(
                                  emoji: '📖',
                                  title: 'diary_noDiaryForDate'.tr,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
