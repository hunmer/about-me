/// 习惯插件 - 习惯日卡小组件注册（按日期聚合）
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/managers/home_date_controller.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/widgets/event_listener_container.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/habits/habits_plugin.dart';
import 'package:aboutme/plugins/habits/models/habit.dart';
import 'package:aboutme/plugins/habits/models/completion_record.dart';
import 'package:aboutme/plugins/habits/screens/habit_monthly_list_screen.dart';
import 'package:aboutme/plugins/habits/widgets/habit_day_card.dart';

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 加载某日各习惯的完成情况（习惯列表同步，完成记录按习惯异步读取）
Future<List<HabitDayStatus>> _statusesForDate(DateTime date) async {
  final plugin = HabitsPlugin.instance;
  final habits = plugin.getHabitController().getHabits() as List<Habit>;
  return Future.wait(
    habits.map((habit) async {
      final records = await plugin
          .getRecordController()
          .getHabitCompletionRecords(habit.id) as List<CompletionRecord>;
      return HabitDayStatus(
        habit: habit,
        records: records
            .where((record) => _isSameDay(record.date, date))
            .toList(),
      );
    }),
  );
}

/// 注册习惯日卡小组件（展示主页选中日期的习惯完成情况）
void registerDayCardWidget(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'habits_day_card',
      pluginId: 'habits',
      name: 'habits_dayCardName'.tr,
      description: 'habits_dayCardDesc'.tr,
      icon: Icons.self_improvement,
      color: Colors.amber,
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
          final statuses = await _statusesForDate(date);
          return statuses.any((status) => status.records.isNotEmpty);
        } catch (_) {
          return false;
        }
      },
      builder: (context, config) => const _HabitsDayCardHomeWidget(),
    ),
  );
}

/// 习惯日卡内容：读取主页选中日期，加载各习惯完成情况后渲染
class _HabitsDayCardHomeWidget extends StatefulWidget {
  const _HabitsDayCardHomeWidget();

  @override
  State<_HabitsDayCardHomeWidget> createState() =>
      _HabitsDayCardHomeWidgetState();
}

class _HabitsDayCardHomeWidgetState extends State<_HabitsDayCardHomeWidget> {
  List<HabitDayStatus> _statuses = [];
  DateTime? _loadingFor;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    HomeDateController().addListener(_loadStatuses);
    _loadStatuses();
  }

  @override
  void dispose() {
    HomeDateController().removeListener(_loadStatuses);
    super.dispose();
  }

  Future<void> _loadStatuses() async {
    final date = HomeDateController().date;
    _loadingFor = date;
    try {
      final statuses = await _statusesForDate(date);
      if (!mounted || _loadingFor != date) return;
      setState(() {
        _statuses = statuses;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || _loadingFor != date) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EventListenerContainer(
      events: const [
        'habit_completion_record_saved',
        'habit_data_changed',
        'habits_cache_updated',
      ],
      onEvent: _loadStatuses,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return HabitDayCard(
      date: HomeDateController().date,
      statuses: _statuses,
      onHabitTap: (habit) => NavigationHelper.push(
        context,
        HabitMonthlyListScreen(habitId: habit.id, habitTitle: habit.title),
      ),
    );
  }
}
