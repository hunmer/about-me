import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/widgets/day_card_header.dart';
import 'package:aboutme/plugins/activity/models/activity_record.dart';

/// 活动单日卡片 - 展示某一天的活动记录
///
/// 供主页活动日卡使用：时间段/标题/时长/标签/心情，
/// 点击记录打开编辑（与时间线页一致）。
class ActivityDayCard extends StatelessWidget {
  /// 卡片对应的日期
  final DateTime date;

  /// 该日的活动记录（由调用方按日期过滤并排序）
  final List<ActivityRecord> records;

  /// 点击记录回调（打开编辑）
  final Function(ActivityRecord) onActivityTap;

  /// 新建活动回调（预填该日日期），为 null 时不显示 ＋ 按钮
  final Function(DateTime)? onAddActivity;

  /// 头部主题色
  final Color color;

  const ActivityDayCard({
    super.key,
    required this.date,
    required this.records,
    required this.onActivityTap,
    this.onAddActivity,
    this.color = Colors.pink,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surface,
          radius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DayCardHeader(
              color: color,
              date: date,
              count: records.length,
              onAdd: onAddActivity == null ? null : () => onAddActivity!(date),
            ),
            Expanded(
              child:
                  records.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DsIcon(
                              DsIconKind.clock,
                              size: 32,
                              color: theme.disabled.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'activity_dayCardEmpty'.tr,
                              style: DsTypography.caption.copyWith(
                                color: theme.disabled.withValues(alpha: 0.4),
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
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          return _buildRecordItem(context, records[index]);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  /// 单条活动行：开始时刻+时长 + 标题/标签 + 心情
  Widget _buildRecordItem(BuildContext context, ActivityRecord record) {
    final theme = DSThemeBridge.resolve(context);

    return InkWell(
      onTap: () => onActivityTap(record),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatTime(record.startTime),
                    style: DsTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDuration(record.durationInMinutes),
                    style: DsTypography.caption.copyWith(
                      fontSize: 10,
                      color: theme.disabled,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    style: DsTypography.caption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (record.tags.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        for (final tag in record.tags.take(3))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: dsSketchDecoration(
                              theme: theme,
                              fillColor: theme.surfaceAlt,
                              radius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: DsTypography.caption.copyWith(
                                fontSize: 9,
                                color: theme.textSub,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (record.mood != null && record.mood!.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(record.mood!, style: const TextStyle(fontSize: 15)),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// 紧凑时长文本：45分钟 / 1小时30分
  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes分钟';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours小时' : '$hours小时$rest分';
  }
}
