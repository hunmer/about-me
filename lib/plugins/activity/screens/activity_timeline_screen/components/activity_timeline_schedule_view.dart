import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/activity/models/activity_record.dart';
import 'package:aboutme/widgets/swipe_action/index.dart';

/// 时间轴左侧连续竖向虚线（复刻 stitch 设计稿的点线）
class _DashedTimelinePainter extends CustomPainter {
  _DashedTimelinePainter({required this.color});

  final Color color;

  static const _dashHeight = 5.0;
  static const _dashSpace = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + _dashHeight), paint);
      y += _dashHeight + _dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedTimelinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 复刻 stitch「Today's Schedule」布局的活动时间轴：
/// 左侧时钟时间徽章 + 连续竖向虚线 + 右侧事件卡片
/// （圆形标签图标 + 标题/标签副标题 + 描述胶囊 + 时间范围与时长胶囊），
/// 卡片高度由内容决定，不再按时长等比拉伸。
class ActivityTimelineScheduleView extends StatelessWidget {
  const ActivityTimelineScheduleView({
    super.key,
    required this.activities,
    this.onActivityTap,
    this.onDeleteActivity,
    this.onUnrecordedTimeTap,
    this.getTagIcons,
    this.getTagColors,
    this.nested = false,
  });

  final List<ActivityRecord> activities;
  final Function(ActivityRecord)? onActivityTap;
  final Function(ActivityRecord)? onDeleteActivity;
  final Function(DateTime start, DateTime end)? onUnrecordedTimeTap;
  final List<IconData> Function(List<String> tagNames)? getTagIcons;
  final List<Color?> Function(List<String> tagNames)? getTagColors;

  /// 嵌套在外层滚动组件里时置 true：按内容高度布局并禁用自身滚动
  final bool nested;

  static const double _badgeWidth = 52;
  static const double _listHPadding = 16;

  // ---- 数据派生 ----

  /// 卡片主色：优先第一个标签的注册色，否则主题色
  Color _accentColor(AppThemeData theme, ActivityRecord activity) {
    if (getTagColors != null && activity.tags.isNotEmpty) {
      final color = getTagColors!(activity.tags).firstOrNull;
      if (color != null) return color;
    }
    return theme.primary;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return [
      if (hours > 0) 'activity_hoursFormat'.trParams({'hours': '$hours'}),
      if (minutes > 0 || hours == 0)
        'activity_minutesFormat'.trParams({'minutes': '$minutes'}),
    ].join(' ');
  }

  // ---- 片段构建 ----

