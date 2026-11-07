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
import 'package:aboutme/widgets/enhanced_calendar/photo_calendar_view.dart';
import 'package:aboutme/widgets/gallery_viewer.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skribble/skribble.dart';

import 'entry_editor/calendar_album_entry_form.dart';

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

    // 固定使用照片视图（每天显示当日首篇笔记名称+图片）
    return PhotoCalendarView(
      dayInfoBuilder: (month) =>
          _buildPhotoMonthInfo(calendarController, month),
      dataListenable: calendarController,
      selectedDate: selectedDate,
      onDateSelected: onDateSelected,
      // 有图片的日期点击被展开占用，长按触发选中弹抽屉
      onDayLongPressed: onDateSelected,
      onHeaderTapped: onHeaderTapped,
      // 点击图片条里的图片：打开当天大图预览
      onPhotoTap: (day, index) =>
          _openDayGallery(calendarController, day, index),
    );
  }

  /// 当天图片集合：逐张「缩略图显示 + 原图预览」配对
  /// （thumbUrls 与 imageUrls 按索引对应，无缩略图的张目回落原图；
  ///  无 imageUrls 时回落 Markdown 内嵌图）
  List<({String title, String display, String original, String dateText})>
  _collectDayPhotos(List<CalendarEntry> entries) {
    final result = <({String title, String display, String original, String dateText})>[];
    for (final entry in entries) {
      final dateText = DateFormat('yyyy/MM/dd').format(entry.createdAt);
      if (entry.thumbUrls.length == entry.imageUrls.length &&
          entry.imageUrls.isNotEmpty) {
        for (var i = 0; i < entry.imageUrls.length; i++) {
          result.add((
            title: entry.title,
            display: entry.thumbUrls[i].isNotEmpty
                ? entry.thumbUrls[i]
                : entry.imageUrls[i],
            original: entry.imageUrls[i],
            dateText: dateText,
          ));
        }
      } else if (entry.imageUrls.isNotEmpty) {
        for (final url in entry.imageUrls) {
          result.add((
            title: entry.title,
            display: url,
            original: url,
            dateText: dateText,
          ));
        }
      } else {
        for (final url in entry.extractImagesFromMarkdown()) {
          result.add((
            title: entry.title,
            display: url,
            original: url,
            dateText: dateText,
          ));
        }
      }
    }
    return result;
  }

  /// 照片视图某月数据适配：每天汇总全部笔记的图片（缩略图优先）
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
      dayData[date] = PhotoCalendarDayInfo(
        title: entries.first.title,
        photos: [
          for (final p in _collectDayPhotos(entries)) p.display,
        ],
      );
    });
    return dayData;
  }

  /// 打开当天图片大图预览（复用 GalleryViewer，原图优先显示）
  void _openDayGallery(
    CalendarController calendarController,
    DateTime day,
    int initialIndex,
  ) {
    final photos = _collectDayPhotos(
      calendarController.getEntriesForDate(day),
    );
    if (photos.isEmpty) return;
    NavigationHelper.push(
      context,
      GalleryViewer(
        title: 'calendar_album_calendar_diary'.tr,
        entranceAnimation: true,
        initialIndex: initialIndex.clamp(0, photos.length - 1),
        photos: [
          for (final p in photos)
            GalleryPhoto(
              url: p.original,
              caption: p.title,
              dateText: p.dateText,
            ),
        ],
      ),
    );
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
