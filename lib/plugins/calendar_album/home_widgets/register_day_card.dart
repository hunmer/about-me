/// 日记相册插件 - 相册日卡小组件注册（按日期聚合）
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Memento/screens/home_screen/managers/home_widget_registry.dart';
import 'package:Memento/screens/home_screen/managers/home_date_controller.dart';
import 'package:Memento/screens/home_screen/models/home_widget_size.dart';
import 'package:Memento/screens/home_screen/widgets/home_widget.dart';
import 'package:Memento/widgets/event_listener_container.dart';
import 'package:Memento/core/navigation/navigation_helper.dart';
import 'package:Memento/plugins/calendar_album/calendar_album_plugin.dart';
import 'package:Memento/plugins/calendar_album/models/calendar_entry.dart';
import 'package:Memento/plugins/calendar_album/screens/entry_detail_screen.dart';
import 'package:Memento/plugins/calendar_album/screens/entry_editor_screen.dart';
import 'package:Memento/plugins/calendar_album/widgets/album_day_card.dart';

/// 获取指定日期的相册条目（存储按日分片，同步读取）
List<CalendarEntry> _entriesForDate(DateTime date) {
  return CalendarAlbumPlugin.instance.getEntriesForDate(date);
}

/// 注册相册日卡小组件（展示主页选中日期的照片/条目）
void registerDayCardWidget(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'calendar_album_day_card',
      pluginId: 'calendar_album',
      name: 'calendar_album_dayCardName'.tr,
      description: 'calendar_album_dayCardDesc'.tr,
      icon: Icons.photo_library,
      color: const Color.fromARGB(255, 245, 210, 52),
      defaultSize: const Wide2Size(),
      supportedSizes: const [LargeSize(), Large3Size(), Wide2Size(), Wide3Size()],
      category: 'home_categoryRecord'.tr,
      isDateDriven: true,
      hasDateData: (date) async {
        try {
          return _entriesForDate(date).isNotEmpty;
        } catch (_) {
          return false;
        }
      },
      builder: (context, config) => const _AlbumDayCardHomeWidget(),
    ),
  );
}

/// 相册日卡内容：读取主页选中日期的条目并用 AlbumDayCard 渲染
class _AlbumDayCardHomeWidget extends StatefulWidget {
  const _AlbumDayCardHomeWidget();

  @override
  State<_AlbumDayCardHomeWidget> createState() =>
      _AlbumDayCardHomeWidgetState();
}

class _AlbumDayCardHomeWidgetState extends State<_AlbumDayCardHomeWidget> {
  @override
  void initState() {
    super.initState();
    HomeDateController().addListener(_reload);
  }

  @override
  void dispose() {
    HomeDateController().removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return EventListenerContainer(
      events: const [
        'calendar_entry_added',
        'calendar_entry_updated',
        'calendar_entry_deleted',
      ],
      onEvent: _reload,
      child: Builder(
        builder: (context) {
          try {
            final date = HomeDateController().date;
            return AlbumDayCard(
              date: date,
              entries: _entriesForDate(date),
              onEntryTap: (entry) =>
                  NavigationHelper.push(context, EntryDetailScreen(entry: entry)),
              onAddEntry: (date) => NavigationHelper.push(
                context,
                EntryEditorScreen(initialDate: date, isEditing: false),
              ),
            );
          } catch (e) {
            return HomeWidget.buildErrorWidget(context, e.toString());
          }
        },
      ),
    );
  }
}
