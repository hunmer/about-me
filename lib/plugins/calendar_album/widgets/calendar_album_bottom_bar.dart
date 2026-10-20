import 'package:aboutme/plugins/calendar_album/controllers/calendar_controller.dart';
import 'package:get/get.dart';
import 'package:aboutme/plugins/calendar_album/controllers/tag_controller.dart';
import 'package:aboutme/plugins/calendar_album/screens/calendar_screen.dart';
import 'package:aboutme/plugins/calendar_album/screens/tag_screen.dart';
import 'package:aboutme/plugins/calendar_album/screens/album_screen.dart';
import 'package:aboutme/plugins/calendar_album/screens/stats_screen.dart';
import 'package:aboutme/plugins/calendar_album/screens/entry_editor/entry_editor_sheet.dart';
import 'package:aboutme/plugins/calendar_album/calendar_album_plugin.dart';
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

  /// 构建 FAB（仅日历 tab 显示新建日记入口）
  Widget? _buildFab() {
    if (_currentPage != 0) return null;
    return DSThemeBridge(
      // DSFab 内部取 AppTheme，需包桥
      child: DSFab(
        color: widget.plugin.color,
        iconColor: Colors.white,
        icon: DsIconKind.edit,
        onPressed: () {
          EntryEditorSheet.show(
            context,
            initialDate: _calendarController.selectedDate,
            calendarController: _calendarController,
            tagController: _tagController,
          );
        },
      ),
    );
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
