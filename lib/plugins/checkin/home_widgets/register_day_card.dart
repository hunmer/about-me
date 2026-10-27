/// 签到插件 - 签到日卡小组件注册（按日期聚合）
///
/// 签到是"动作"而非"表单"，故只提供日期卡片、不注册快速新建项；
/// 卡片上点击签到项即完成/取消该日签到。
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/managers/home_date_controller.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/screens/route.dart';
import 'package:aboutme/widgets/event_listener_container.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/item_event_args.dart';
import 'package:aboutme/plugins/checkin/checkin_plugin.dart';
import 'package:aboutme/plugins/checkin/models/checkin_item.dart';
import 'package:aboutme/plugins/checkin/widgets/checkin_day_card.dart';

/// 获取指定日期排班的签到项（与插件一致：frequency[weekday-1]，0=周一）
List<CheckinItem> _scheduledItems(DateTime date) {
  return CheckinPlugin.instance.checkinItems.where((item) {
    final index = date.weekday - 1;
    if (item.frequency.length != 7) return true;
    return item.frequency[index];
  }).toList();
}

/// 注册签到日卡小组件（展示主页选中日期的签到状态）
void registerDayCardWidget(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'checkin_day_card',
      pluginId: 'checkin',
      name: 'checkin_dayCardName'.tr,
      description: 'checkin_dayCardDesc'.tr,
      icon: Icons.check_circle,
      color: Colors.teal,
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
          // 该日有排班的签到项，或当天留有打卡记录（未排班但手动打卡过）
          if (_scheduledItems(date).isNotEmpty) return true;
          return CheckinPlugin.instance.checkinItems.any(
            (item) => item.getDateRecords(date).isNotEmpty,
          );
        } catch (_) {
          return false;
        }
      },
      dateCardRoute: AppRoutes.checkin,
      dateStatsProvider: (date) async {
        final scheduled = _scheduledItems(date);
        final done = scheduled
            .where((item) => item.getDateRecords(date).isNotEmpty)
            .length;
        return [
          DateStatItem(
            label: 'checkin_dateStatLabel'.tr,
            value: done.toString(),
            unit: '/${scheduled.length}',
          ),
        ];
      },
      builder: (context, config) => const _CheckinDayCardHomeWidget(),
    ),
  );
}

/// 签到日卡内容：读取主页选中日期的排班项，点击切换签到状态
class _CheckinDayCardHomeWidget extends StatefulWidget {
  const _CheckinDayCardHomeWidget();

  @override
  State<_CheckinDayCardHomeWidget> createState() =>
      _CheckinDayCardHomeWidgetState();
}

class _CheckinDayCardHomeWidgetState extends State<_CheckinDayCardHomeWidget> {
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

  /// 切换签到项在选中日期的签到状态（已签→取消最新一条；未签→快速签到）
  Future<void> _toggleCheckin(CheckinItem item) async {
    final date = HomeDateController().date;
    try {
      final records = item.getDateRecords(date);
      if (records.isNotEmpty) {
        await item.cancelCheckinRecord(records.first.checkinTime);
        _broadcast('cancelled', item);
      } else {
        final now = DateTime.now();
        final stamp = DateTime(
          date.year,
          date.month,
          date.day,
          now.hour,
          now.minute,
          now.second,
        );
        await item.addCheckinRecord(
          CheckinRecord(
            startTime: stamp,
            endTime: stamp,
            checkinTime: stamp,
            note: '快速打卡',
          ),
        );
        _broadcast('completed', item);
      }
      _reload();
    } catch (_) {
      // 与插件控制器一致：失败静默（插件内部已有日志）
    }
  }

  /// 广播签到事件（与 CheckinListController.notifyEvent 一致，驱动各处刷新）
  void _broadcast(String action, CheckinItem item) {
    EventManager.instance.broadcast(
      'checkin_$action',
      ItemEventArgs(
        eventName: 'checkin_$action',
        itemId: item.id,
        title: item.name,
        action: action,
        data: action == 'completed' ? {'isPenalty': item.isPenalty} : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EventListenerContainer(
      events: const [
        'checkin_completed',
        'checkin_cancelled',
        'checkin_reset',
        'checkin_deleted',
      ],
      onEvent: _reload,
      child: Builder(
        builder: (context) {
          try {
            final date = HomeDateController().date;
            return CheckinDayCard(
              date: date,
              items: _scheduledItems(date),
              onItemTap: (item) => _toggleCheckin(item),
            );
          } catch (e) {
            return HomeWidget.buildErrorWidget(context, e.toString());
          }
        },
      ),
    );
  }
}
