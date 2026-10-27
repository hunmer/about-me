/// 追踪插件 - 追踪日卡小组件注册（按日期聚合）
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/managers/home_date_controller.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/tracker/tracker_plugin.dart';
import 'package:aboutme/plugins/tracker/screens/goal_detail_screen.dart';
import 'package:aboutme/plugins/tracker/widgets/record_day_card.dart';

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 获取指定日期的记录（按记录时间归属）
List<Record> _recordsForDate(DateTime date) {
  final records = TrackerPlugin
      .instance
      .controller
      .records
      .where((record) => _isSameDay(record.recordedAt, date))
      .toList();

  if (HomeDateController().sortOption == DateViewSortOption.time) {
    records.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  }
  return records;
}

Map<String, Goal> _goalById() {
  return {
    for (final goal in TrackerPlugin.instance.controller.goals) goal.id: goal,
  };
}

/// 注册追踪日卡小组件（展示主页选中日期的目标记录）
void registerDayCardWidget(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'tracker_day_card',
      pluginId: 'tracker',
      name: 'tracker_dayCardName'.tr,
      description: 'tracker_dayCardDesc'.tr,
      icon: Icons.flag,
      color: Colors.red,
      defaultSize: const LargeSize(),
      supportedSizes: const [
        LargeSize(),
        Large3Size(),
        Wide2Size(),
        Wide3Size(),
      ],
      category: 'home_categoryRecord'.tr,
      isDateDriven: true,
      hasDateData: (date) async {
        try {
          return _recordsForDate(date).isNotEmpty;
        } catch (_) {
          return false;
        }
      },
      builder: (context, config) => const _TrackerDayCardHomeWidget(),
    ),
  );
}

/// 追踪日卡内容：读取主页选中日期，过滤该日记录后用 RecordDayCard 渲染
class _TrackerDayCardHomeWidget extends StatelessWidget {
  const _TrackerDayCardHomeWidget();

  @override
  Widget build(BuildContext context) {
    try {
      final controller = TrackerPlugin.instance.controller;

      // controller 为 ChangeNotifier：记录/目标变化与日期切换时刷新
      return AnimatedBuilder(
        animation: Listenable.merge([controller, HomeDateController()]),
        builder: (context, _) {
          final date = HomeDateController().date;

          return RecordDayCard(
            date: date,
            records: _recordsForDate(date),
            goalById: _goalById(),
            onRecordTap: (goal) => NavigationHelper.push(
              context,
              GoalDetailScreen(goal: goal),
            ),
            onAddRecord: () => openRecordCreateFlow(context, date),
          );
        },
      );
    } catch (e) {
      return HomeWidget.buildErrorWidget(context, e.toString());
    }
  }
}
