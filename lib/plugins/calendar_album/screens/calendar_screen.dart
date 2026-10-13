import 'dart:io' show File;

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/calendar_album/controllers/calendar_controller.dart';
import 'package:aboutme/plugins/calendar_album/controllers/tag_controller.dart';
import 'package:aboutme/plugins/calendar_album/models/calendar_entry.dart';
import 'package:aboutme/plugins/calendar_album/widgets/entry_list.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/enhanced_calendar/syncfusion_calendar.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skribble/skribble.dart';

import 'entry_detail_screen.dart';
import 'entry_editor_screen.dart';

final DateTime _calendarMinMonth = DateTime(2010, 1, 1);
final DateTime _calendarMaxMonth = DateTime(2030, 12, 31);
const int _calendarLoadBatchSize = 3;

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  DateTime _focusedDay = DateTime.now();
  // 搜索相关状态
  String _searchQuery = '';
  Map<String, bool> _searchFilters = {
    'title': true,
    'content': true,
    'tag': true,
  };
  List<CalendarEntry> _searchResults = [];
  // 是否使用照片视图（每天显示当日首篇笔记名称+图片）
  bool _usePhotoView = false;

  @override
  void initState() {
    super.initState();
    // 使用 addPostFrameCallback 确保在第一帧渲染后初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<CalendarController>(
          context,
          listen: false,
        ).selectDate(DateTime.now());
        // 初始化时设置路由上下文
        _updateRouteContext(DateTime.now());
      }
    });
  }

  /// 更新路由上下文，使"询问当前上下文"功能能获取到当前日期
  void _updateRouteContext(DateTime date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    RouteHistoryManager.updateCurrentContext(
      pageId: '/calendar_album_calendar',
      title: '日历日记 - $dateStr',
      params: {'date': dateStr},
    );
  }

  /// 获取图片的绝对路径
  Future<String> _getImagePath(String relativePath) async {
    try {
      return await ImageUtils.getAbsolutePath(relativePath);
    } catch (e) {
      debugPrint('获取图片路径失败: $e');
      return relativePath;
    }
  }

  /// 执行搜索操作
  void _performSearch(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final calendarController = Provider.of<CalendarController>(
      context,
      listen: false,
    );

    final allEntries = <CalendarEntry>[];
    // 获取所有日记条目
    calendarController.entries.forEach((date, entries) {
      allEntries.addAll(entries);
    });

    // 根据过滤器条件搜索
    _searchResults =
        allEntries.where((entry) {
          bool matches = false;

          // 搜索标题
          if (_searchFilters['title'] == true) {
            if (entry.title.toLowerCase().contains(query.toLowerCase())) {
              matches = true;
            }
          }

          // 搜索内容
          if (_searchFilters['content'] == true && !matches) {
            if (entry.content.toLowerCase().contains(query.toLowerCase())) {
              matches = true;
            }
          }

          // 搜索标签
          if (_searchFilters['tag'] == true && !matches) {
            if (entry.tags.any(
              (tag) => tag.toLowerCase().contains(query.toLowerCase()),
            )) {
              matches = true;
            }
          }

          return matches;
        }).toList();

    // 按创建时间倒序排列
    _searchResults.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final calendarController = Provider.of<CalendarController>(context);
    final tagController = Provider.of<TagController>(context);
    final selectedDate = calendarController.selectedDate;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: calendarController),
        ChangeNotifierProvider.value(value: tagController),
      ],
      child: SuperCupertinoNavigationWrapper(
        title: Text('calendar_album_calendar_diary'.tr),
        largeTitle: 'calendar_album_calendar_diary'.tr,
        // 启用搜索栏
        enableSearchBar: true,
        searchPlaceholder: 'calendar_album_search_diary_placeholder'.tr,
        onSearchChanged: (query) {
          _performSearch(query);
        },
        onSearchSubmitted: (query) {
          _performSearch(query);
        },
        // 启用搜索过滤器
        enableSearchFilter: true,
        filterLabels: {
          'title': 'calendar_album_title'.tr,
          'content': 'calendar_album_content'.tr,
          'tag': 'calendar_album_tag'.tr,
        },
        onSearchFilterChanged: (filters) {
          setState(() {
            _searchFilters = Map.from(filters);
          });
          // 重新执行搜索以应用新的过滤器
          if (_searchQuery.isNotEmpty) {
            _performSearch(_searchQuery);
          }
        },
        // 搜索结果页面
        searchBody: _buildSearchResults(calendarController, tagController),
        actions: [
          // SuperAppBar 的 actions 经 Overlay 渲染,DS 组件需自带 DSThemeBridge
          DSThemeBridge(
            child: Builder(
              builder: (buildContext) {
                final theme = DSThemeBridge.resolve(buildContext);
                return DSIconButton(
                  icon: DsIconKind.calendar,
                  size: 36,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  tooltip: 'calendar_album_back_to_current_month'.tr,
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime.now();
                      Provider.of<CalendarController>(
                        context,
                        listen: false,
                      ).selectDate(DateTime.now());
                    });
                    // 更新路由上下文
                    _updateRouteContext(DateTime.now());
                  },
                );
              },
            ),
          ),
          // 切换 日历视图 / 照片视图
          DSThemeBridge(
            child: Builder(
              builder: (buildContext) {
                final theme = DSThemeBridge.resolve(buildContext);
                return DSIconButton(
                  icon:
                      _usePhotoView ? DsIconKind.calendar : DsIconKind.image,
                  size: 36,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  tooltip: (_usePhotoView
                          ? 'calendar_album_switch_calendar_view'
                          : 'calendar_album_switch_photo_view')
                      .tr,
                  onPressed:
                      () => setState(() => _usePhotoView = !_usePhotoView),
                );
              },
            ),
          ),
        ],
        body: _buildCalendarListView(calendarController, selectedDate),
      ),
    );
  }

  /// 打开日记详情页
  Future<void> _openEntryDetail(
    CalendarController calendarController,
    TagController tagController,
    CalendarEntry entry,
  ) async {
    await NavigationHelper.push(
      context,
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: calendarController),
          ChangeNotifierProvider.value(value: tagController),
        ],
        child: EntryDetailScreen(entry: entry),
      ),
    );
    if (mounted) setState(() {});
  }

  /// 打开日记编辑器
  Future<void> _openEntryEditor({
    CalendarEntry? entry,
    DateTime? initialDate,
    required bool isEditing,
    CalendarController? calendarController,
  }) {
    if (entry != null && calendarController != null) {
      // 编辑已有条目后恢复选中日期
      final selectedDate = calendarController.selectedDate;
      return NavigationHelper.push(
        context,
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: calendarController),
            ChangeNotifierProvider.value(
              value: Provider.of<TagController>(context, listen: false),
            ),
          ],
          child: EntryEditorScreen(entry: entry, isEditing: true),
        ),
      ).then((_) {
        if (mounted) {
          calendarController.selectDate(selectedDate);
          setState(() {});
        }
      });
    }
    return NavigationHelper.push(
      context,
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(
            value:
                calendarController ??
                Provider.of<CalendarController>(context, listen: false),
          ),
          ChangeNotifierProvider.value(
            value: Provider.of<TagController>(context, listen: false),
          ),
        ],
        child: EntryEditorScreen(
          initialDate: initialDate,
          isEditing: isEditing,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  /// 构建搜索结果列表
  Widget _buildSearchResults(
    CalendarController calendarController,
    TagController tagController,
  ) {
    final theme = DSThemeBridge.resolve(context);

    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DsIcon(DsIconKind.search, size: 64, color: theme.textSub),
            const SizedBox(height: 16),
            Text(
              'calendar_album_enter_keyword_to_search'.tr,
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DsIcon(DsIconKind.book, size: 64, color: theme.textSub),
            const SizedBox(height: 16),
            Text(
              'calendar_album_no_matching_diaries'.tr,
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
            const SizedBox(height: 8),
            Text(
              'calendar_album_try_other_keywords'.tr,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final entry = _searchResults[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          // 挂载即描画入场
          child: WiredDraw(
            child: DSCard(
              onTap:
                  () => _openEntryDetail(
                    calendarController,
                    tagController,
                    entry,
                  ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.content.length > 100
                        ? '${entry.content.substring(0, 100)}...'
                        : entry.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.body.copyWith(
                      color: theme.textSub,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 显示图片缩略图
                  if (entry.imageUrls.isNotEmpty)
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount:
                            entry.imageUrls.length > 3
                                ? 3
                                : entry.imageUrls.length,
                        itemBuilder: (context, index) {
                          final imageUrl = entry.imageUrls[index];
                          return Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.only(right: 8),
                            color: theme.surfaceAlt,
                            child: ClipRRect(
                              borderRadius: theme.radii.lg,
                              child: FutureBuilder<String>(
                                future: _getImagePath(imageUrl),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Image.file(
                                      File(snapshot.data!),
                                      fit: BoxFit.cover,
                                      width: 80,
                                      height: 80,
                                    );
                                  }
                                  return DsIcon(
                                    DsIconKind.image,
                                    color: theme.textSub,
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (entry.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children:
                            entry.tags
                                .map((tag) => DSChip(label: tag))
                                .toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      DsIcon(
                        DsIconKind.calendar,
                        size: 14,
                        color: theme.textSub,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('yyyy-MM-dd').format(entry.createdAt),
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarListView(
    CalendarController calendarController,
    DateTime selectedDate,
  ) {
    void onDateSelected(DateTime selectedDay) {
      calendarController.selectDate(selectedDay);
      setState(() => _focusedDay = selectedDay);
      // 更新路由上下文
      _updateRouteContext(selectedDay);
      // 选中日期后自动弹出抽屉
      _showEntryDrawer(context, calendarController, selectedDay);
    }

    void onHeaderTapped(DateTime focusedMonth) {
      _showDatePicker(context, calendarController);
    }

    if (_usePhotoView) {
      return _PhotoCalendarView(
        calendarController: calendarController,
        selectedDate: selectedDate,
        onDateSelected: onDateSelected,
        onHeaderTapped: onHeaderTapped,
      );
    }

    return _VerticalCalendarView(
      calendarController: calendarController,
      selectedDate: selectedDate,
      focusedDay: _focusedDay,
      onDateSelected: onDateSelected,
      onDateLongPressed: (pressedDay) {
        // 长按可以选择日期并打开编辑器
        calendarController.selectDate(pressedDay);
        setState(() => _focusedDay = pressedDay);
        // 更新路由上下文
        _updateRouteContext(pressedDay);
        _openEntryEditor(initialDate: pressedDay, isEditing: false);
      },
      onHeaderTapped: onHeaderTapped,
    );
  }

  void _showEntryDrawer(
    BuildContext context,
    CalendarController calendarController,
    DateTime selectedDate,
  ) {
    // 在 showDSBottomSheet 之前获取 TagController 实例
    final tagController = Provider.of<TagController>(context, listen: false);

    showDSBottomSheet(
      context: context,
      title:
          '${DateFormat('yyyy年MM月dd日').format(selectedDate)}${'calendar_album_diary_for_date'.tr}',
      builder:
          (context) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: calendarController),
                ChangeNotifierProvider.value(value: tagController),
              ],
              child: Consumer<TagController>(
                builder: (context, tagController, child) {
                  return _buildDrawerEntryList(
                    context,
                    calendarController,
                    tagController,
                    selectedDate,
                  );
                },
              ),
            ),
          ),
    );
  }

  Widget _buildDrawerEntryList(
    BuildContext context,
    CalendarController calendarController,
    TagController tagController,
    DateTime selectedDate,
  ) {
    return EntryList(
      entries: calendarController.getEntriesForDate(selectedDate),
      onTap: (entry) {
        Navigator.pop(context); // 关闭抽屉
        _openEntryDetail(calendarController, tagController, entry);
      },
      onEdit: (entry) {
        Navigator.pop(context); // 关闭抽屉
        _openEntryEditor(
          entry: entry,
          isEditing: true,
          calendarController: calendarController,
        );
      },
      onDelete:
          (entry) => showDSDialog(
            context: context,
            theme: DSThemeBridge.resolve(context),
            builder:
                (context) => DSDialog(
                  title: 'common_delete'.tr,
                  message: '${'common_confirmDelete'.tr} "${entry.title}"?',
                  cancelText: 'calendar_album_cancel'.tr,
                  confirmText: 'common_delete'.tr,
                  confirmVariant: DSButtonVariant.destructive,
                  onCancel: () => Navigator.pop(context),
                  onConfirm: () {
                    calendarController.deleteEntry(entry);
                    Navigator.pop(context); // 关闭对话框
                    Navigator.pop(context); // 关闭抽屉并刷新
                    setState(() {});
                  },
                ),
          ),
      onCreateNew: () {
        Navigator.pop(context); // 关闭抽屉
        _openEntryEditor(
          initialDate: selectedDate,
          isEditing: false,
          calendarController: calendarController,
        );
      },
    );
  }

  Future<void> _showDatePicker(
    BuildContext context,
    CalendarController calendarController,
  ) async {
    final selectedDate = await showDSDatePickerDialog(
      context: context,
      initial: _focusedDay,
      theme: DSThemeBridge.resolve(context),
    );
    if (selectedDate != null) {
      setState(() {
        _focusedDay = DateTime(selectedDate.year, selectedDate.month);
      });
      Provider.of<CalendarController>(
        context,
        listen: false,
      ).selectDate(DateTime(selectedDate.year, selectedDate.month));
    }
  }
}

/// 垂直日历视图（默认视图）
class _VerticalCalendarView extends StatefulWidget {
  final CalendarController calendarController;
  final DateTime selectedDate;
  final DateTime focusedDay;
  final Function(DateTime) onDateSelected;
  final Function(DateTime) onDateLongPressed;
  final Function(DateTime) onHeaderTapped;

  const _VerticalCalendarView({
    required this.calendarController,
    required this.selectedDate,
    required this.focusedDay,
    required this.onDateSelected,
    required this.onDateLongPressed,
    required this.onHeaderTapped,
  });

  @override
  State<_VerticalCalendarView> createState() => _VerticalCalendarViewState();
}

class _VerticalCalendarViewState extends State<_VerticalCalendarView>
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  final List<DateTime> _months = [];
  final Map<String, Map<DateTime, CalendarDayData>> _cachedDayData = {};
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeMonths();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);

    // 监听 CalendarController 的变化，数据更新时清除缓存
    widget.calendarController.addListener(_onCalendarDataChanged);
  }

  void _onCalendarDataChanged() {
    // 清除所有缓存，强制重新加载数据
    if (mounted) {
      setState(() {
        _cachedDayData.clear();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    widget.calendarController.removeListener(_onCalendarDataChanged);
    super.dispose();
  }

  /// 初始化月份列表（从当前月份开始，从大到小显示）
  void _initializeMonths() {
    _months.clear();
    final now = DateTime.now();

    // 从当前月份开始，添加几个月份用于初始化显示
    for (int i = 0; i < 3; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      _months.add(month);
    }
  }

  /// 加载更多月份（向下滚动时加载更早的月份）
  bool _loadMorePreviousMonths() {
    if (_months.isEmpty || _isLoading) return false;

    setState(() => _isLoading = true);

    final addedMonths = <DateTime>[];
    bool hasChanges = false;

    // 获取最早的月份，然后添加更早的月份
    final earliestMonth = _months.last; // 因为列表是从大到小排列，所以最后的是最早的
    var currentMonth = DateTime(earliestMonth.year, earliestMonth.month - 1, 1);

    for (int i = 0; i < _calendarLoadBatchSize; i++) {
      if (currentMonth.isBefore(_calendarMinMonth)) {
        break;
      }

      _months.add(currentMonth);
      addedMonths.add(currentMonth);
      hasChanges = true;

      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
    }

    setState(() => _isLoading = false);

    // 触发数据缓存
    for (final added in addedMonths) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getCalendarDayData(added);
      });
    }

    return hasChanges;
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoading) return;

    // 使用 addPostFrameCallback 确保不在 build 阶段访问 position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || _isLoading) return;

      const threshold = 200.0;
      final position = _scrollController.position;

      // 只有向下滚动到底部时才加载更早的月份
      if (position.maxScrollExtent > 0 &&
          (position.maxScrollExtent - position.pixels) <= threshold) {
        _loadMorePreviousMonths();
      }
    });
  }

  /// 生成月份的唯一key
  String _getMonthKey(DateTime month) {
    return 'vertical_${month.year}_${month.month}';
  }

  /// 获取指定月份的日历数据（带缓存）- 垂直视图
  /// 注意: isSelected 和 isToday 状态由 EnhancedCalendar 内部的 _dayBuilder 处理，
  /// 这里只需要提供背景图片和条目数量等静态数据
  Map<DateTime, CalendarDayData> _getCalendarDayData(DateTime month) {
    final monthKey = _getMonthKey(month);

    // 检查缓存 - 直接返回，不修改缓存中的选中/今日状态
    // EnhancedCalendar._dayBuilder 会自己计算这些动态状态
    if (_cachedDayData.containsKey(monthKey)) {
      return _cachedDayData[monthKey]!;
    }

    // 计算新的日历数据
    final Map<DateTime, CalendarDayData> dayData = {};
    final currentMonth = DateTime(month.year, month.month, 1);
    final nextMonth = DateTime(month.year, month.month + 1, 1);

    // 获取当月所有条目
    widget.calendarController.entries.forEach((date, entries) {
      if (date.isAfter(currentMonth.subtract(const Duration(days: 1))) &&
          date.isBefore(nextMonth)) {
        // 获取当天日记的第一张图片作为背景
        String? backgroundImage;

        for (var entry in entries) {
          if (entry.imageUrls.isNotEmpty) {
            backgroundImage = entry.imageUrls.first;
            break;
          }

          final markdownImages = entry.extractImagesFromMarkdown();
          if (markdownImages.isNotEmpty) {
            backgroundImage = markdownImages.first;
            break;
          }
        }

        dayData[date] = CalendarDayData(
          date: date,
          backgroundImage: backgroundImage,
          count: entries.length,
          // 以下状态由 EnhancedCalendar._dayBuilder 内部计算，这里设置默认值
          isSelected: false,
          isToday: false,
          isCurrentMonth: date.year == month.year && date.month == month.month,
        );
      }
    });

    // 缓存数据
    _cachedDayData[monthKey] = dayData;
    return dayData;
  }

  /// 构建单个日历月份
  Widget _buildMonthCalendar(DateTime month) {
    final theme = DSThemeBridge.resolve(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // 大容器走手绘面板：纸底 + 淡排线 + 墨线框
      child: DsSketchPanel(
        theme: theme,
        radius: theme.radii.xl,
        padding: const EdgeInsets.all(8),
        seed: month.year * 12 + month.month,
        child: Column(
          children: [
            // 简化的月份标题 - 只显示文本
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                DateFormat('yyyy年MM月').format(month),
                style: DsTypography.heading.copyWith(color: theme.text),
                textAlign: TextAlign.center,
              ),
            ),
            // 日历内容 - 使用 GestureDetector 包装，确保滚动事件透传给外层 ListView
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 400, // 限制最大高度，防止内部滚动
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                // 为每个月份的日历添加独立 key，确保它们完全独立管理自己的状态
                child: SyncfusionCalendarWidget(
                  key: ValueKey(
                    'syncfusion_calendar_${month.year}_${month.month}',
                  ),
                  dayData: _getCalendarDayData(month),
                  focusedMonth: month,
                  selectedDate: widget.selectedDate,
                  onDaySelected: widget.onDateSelected,
                  onHeaderTapped: widget.onHeaderTapped,
                  enableNavigation: false, // 禁用内置导航，使用外部控制
                  locale: 'zh_CN',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = DSThemeBridge.resolve(context);

    return Column(
      children: [
        // 垂直滚动的日历列表
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  0, 16, 0, 16 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: _months.length,
                itemBuilder: (context, index) {
                  final month = _months[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: KeyedSubtree(
                      key: ValueKey('vertical_${_getMonthKey(month)}'),
                      child: _buildMonthCalendar(month),
                    ),
                  );
                },
              ),
              if (_isLoading)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: DSLoadingDots(color: theme.textSub),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 照片视图中某天的展示信息（当日首篇笔记）
class _PhotoDayInfo {
  final String title;
  final String? imagePath;

  const _PhotoDayInfo({required this.title, this.imagePath});
}

/// 照片视图：每天格子显示当日首篇笔记的名称（彩色小标签）+ 首图
/// （白色圆角边框、轻微倾斜的拍立得样式），参考 couple calendar 风格
class _PhotoCalendarView extends StatefulWidget {
  final CalendarController calendarController;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onHeaderTapped;

  const _PhotoCalendarView({
    required this.calendarController,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onHeaderTapped,
  });

  @override
  State<_PhotoCalendarView> createState() => _PhotoCalendarViewState();
}

class _PhotoCalendarViewState extends State<_PhotoCalendarView>
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  final List<DateTime> _months = [];
  final Map<String, Map<DateTime, _PhotoDayInfo>> _cachedDayData = {};
  bool _isLoading = false;

  // 标题小标签的柔和色板（参考图中的彩色事件标签）
  static const _chipColors = [
    Color(0xFFFFD54F),
    Color(0xFF4FC3F7),
    Color(0xFFFF8A80),
    Color(0xFFAED581),
    Color(0xFFCE93D8),
    Color(0xFFFFB74D),
    Color(0xFF80CBC4),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeMonths();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
    // 监听 CalendarController 的变化，数据更新时清除缓存
    widget.calendarController.addListener(_onCalendarDataChanged);
  }

  void _onCalendarDataChanged() {
    if (mounted) {
      setState(() {
        _cachedDayData.clear();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    widget.calendarController.removeListener(_onCalendarDataChanged);
    super.dispose();
  }

  /// 初始化月份列表（从当前月份开始，从大到小显示）
  void _initializeMonths() {
    _months.clear();
    final now = DateTime.now();
    for (int i = 0; i < 3; i++) {
      _months.add(DateTime(now.year, now.month - i, 1));
    }
  }

  /// 加载更多月份（向下滚动时加载更早的月份）
  bool _loadMorePreviousMonths() {
    if (_months.isEmpty || _isLoading) return false;

    setState(() => _isLoading = true);

    final addedMonths = <DateTime>[];
    final earliestMonth = _months.last;
    var currentMonth = DateTime(earliestMonth.year, earliestMonth.month - 1, 1);

    for (int i = 0; i < _calendarLoadBatchSize; i++) {
      if (currentMonth.isBefore(_calendarMinMonth)) break;
      _months.add(currentMonth);
      addedMonths.add(currentMonth);
      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
    }

    setState(() => _isLoading = false);

    for (final added in addedMonths) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getMonthDayData(added);
      });
    }

    return addedMonths.isNotEmpty;
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoading) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || _isLoading) return;

      const threshold = 200.0;
      final position = _scrollController.position;

      if (position.maxScrollExtent > 0 &&
          (position.maxScrollExtent - position.pixels) <= threshold) {
        _loadMorePreviousMonths();
      }
    });
  }

  String _getMonthKey(DateTime month) {
    return 'photo_${month.year}_${month.month}';
  }

  /// 获取指定月份每天的首篇笔记信息（带缓存）
  Map<DateTime, _PhotoDayInfo> _getMonthDayData(DateTime month) {
    final monthKey = _getMonthKey(month);
    if (_cachedDayData.containsKey(monthKey)) {
      return _cachedDayData[monthKey]!;
    }

    final Map<DateTime, _PhotoDayInfo> dayData = {};
    final currentMonth = DateTime(month.year, month.month, 1);
    final nextMonth = DateTime(month.year, month.month + 1, 1);

    widget.calendarController.entries.forEach((date, entries) {
      if (entries.isEmpty ||
          date.isBefore(currentMonth) ||
          !date.isBefore(nextMonth)) {
        return;
      }
      final first = entries.first;
      // 首图优先取缩略图，其次原图 / Markdown 内嵌图
      String? image;
      if (first.thumbUrls.isNotEmpty) {
        image = first.thumbUrls.first;
      } else if (first.imageUrls.isNotEmpty) {
        image = first.imageUrls.first;
      } else {
        final markdownImages = first.extractImagesFromMarkdown();
        if (markdownImages.isNotEmpty) {
          image = markdownImages.first;
        }
      }
      dayData[date] = _PhotoDayInfo(title: first.title, imagePath: image);
    });

    _cachedDayData[monthKey] = dayData;
    return dayData;
  }

  Color _chipColor(String title) =>
      _chipColors[title.hashCode.abs() % _chipColors.length];

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _imageFallback(AppThemeData theme) => Container(
    width: 52,
    height: 52,
    color: theme.surfaceAlt,
    child: DsIcon(DsIconKind.image, size: 20, color: theme.textSub),
  );

  /// 首图缩略图：白底圆角边框 + 按日期交错的小角度倾斜（拍立得效果）
  Widget _buildTiltedImage(String imagePath, DateTime day, AppThemeData theme) {
    final angle = ((day.day % 3) - 1) * 0.06;
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.stroke.withValues(alpha: 0.6)),
          boxShadow: DsShadows.soft,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: FutureBuilder<String>(
            future: ImageUtils.getAbsolutePath(imagePath),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return Image.file(
                  File(snapshot.data!),
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imageFallback(theme),
                );
              }
              return _imageFallback(theme);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMonthGrid(DateTime month) {
    final theme = DSThemeBridge.resolve(context);
    final dayData = _getMonthDayData(month);
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // 周日开头，与 SyncfusionCalendarWidget（firstDayOfWeek=7）一致
    final leadingBlanks = firstDay.weekday % 7;

    // 按周分行；行内任一天有笔记时用高行高容纳名称与图片
    final rows = <List<DateTime?>>[];
    var currentRow = List<DateTime?>.filled(leadingBlanks, null);
    for (var day = 1; day <= daysInMonth; day++) {
      currentRow.add(DateTime(month.year, month.month, day));
      if (currentRow.length == 7) {
        rows.add(currentRow);
        currentRow = <DateTime?>[];
      }
    }
    if (currentRow.isNotEmpty) {
      currentRow.addAll(List<DateTime?>.filled(7 - currentRow.length, null));
      rows.add(currentRow);
    }

    double rowHeight(List<DateTime?> row) {
      final hasContent = row.any((d) => d != null && dayData.containsKey(d));
      return hasContent ? 132.0 : 36.0;
    }

    Widget buildDayCell(DateTime day, _PhotoDayInfo? info, double height) {
      final isToday = _isSameDay(day, DateTime.now());
      final isSelected = _isSameDay(day, widget.selectedDate);

      return SizedBox(
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onDateSelected(day),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration:
                      isToday
                          ? BoxDecoration(
                            color: theme.text,
                            shape: BoxShape.circle,
                          )
                          : isSelected
                          ? BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.primary,
                              width: 1.5,
                            ),
                          )
                          : null,
                  child: Text(
                    '${day.day}',
                    style: DsTypography.caption.copyWith(
                      color: isToday ? theme.surface : theme.text,
                    ),
                  ),
                ),
                if (info != null) ...[
                  const SizedBox(height: 2),
                  // 当日首篇笔记名称
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _chipColor(info.title),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      info.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsTypography.caption.copyWith(
                        fontSize: 9,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (info.imagePath != null)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: _buildTiltedImage(info.imagePath!, day, theme),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // 大容器走手绘面板：纸底 + 淡排线 + 墨线框（与垂直视图一致）
      child: DsSketchPanel(
        theme: theme,
        radius: theme.radii.xl,
        padding: const EdgeInsets.all(8),
        seed: month.year * 12 + month.month,
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onHeaderTapped(month),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  DateFormat('yyyy年MM月').format(month),
                  style: DsTypography.heading.copyWith(color: theme.text),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Row(
              children:
                  ['日', '一', '二', '三', '四', '五', '六']
                      .map(
                        (label) => Expanded(
                          child: Center(
                            child: Text(
                              label,
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 4),
            for (final row in rows)
              Row(
                children: [
                  for (final day in row)
                    Expanded(
                      child:
                          day == null
                              ? SizedBox(height: rowHeight(row))
                              : buildDayCell(
                                day,
                                dayData[day],
                                rowHeight(row),
                              ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = DSThemeBridge.resolve(context);

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  0, 16, 0, 16 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: _months.length,
                itemBuilder: (context, index) {
                  final month = _months[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: KeyedSubtree(
                      key: ValueKey('photo_${_getMonthKey(month)}'),
                      child: _buildMonthGrid(month),
                    ),
                  );
                },
              ),
              if (_isLoading)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(child: DSLoadingDots(color: theme.textSub)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
