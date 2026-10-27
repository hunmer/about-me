/// 活动插件 - 活动日卡小组件注册（按日期聚合）
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/managers/home_date_controller.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/screens/route.dart';
import 'package:aboutme/widgets/event_listener_container.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/activity/activity_plugin.dart';
import 'package:aboutme/plugins/activity/models/activity_record.dart';
import 'package:aboutme/plugins/activity/screens/activity_edit_screen.dart';
import 'package:aboutme/plugins/activity/widgets/activity_day_card.dart';

/// 获取指定日期的活动记录（按开始时间升序，与时间线页一致）
Future<List<ActivityRecord>> _recordsForDate(DateTime date) async {
  final records = await ActivityPlugin.instance.activityService
      .getActivitiesForDate(date);
  records.sort((a, b) => a.startTime.compareTo(b.startTime));
  return records;
}

/// 打开活动编辑（与时间线页一致：底部弹层）
void _editActivity(BuildContext context, ActivityRecord record) {
  SmoothBottomSheet.show(
    context: context,
    builder: (context) {
      final screenHeight = MediaQuery.of(context).size.height;
      return SizedBox(
        height: screenHeight * 0.85,
        child: ActivityEditScreen(activity: record, showAsBottomSheet: true),
      );
    },
  );
}

/// 打开新建活动表单（预填该日日期）
void _openActivityEditor(BuildContext context, DateTime date) {
  NavigationHelper.push(context, ActivityEditScreen(selectedDate: date));
}

/// 注册活动日卡小组件（展示主页选中日期的活动记录）
void registerDayCardWidget(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'activity_day_card',
      pluginId: 'activity',
      name: 'activity_dayCardName'.tr,
      description: 'activity_dayCardDesc'.tr,
      icon: Icons.timeline,
      color: Colors.pink,
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
          return (await _recordsForDate(date)).isNotEmpty;
        } catch (_) {
          return false;
        }
      },
      dateCardRoute: AppRoutes.activity,
      dateStatsProvider: (date) async {
        final records = await _recordsForDate(date);
        return [
          DateStatItem(
            label: 'activity_dateStatLabel'.tr,
            value: records.length.toString(),
            unit: 'activity_dateStatUnit'.tr,
          ),
        ];
      },
      builder: (context, config) => const _ActivityDayCardHomeWidget(),
    ),
  );
}

/// 活动日卡内容：读取主页选中日期，加载该日活动后用 ActivityDayCard 渲染
class _ActivityDayCardHomeWidget extends StatefulWidget {
  const _ActivityDayCardHomeWidget();

  @override
  State<_ActivityDayCardHomeWidget> createState() =>
      _ActivityDayCardHomeWidgetState();
}

class _ActivityDayCardHomeWidgetState
    extends State<_ActivityDayCardHomeWidget> {
  List<ActivityRecord> _records = [];
  DateTime? _loadingFor;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    HomeDateController().addListener(_loadRecords);
    _loadRecords();
  }

  @override
  void dispose() {
    HomeDateController().removeListener(_loadRecords);
    super.dispose();
  }

  /// 加载选中日期的活动记录（按日分片存储，异步读取）
  Future<void> _loadRecords() async {
    final date = HomeDateController().date;
    _loadingFor = date;
    try {
      final records = await _recordsForDate(date);
      if (!mounted || _loadingFor != date) return;
      setState(() {
        _records = records;
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
      events: const ['activity_added', 'activity_updated', 'activity_deleted'],
      onEvent: _loadRecords,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      // DSLoadingDots 内部取 AppTheme，需包桥
      return Center(
        child: DSThemeBridge(
          child: Builder(builder: (_) => const DSLoadingDots()),
        ),
      );
    }

    return ActivityDayCard(
      date: HomeDateController().date,
      records: _records,
      onActivityTap: (record) => _editActivity(context, record),
      onAddActivity: (date) => _openActivityEditor(context, date),
    );
  }
}