  /// 左侧时间徽章（时钟图标 + 时间，压在竖向虚线上）
  Widget _buildTimeBadge(AppThemeData theme, DateTime time) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: JellyBox(
        width: _badgeWidth,
        height: 52,
        color: theme.surfaceAlt,
        radius: BorderRadius.circular(16),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsIcon(DsIconKind.clock, size: 13, color: theme.textSub),
            const SizedBox(height: 2),
            Text(
              DateFormat('H:mm').format(time),
              style: DsTypography.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 单行：时间徽章 + 卡片
  Widget _buildRow(Widget badge, Widget card) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [badge, const SizedBox(width: 12), Expanded(child: card)],
      ),
    );
  }

  Widget _buildTimelineItem(
    AppThemeData theme,
    ActivityRecord activity,
    int seed,
  ) {
    final accent = _accentColor(theme, activity);
    final duration = activity.endTime.difference(activity.startTime);

    IconData? tagIcon;
    if (getTagIcons != null && activity.tags.isNotEmpty) {
      tagIcon = getTagIcons!(activity.tags).firstOrNull;
    }

    return SwipeActionWrapper(
      key: ValueKey(activity.id),
      leadingActions: [
        SwipeActionPresets.edit(onTap: () => onActivityTap?.call(activity)),
      ],
      trailingActions: [
        SwipeActionPresets.delete(
          onTap: () => onDeleteActivity?.call(activity),
        ),
      ],
      child: Pressable(
        onPressed: () => onActivityTap?.call(activity),
        child: _buildRow(
          _buildTimeBadge(theme, activity.startTime),
          JellyBox(
            color: theme.surface,
            radius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部：圆形标签图标 + 标题/标签 + 心情
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: dsSketchDecoration(
                        theme: theme,
                        circle: true,
                        fillColor: accent.withValues(alpha: 0.16),
                        seed: seed,
                      ),
                      child: Center(
                        child:
                            tagIcon != null
                                ? Icon(tagIcon, size: 22, color: accent)
                                : DsIcon(
                                  DsIconKind.calendar,
                                  size: 22,
                                  color: accent,
                                ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsTypography.body.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: theme.text,
                            ),
                          ),
                          if (activity.tags.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                DsIcon(
                                  DsIconKind.tag,
                                  size: 11,
                                  color: theme.textSub,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    activity.tags.join(' • '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DsTypography.caption.copyWith(
                                      fontSize: 11,
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
                    if (activity.mood != null && activity.mood!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(activity.mood!, style: const TextStyle(fontSize: 18)),
                    ],
                  ],
                ),
                // 描述胶囊（通栏）
                if (activity.description != null &&
                    activity.description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: dsSketchDecoration(
                      theme: theme,
                      fillColor: theme.surfaceAlt,
                      radius: BorderRadius.circular(999),
                      seed: seed,
                    ),
                    child: Text(
                      activity.description!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DsTypography.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.text,
                      ),
                    ),
                  ),
                ],
                // 底部：时间范围 + 时长胶囊
                const SizedBox(height: 10),
                Row(
                  children: [
                    DsIcon(DsIconKind.clock, size: 12, color: theme.textSub),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('H:mm').format(activity.startTime)} - ${DateFormat('H:mm').format(activity.endTime)}',
                      style: DsTypography.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.textSub,
                      ),
                    ),
                    const Spacer(),
                    if (duration.inMinutes > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: dsSketchDecoration(
                          theme: theme,
                          fillColor: theme.hatch,
                          radius: BorderRadius.circular(999),
                          seed: seed,
                        ),
                        child: Text(
                          _formatDuration(duration),
                          style: DsTypography.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: theme.primaryText,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnrecordedTimeGap(
    AppThemeData theme,
    DateTime start,
    DateTime end,
  ) {
    final duration = end.difference(start);
    if (duration.inMinutes <= 1) return const SizedBox.shrink();

    return Pressable(
      onPressed: () => onUnrecordedTimeTap?.call(start, end),
      child: _buildRow(
        _buildTimeBadge(theme, start),
        JellyBox(
          color: theme.surfaceAlt,
          radius: BorderRadius.circular(24),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Row(
            children: [
              DsIcon(DsIconKind.plus, size: 16, color: theme.textSub),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${'activity_unrecordedTimeText'.tr} (${_formatDuration(duration)})',
                  style: DsTypography.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.textSub,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTimelineSlices(BuildContext context, AppThemeData theme) {
    final List<Widget> items = [];
    if (activities.isEmpty) return items;

    final dayStart = DateTime(
      activities.first.startTime.year,
      activities.first.startTime.month,
      activities.first.startTime.day,
    );
    DateTime lastEventEnd = dayStart;

    if (activities.first.startTime.isAfter(lastEventEnd)) {
      items.add(
        _buildUnrecordedTimeGap(theme, lastEventEnd, activities.first.startTime),
      );
    }

    for (int i = 0; i < activities.length; i++) {
      final currentActivity = activities[i];

      if (currentActivity.startTime.isAfter(lastEventEnd)) {
        items.add(
          _buildUnrecordedTimeGap(theme, lastEventEnd, currentActivity.startTime),
        );
      }

      items.add(_buildTimelineItem(theme, currentActivity, i));
      lastEventEnd = currentActivity.endTime;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (lastEventEnd.year == today.year &&
        lastEventEnd.month == today.month &&
        lastEventEnd.day == today.day) {
      if (now.isAfter(lastEventEnd)) {
        items.add(_buildUnrecordedTimeGap(theme, lastEventEnd, now));
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    // JellyBox / dsSketchDecoration 内部取 AppTheme，需包桥
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final slices = _buildTimelineSlices(context, theme);

          if (slices.isEmpty) {
            return Center(
              child: Text(
                'activity_noActivitiesText'.tr,
                style: DsTypography.body.copyWith(
                  color: theme.textSub,
                  fontSize: 16,
                ),
              ),
            );
          }

          const lineWidth = 2.0;
          return Stack(
            children: [
              Positioned(
                top: 24,
                left: _listHPadding + _badgeWidth / 2 - lineWidth / 2,
                bottom: 0,
                child: CustomPaint(
                  size: const Size(lineWidth, double.infinity),
                  painter: _DashedTimelinePainter(color: theme.textSub),
                ),
              ),
              ListView(
                shrinkWrap: nested,
                physics: nested ? const NeverScrollableScrollPhysics() : null,
                padding: EdgeInsets.fromLTRB(
                  _listHPadding,
                  8,
                  _listHPadding,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                children: slices,
              ),
            ],
          );
        },
      ),
    );
  }
}
