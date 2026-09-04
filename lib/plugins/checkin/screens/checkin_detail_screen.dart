import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/checkin/models/checkin_item.dart';
import 'package:aboutme/plugins/checkin/controllers/checkin_list_controller.dart';
import 'package:aboutme/utils/audio_service.dart';

class CheckinDetailScreen extends StatelessWidget {
  final CheckinItem checkinItem;
  final CheckinListController? controller;

  const CheckinDetailScreen({
    super.key,
    required this.checkinItem,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(checkinItem.name),
        backgroundColor: checkinItem.color,
      ),
      body: Column(
        children: [
          // 打卡状态卡片
          _buildStatusCard(),

          // 打卡历史列表
          Expanded(child: _buildHistoryList()),
        ],
      ),
      floatingActionButton: DSThemeBridge(
        child: Builder(
          builder: (context) {
            return DSFab(
              size: 56,
              color: checkinItem.color,
              icon:
                  checkinItem.isCheckedToday()
                      ? DsIconKind.close
                      : DsIconKind.check,
              onPressed: () async {
                if (controller != null) {
                  if (!checkinItem.isCheckedToday()) {
                    await AudioService().playCheckInSound();
                  }
                  // 使用 controller 处理打卡/取消打卡
                  await controller!.toggleCheckin(checkinItem);
                } else {
                  // 没有 controller 时的回退逻辑（直接操作，不广播事件）
                  if (!checkinItem.isCheckedToday()) {
                    await AudioService().playCheckInSound();
                    final now = DateTime.now();
                    final record = CheckinRecord(
                      startTime: now,
                      endTime: now,
                      checkinTime: now,
                      note: '快速打卡',
                    );
                    await checkinItem.addCheckinRecord(record);
                  } else {
                    final todayRecords = checkinItem.getTodayRecords();
                    if (todayRecords.isNotEmpty) {
                      await checkinItem.cancelCheckinRecord(
                        todayRecords.first.checkinTime,
                      );
                    }
                  }
                }

                // 刷新页面
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    NavigationHelper.createRoute(
                      CheckinDetailScreen(checkinItem: checkinItem),
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final consecutiveDays = checkinItem.getConsecutiveDays();
    final now = DateTime.now();
    final monthlyRecords = checkinItem.getMonthlyRecords(now.year, now.month);
    final monthlyCount = monthlyRecords.keys.length; // 统计打卡天数而不是记录数

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: DSCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatusItem(
                    context,
                    '今日状态',
                    checkinItem.isCheckedToday() ? '已打卡' : '未打卡',
                    checkinItem.isCheckedToday()
                        ? DsIcon(
                          DsIconKind.check,
                          color: checkinItem.color,
                          size: 32,
                        )
                        : DsIcon(
                          DsIconKind.close,
                          color: checkinItem.color,
                          size: 32,
                        ),
                  ),
                  _buildStatusItem(
                    context,
                    '连续打卡',
                    '$consecutiveDays天',
                    Icon(
                      Icons.local_fire_department,
                      color: checkinItem.color,
                      size: 32,
                    ),
                  ),
                  _buildStatusItem(
                    context,
                    '本月完成',
                    '$monthlyCount天',
                    DsIcon(
                      DsIconKind.calendarCheck,
                      color: checkinItem.color,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusItem(
    BuildContext context,
    String label,
    String value,
    Widget icon,
  ) {
    final theme = DSThemeBridge.resolve(context);
    return Column(
      children: [
        icon,
        const SizedBox(height: 8),
        Text(
          value,
          style: DsTypography.heading.copyWith(
            fontWeight: FontWeight.bold,
            color: checkinItem.color,
          ),
        ),
        Text(label, style: DsTypography.caption.copyWith(color: theme.textSub)),
      ],
    );
  }

  Widget _buildHistoryList() {
    // 获取最近30天的打卡记录
    final List<DateTime> dates = List.generate(
      30,
      (index) => DateTime.now().subtract(Duration(days: index)),
    );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final date = dates[index];
        final theme = DSThemeBridge.resolve(context);
        // 获取该日期的打卡记录
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final dayRecords = checkinItem.checkInRecords[dateStr] ?? [];
        final hasRecord = dayRecords.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DSCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        hasRecord
                            ? checkinItem.color.withAlpha(25)
                            : theme.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child:
                      hasRecord
                          ? DsIcon(
                            DsIconKind.check,
                            color: checkinItem.color,
                            size: 24,
                          )
                          : Icon(
                            Icons.circle_outlined,
                            color: theme.textSub,
                            size: 24,
                          ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${date.year}年${date.month}月${date.day}日',
                    style: DsTypography.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.text,
                    ),
                  ),
                ),
                if (hasRecord)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dayRecords.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: checkinItem.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${dayRecords.length}次',
                            style: DsTypography.caption.copyWith(
                              color: checkinItem.color,
                            ),
                          ),
                        ),
                      Text(
                        '已打卡',
                        style: DsTypography.body.copyWith(
                          color: checkinItem.color,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '未打卡',
                    style: DsTypography.body.copyWith(color: theme.textSub),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
