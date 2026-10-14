import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/widgets/day_card_header.dart';
import 'package:aboutme/plugins/calendar/models/event.dart';

/// 日历单日卡片 - 展示某一天的活动事件列表
///
/// 供主页日历日卡使用：事件名/时间/颜色标记，
/// 点击事件打开详情（与插件页一致）。
class EventDayCard extends StatelessWidget {
  /// 卡片对应的日期
  final DateTime date;

  /// 该日的事件列表（由调用方按日期过滤并排序）
  final List<CalendarEvent> events;

  /// 点击事件回调（打开详情）
  final Function(CalendarEvent) onEventTap;

  /// 新建事件回调（预填该日日期），为 null 时不显示 ＋ 按钮
  final Function(DateTime)? onAddEvent;

  /// 头部主题色
  final Color color;

  const EventDayCard({
    super.key,
    required this.date,
    required this.events,
    required this.onEventTap,
    this.onAddEvent,
    this.color = const Color.fromARGB(255, 211, 91, 91),
  });

  @override
  Widget build(BuildContext context) {
    final dsTheme = DSThemeBridge.resolve(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: dsSketchDecoration(
          theme: dsTheme,
          fillColor: dsTheme.surface,
          radius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DayCardHeader(
              color: color,
              date: date,
              count: events.length,
              onAdd: onAddEvent == null ? null : () => onAddEvent!(date),
            ),
            Expanded(
              child:
                  events.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DsIcon(
                              DsIconKind.calendar,
                              size: 32,
                              color: dsTheme.disabled.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'calendar_dayCardEmpty'.tr,
                              style: TextStyle(
                                color: dsTheme.disabled.withValues(
                                  alpha: 0.4,
                                ),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return _buildEventItem(context, event);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  /// 单条事件行：颜色条 + 标题 + 时间 + 图标
  Widget _buildEventItem(BuildContext context, CalendarEvent event) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => onEventTap(event),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 30,
              decoration: BoxDecoration(
                color: event.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _timeText(event),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.disabledColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(event.icon, size: 16, color: event.color),
          ],
        ),
      ),
    );
  }

  /// 事件时间文本：全天事件显示「全天」，否则显示起止时刻
  String _timeText(CalendarEvent event) {
    final start = event.startTime;
    final end = event.endTime;
    final startIsMidnight = start.hour == 0 && start.minute == 0;
    final endIsMidnight =
        end == null || (end.hour == 0 && end.minute == 0 && _isSameDay(end, start));

    if (startIsMidnight && endIsMidnight) {
      return 'calendar_allDay'.tr;
    }

    final startText = _formatTime(start);
    if (end == null || (end.hour == start.hour && end.minute == start.minute)) {
      return startText;
    }
    return '$startText - ${_formatTime(end)}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
