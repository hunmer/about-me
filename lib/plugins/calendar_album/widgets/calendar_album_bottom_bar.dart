import 'dart:io';

import 'package:aboutme/plugins/calendar_album/controllers/calendar_controller.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/plugins/calendar_album/controllers/tag_controller.dart';
import 'package:aboutme/plugins/calendar_album/screens/calendar_screen.dart';
import 'package:aboutme/plugins/calendar_album/screens/tag_screen.dart';
import 'package:aboutme/plugins/calendar_album/screens/album_screen.dart';
import 'package:aboutme/plugins/calendar_album/screens/stats_screen.dart';
import 'package:aboutme/plugins/calendar_album/screens/entry_editor/entry_editor_sheet.dart';
import 'package:aboutme/plugins/calendar_album/calendar_album_plugin.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/expandable_fab.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';
import 'package:xue_hua_media_info/xue_hua_media_info.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aboutme/core/widgets/custom_bottom_bar.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// CalendarAlbum 插件的底部栏组件
/// 提供日历视图、标签视图、相册视图和统计视图四个 Tab 的切换功能
class CalendarAlbumBottomBar extends StatefulWidget {
  final CalendarAlbumPlugin plugin;

  const CalendarAlbumBottomBar({super.key, required this.plugin});

  @override
  State<CalendarAlbumBottomBar> createState() => _CalendarAlbumBottomBarState();
}

class _CalendarAlbumBottomBarState extends State<CalendarAlbumBottomBar>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _currentPage;
  final GlobalKey _bottomBarKey = GlobalKey();

  late final CalendarController _calendarController;
  late final TagController _tagController;

  @override
  void initState() {
    super.initState();
    _currentPage = 0;
    _tabController = TabController(length: 4, vsync: this);
    _tabController.animation?.addListener(() {
      final value = _tabController.animation!.value.round();
      if (value != _currentPage && mounted) {
        setState(() {
          _currentPage = value;
        });
      }
    });

    // 获取控制器
    _calendarController = widget.plugin.calendarController!;
    _tagController = widget.plugin.tagController!;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 构建 FAB（仅日历 tab 显示）：点击展开 创建新条目 / 选择照片 菜单
  Widget? _buildFab() {
    if (_currentPage != 0) return null;
    return ExpandableFab(
      color: widget.plugin.color,
      iconColor: Colors.white,
      icon: DsIconKind.edit,
      circularActions: true,
      actions: [
        ExpandableFabAction(
          icon: DsIconKind.edit,
          label: 'calendar_album_create_entry'.tr,
          onPressed: () => _showEditor(
            _calendarController.selectedDate,
          ),
        ),
        ExpandableFabAction(
          icon: DsIconKind.image,
          label: 'calendar_album_select_photos'.tr,
          onPressed: _createEntriesFromPhotos,
        ),
      ],
    );
  }

  /// 打开日记表单，[date] / [photos] 为新建模式的初始日期与图片
  Future<void> _showEditor(DateTime? date, [List<Map<String, dynamic>>? photos]) {
    return EntryEditorSheet.show(
      context,
      initialDate: date,
      initialImages: photos,
      calendarController: _calendarController,
      tagController: _tagController,
    );
  }

  /// 从照片创建日记：选图后按拍摄日期分组，
  /// 跨天时询问是否分开记录，是则逐个弹表单（上一个关闭后弹下一个）
  Future<void> _createEntriesFromPhotos() async {
    final results = await ImagePickerDialog.show<List<Map<String, dynamic>>>(
      context,
      saveDirectory: 'calendar_album/images',
      multiple: true,
      enableCompression: true,
      compressionQuality: 85,
    );
    if (results == null || results.isEmpty || !mounted) return;

    // 读取每张照片的拍摄日期，按天分组（保持选择顺序），
    // 分组日期随照片带入表单（驱动顶部日期按钮与保存日期）
    final groups = <DateTime, List<Map<String, dynamic>>>{};
    for (final result in results) {
      if (result['url'] == null) continue;
      final date = await _resolvePhotoDate(result);
      final day = DateTime(date.year, date.month, date.day);
      groups.putIfAbsent(day, () => []).add({...result, 'date': day});
    }
    if (groups.isEmpty || !mounted) return;

    final days = groups.keys.toList()..sort();
    if (days.length > 1 && await _confirmSplitByDate(days) && mounted) {
      for (final day in days) {
        if (!mounted) return;
        await _showEditor(day, groups[day]);
      }
      return;
    }
    // 单日或选择合并：全部照片并入一条，日期取最早一天
    await _showEditor(
      days.first,
      groups.values.expand((photos) => photos).toList(),
    );
  }

  /// 解析照片拍摄日期：EXIF 拍摄时间（xue_hua_media_info）优先，
  /// 回退文件修改时间，再回退当前时间
  Future<DateTime> _resolvePhotoDate(Map<String, dynamic> result) async {
    final bytes = result['bytes'];
    try {
      if (bytes is List<int>) {
        final meta = await MediaInfo.readImage(MediaSource.bytes(bytes));
        final taken = meta.dateTimeOriginal;
        if (taken != null) return taken;
      }
    } catch (_) {
      // 无 EXIF / 解析失败，走文件回退
    }
    final url = result['url'] as String?;
    if (url != null && url.startsWith('./')) {
      try {
        final absolutePath = await ImageUtils.getAbsolutePath(url);
        final file = File(absolutePath);
        if (absolutePath.isNotEmpty && await file.exists()) {
          return await file.lastModified();
        }
      } catch (_) {
        // 文件不可读（如远端存储），回退当前时间
      }
    }
    return DateTime.now();
  }

  /// 跨天分组确认对话框：确认=分开记录，取消=合并为一条
  Future<bool> _confirmSplitByDate(List<DateTime> days) async {
    final datesText = days
        .map((day) => DateFormat('yyyy/MM/dd').format(day))
        .join(' / ');
    final result = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSDialog(
        title: 'calendar_album_split_by_date_title'.tr,
        message: 'calendar_album_split_by_date_message'.trParams({
          'dates': datesText,
        }),
        cancelText: 'calendar_album_split_by_date_merge'.tr,
        confirmText: 'calendar_album_split_by_date_split'.tr,
        onCancel: () => Navigator.pop(dialogContext),
        onConfirm: () => Navigator.pop(dialogContext, true),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
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
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: _calendarController),
              ChangeNotifierProvider.value(value: _tagController),
            ],
            child: CalendarScreen(key: const PageStorageKey('calendar')),
          ),
          // Tab1: 标签视图
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: _calendarController),
              ChangeNotifierProvider.value(value: _tagController),
            ],
            child: TagScreen(key: const PageStorageKey('tags')),
          ),
          // Tab2: 相册视图
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: _calendarController),
              ChangeNotifierProvider.value(value: _tagController),
            ],
            child: AlbumScreen(key: const PageStorageKey('album')),
          ),
          // Tab3: 统计视图
          CalendarAlbumStatsView(
            calendarController: _calendarController,
            tagController: _tagController,
          ),
        ],
      ),
      fab: _buildFab(),
      items: [
        DSNavItem(
          icon: DsIconKind.calendar,
          label: 'calendar_album_calendar'.tr,
        ),
        DSNavItem(icon: DsIconKind.tag, label: 'calendar_album_tags'.tr),
        DSNavItem(icon: DsIconKind.image, label: 'calendar_album_album'.tr),
        DSNavItem(icon: DsIconKind.chart, label: 'calendar_album_statsTab'.tr),
      ],
    );
  }
}
