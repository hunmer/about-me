/// 日历插件 - 日历日卡小组件注册（按日期聚合）
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Memento/screens/home_screen/managers/home_widget_registry.dart';
import 'package:Memento/screens/home_screen/managers/home_date_controller.dart';
import 'package:Memento/screens/home_screen/models/home_widget_size.dart';
import 'package:Memento/screens/home_screen/widgets/home_widget.dart';
import 'package:Memento/core/navigation/navigation_helper.dart';
import 'package:Memento/plugins/calendar/calendar_plugin.dart';
import 'package:Memento/plugins/calendar/models/event.dart';
import 'package:Memento/plugins/calendar/pages/event_edit_page.dart';
import 'package:Memento/plugins/calendar/widgets/event_day_card.dart';

/// 与日历视图一致的事件归属判断：startTime 落在该日
bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 获取指定日期的事件（本地 + 系统 + 待办合并）
///
/// 日期视图的「时间」排序按开始时刻升序，其余保持合并顺序
List<CalendarEvent> _eventsForDate(DateTime date) {
  final events =
      CalendarPlugin.instance.controller.getAllEvents().where((event) {
        return _isSameDay(event.startTime, date);
      }).toList();

  if (HomeDateController().sortOption == DateViewSortOption.time) {
    events.sort((a, b) => a.startTime.compareTo(b.startTime));
  }
  return events;
}

/// 打开新建事件表单（预填该日日期）
void _openEventEditor(BuildContext context, DateTime date) {
  final plugin = CalendarPlugin.instance;
  NavigationHelper.push(
    context,
    EventEditPage(
      initialDate: date,
      onSave: (event) {
        plugin.controller.addEvent(event);
        plugin.controller.refresh();
      },
    ),
  );
}

/// 注册日历日卡小组件（展示主页选中日期的活动）
void registerDayCardWidget(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'calendar_day_card',
      pluginId: 'calendar',
      name: 'calendar_dayCardName'.tr,
      description: 'calendar_dayCardDesc'.tr,
      icon: Icons.event,
      color: const Color.fromARGB(255, 211, 91, 91),
      defaultSize: const LargeSize(),
      supportedSizes: const [
        LargeSize(),
        Large3Size(),
        Wide2Size(),
        Wide3Size(),
      ],
      category: 'home_categoryTools'.tr,
      isDateDriven: true,
      hasDateData: (date) async {
        try {
          return _eventsForDate(date).isNotEmpty;
        } catch (_) {
          return false;
        }
      },
      builder: (context, config) => const _CalendarDayCardHomeWidget(),
    ),
  );
}

/// 日历日卡内容：读取主页选中日期，过滤该日事件后用 EventDayCard 渲染
class _CalendarDayCardHomeWidget extends StatelessWidget {
  const _CalendarDayCardHomeWidget();

  @override
  Widget build(BuildContext context) {
    try {
      final plugin = CalendarPlugin.instance;

      // 同时监听事件数据变化、主页选中日期和排序变化
      return AnimatedBuilder(
        animation: Listenable.merge([
          plugin.controller,
          HomeDateController(),
        ]),
        builder: (context, _) {
          final date = HomeDateController().date;

          return EventDayCard(
            date: date,
            events: _eventsForDate(date),
            onEventTap: (event) => plugin.showEventDetails(context, event),
            onAddEvent: (date) => _openEventEditor(context, date),
          );
        },
      );
    } catch (e) {
      return HomeWidget.buildErrorWidget(context, e.toString());
    }
  }
}
