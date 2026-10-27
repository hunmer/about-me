import 'dart:io' show File;

import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/calendar_album/controllers/calendar_controller.dart';
import 'package:aboutme/plugins/calendar_album/controllers/tag_controller.dart';
import 'package:aboutme/plugins/calendar_album/models/calendar_entry.dart';
import 'package:aboutme/plugins/calendar_album/widgets/entry_list.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/enhanced_calendar/photo_calendar_view.dart';
import 'package:aboutme/widgets/enhanced_calendar/syncfusion_calendar.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skribble/skribble.dart';

import 'entry_editor/calendar_album_entry_form.dart';

final DateTime _calendarMinMonth = DateTime(2010, 1, 1);
const int _calendarLoadBatchSize = 3;
const String _photoViewPrefKey = 'calendar_album_use_photo_view';

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
    // 恢复持久化的视图模式
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _usePhotoView = prefs.getBool(_photoViewPrefKey) ?? false;
        });
      }
    });
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
    _searchResults = allEntries.where((entry) {
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
          // 切换 日历视图 / 照片视图
          DSThemeBridge(
            child: Builder(
              builder: (buildContext) {
                final theme = DSThemeBridge.resolve(buildContext);
                return DSIconButton(
                  icon: _usePhotoView ? DsIconKind.calendar : DsIconKind.image,
                  size: 36,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  tooltip:
                      (_usePhotoView
                              ? 'calendar_album_switch_calendar_view'
                              : 'calendar_album_switch_photo_view')
                          .tr,
                  onPressed: () {
                    setState(() => _usePhotoView = !_usePhotoView);
                    // 视图模式持久化，重启后保持
                    SharedPreferences.getInstance().then(
                      (prefs) =>
                          prefs.setBool(_photoViewPrefKey, _usePhotoView),
                    );
                  },
                );
              },
            ),
          ),
        ],
        body: _buildCalendarListView(calendarController, selectedDate),
      ),
    );
  }

  /// 打开日记编辑器（底部弹层，新建/编辑统一入口）
  Future<void> _openEntryEditor({
    CalendarEntry? entry,
    DateTime? initialDate,
    CalendarController? calendarController,
  }) {
    final controller =
        calendarController ??
        Provider.of<CalendarController>(context, listen: false);
    // 关闭后恢复选中日期并刷新
    final selectedDate = controller.selectedDate;
    return CalendarAlbumEntryForm.show(
      context,
      entry: entry,
      initialDate: initialDate,
      calendarController: controller,
    ).then((_) {
      if (mounted) {
        controller.selectDate(selectedDate);
        setState(() {});
      }
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
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final entry = _searchResults[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          // 挂载即描画入场
          child: WiredDraw(
            child: DSCard(
              onTap: () => _openEntryEditor(
                entry: entry,
                calendarController: calendarController,
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
                        itemCount: entry.imageUrls.length > 3
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
                        children: entry.tags
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
      return PhotoCalendarView(
        dayInfoBuilder: (month) =>
            _buildPhotoMonthInfo(calendarController, month),
        dataListenable: calendarController,
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
        _openEntryEditor(initialDate: pressedDay);
      },
      onHeaderTapped: onHeaderTapped,
    );
  }

  /// 照片视图某月数据适配：每天取首篇笔记的标题 + 首图
  Map<DateTime, PhotoCalendarDayInfo> _buildPhotoMonthInfo(
    CalendarController calendarController,
    DateTime month,
  ) {
    final Map<DateTime, PhotoCalendarDayInfo> dayData = {};
    final currentMonth = DateTime(month.year, month.month, 1);
    final nextMonth = DateTime(month.year, month.month + 1, 1);

    calendarController.entries.forEach((date, entries) {
      if (entries.isEmpty ||
          date.isBefore(currentMonth) ||
          !date.isBefore(nextMonth)) {
        return;
      }
      final first = entries.first;
      // 首图优先取缩略图（过滤空字符串占位），其次原图 / Markdown 内嵌图
      String? image;
      final thumbs = first.thumbUrls.where((t) => t.isNotEmpty);
      if (thumbs.isNotEmpty) {
        image = thumbs.first;
      } else if (first.imageUrls.isNotEmpty) {
        image = first.imageUrls.first;
      } else {
        final markdownImages = first.extractImagesFromMarkdown();
        if (markdownImages.isNotEmpty) {
          image = markdownImages.first;
        }
      }
      dayData[date] = PhotoCalendarDayInfo(title: first.title, imagePath: image);
    });
    return dayData;
  }

  void _showEntryDrawer(
    BuildContext context,
    CalendarController calendarController,
    DateTime selectedDate,
  ) {
    // 在 SmoothBottomSheet 之前获取 TagController 实例
    final tagController = Provider.of<TagController>(context, listen: false);

    SmoothBottomSheet.showWithTitle(
      context: context,
      title:
          '${DateFormat('yyyy年MM月dd日').format(selectedDate)}${'calendar_album_diary_for_date'.tr}',
      // 标题栏右侧新建按钮：带当前选中日期打开编辑器
      headerActions: [
        Builder(
          builder: (sheetContext) => DSButton(
            label: 'calendar_album_create_new_diary'.tr,
            size: DSButtonSize.sm,
            icon: DsIconKind.plus,
            onPressed: () {
              Navigator.pop(sheetContext); // 关闭抽屉
              _openEntryEditor(
                initialDate: selectedDate,
                calendarController: calendarController,
              );
            },
          ),
        ),
      ],
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.55,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: calendarController),
            ChangeNotifierProvider.value(value: tagController),
          ],
          child: Consumer2<CalendarController, TagController>(
            builder: (context, calendarController, tagController, child) {
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
        _openEntryEditor(entry: entry, calendarController: calendarController);
      },
      onEdit: (entry) {
        Navigator.pop(context); // 关闭抽屉
        _openEntryEditor(entry: entry, calendarController: calendarController);
      },
      onDelete: (entry) => showDSDialog(
        context: context,
        theme: DSThemeBridge.resolve(context),
        builder: (context) => DSDialog(
          title: 'core_delete'.tr,
          message: '${'core_confirmDelete'.tr} "${entry.title}"?',
          cancelText: 'calendar_album_cancel'.tr,
          confirmText: 'core_delete'.tr,
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
  /// 注意: isSelected 和 isToday 状态由 SyncfusionCalendarWidget 内部的 _monthCellBuilder 处理，
  /// 这里只需要提供背景图片和条目数量等静态数据
  Map<DateTime, CalendarDayData> _getCalendarDayData(DateTime month) {
    final monthKey = _getMonthKey(month);

    // 检查缓存 - 直接返回，不修改缓存中的选中/今日状态
    // SyncfusionCalendarWidget._monthCellBuilder 会自己计算这些动态状态
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
          // 以下状态由 SyncfusionCalendarWidget._monthCellBuilder 内部计算，这里设置默认值
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
      // 挂载即描画入场：墨线 + 贴纸一起动画
      child: WiredDraw(
        child: Builder(
          builder: (context) {
            final progress = WiredDrawTransition.progressOf(context);
            // 大容器走手绘面板：纸底 + 淡排线 + 墨线框
            return DsSketchPanel(
              theme: theme,
              radius: theme.radii.xl,
              padding: const EdgeInsets.all(8),
              seed: month.year * 12 + month.month,
              progress: progress,
              // 相机贴纸：压在边框右上角外侧，小倾斜增加手账感
              stickers: const [
                DsSketchSticker(
                  alignment: Alignment.topRight,
                  offset: Offset(10, -30),
                  size: 52,
                  rotation: 0.18,
                  svg: 'assets/icons/svg/camera.svg',
                ),
              ],
              child: Column(
                children: [
                  // 简化的月份标题 - 只显示文本
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
            );
          },
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
                  0,
                  16,
                  0,
                  16 + MediaQuery.paddingOf(context).bottom,
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
                  child: Center(child: DSLoadingDots(color: theme.textSub)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
