import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/tracker/tracker_plugin.dart';
import 'package:aboutme/widgets/stats/sketch_stats.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/wave_fill.dart';

/// 目标追踪统计页（视觉风格同 todo/calendar_album 统计页）
///
/// - Hero 卡：今日记录数 + 较昨日增量胶囊 + 进行中/已完成 + 今日打卡目标数
/// - 今日记录分布：0–22 点手绘墨线曲线
/// - 每日记录分布：7 天胶囊柱状图，今日高亮
/// - 分组分布：目标按分组徽章
class TrackerStatsView extends StatefulWidget {
  const TrackerStatsView({super.key});

  @override
  State<TrackerStatsView> createState() => _TrackerStatsViewState();
}

class _TrackerStatsViewState extends State<TrackerStatsView> {
  int _selectedDay = 6; // 柱状图选中的天（默认今天，即第 7 天）

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SuperCupertinoNavigationWrapper(
      title: Text('tracker_statsTab'.tr),
      largeTitle: 'tracker_statsTab'.tr,
      enableSearchBar: false,
      // Tab 切换挂载时墨线描画入场
      body: WiredDraw(
        child: AnimatedBuilder(
          animation: TrackerPlugin.instance.controller,
          builder: (context, _) {
            final controller = TrackerPlugin.instance.controller;
            if (controller.goals.isEmpty) {
              return Center(
                child: DSEmptyState(
                  icon: DsIconKind.target,
                  title: 'tracker_statsNoGoals'.tr,
                  message: 'tracker_statsNoGoalsHint'.tr,
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
              children: [
                _buildHeroCard(theme, controller.goals, controller.records),
                const SizedBox(height: 16),
                _buildTodayLineChartCard(theme, controller.records),
                const SizedBox(height: 16),
                _buildBarChartCard(theme, controller.records),
                const SizedBox(height: 16),
                _buildGroupCard(theme, controller.goals),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===== 数据聚合 =====

  DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  List<Record> _recordsOf(List<Record> records, DateTime day) {
    return records.where((r) => _dayOf(r.recordedAt) == day).toList();
  }

  /// 今日有记录的不同目标数
  int _todayActiveGoals(List<Record> records) {
    final today = _dayOf(DateTime.now());
    return _recordsOf(records, today).map((r) => r.goalId).toSet().length;
  }

  /// 最近 7 天（含今天）
  List<DateTime> get _last7Days => List.generate(
    7,
    (i) => _dayOf(DateTime.now()).subtract(Duration(days: 6 - i)),
  );

  // ===== Hero 卡：今日记录数 =====

  Widget _buildHeroCard(ThemeData theme, List<Goal> goals, List<Record> records) {
    final now = DateTime.now();
    final today = _recordsOf(records, _dayOf(now)).length;
    final yesterday =
        _recordsOf(records, _dayOf(now.subtract(const Duration(days: 1)))).length;
    final diff = today - yesterday;
    final active = goals.where((g) => !g.isCompleted).length;
    final done = goals.where((g) => g.isCompleted).length;

    return StatsSketchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'tracker_statsTodayRecords'.tr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$today',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            'tracker_statsUnit'.tr,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 较昨日增量胶囊
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFFFDBCF),
                ),
                child: Row(
                  children: [
                    Icon(
                      diff >= 0 ? Icons.trending_up : Icons.trending_down,
                      size: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'tracker_statsVsYesterday'.trParams({
                        'diff': '${diff >= 0 ? '+' : ''}$diff',
                      }),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: theme.colorScheme.surfaceContainerHighest),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFA5E1E),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'tracker_statsSummary'.trParams({
                    'active': '$active',
                    'done': '$done',
                  }),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                'tracker_statsActiveGoals'.trParams({
                  'count': '${_todayActiveGoals(records)}',
                }),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== 今日记录分布曲线（手绘墨线） =====

  Widget _buildTodayLineChartCard(ThemeData theme, List<Record> records) {
    final now = DateTime.now();
    final today = _recordsOf(records, _dayOf(now));

    // 每 2 小时聚合一档记录数（0–22 点共 12 档）
    final buckets = List.filled(12, 0.0);
    for (final r in today) {
      buckets[r.recordedAt.hour ~/ 2] += 1;
    }
    final maxBucket = buckets.fold(0.0, (a, b) => a > b ? a : b);

    return StatsSketchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.show_chart,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'tracker_statsTodayChart'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${statsDateLabel(now)} · ${today.length} ${'tracker_statsUnit'.tr}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 170,
            child: Builder(
              builder: (context) {
                final dsTheme = DSThemeBridge.resolve(context);
                return SketchLineChart(
                  values: buckets,
                  maxValue: maxBucket < 1 ? 1.0 : maxBucket,
                  color: theme.colorScheme.primary,
                  drawConfig: dsTheme.wired.drawConfig,
                  drawProgress: WiredDrawTransition.progressOf(context),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < buckets.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  child: Center(
                    child: Text(
                      statsHourLabel(i * 2),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ===== 每日记录分布柱状图 =====

  Widget _buildBarChartCard(ThemeData theme, List<Record> records) {
    final days = _last7Days;
    final counts = days.map((d) => _recordsOf(records, d).length).toList();
    final avg = counts.fold<int>(0, (a, b) => a + b) / 7;

    // 按 weekday 索引（周一 = 0）
    final dayNames = List.generate(7, (i) => statsWeekdayShort(i + 1));

    return StatsSketchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'tracker_statsDailyChart'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                'tracker_statsDailyAvg'.trParams({
                  'count': avg.toStringAsFixed(1),
                }),
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 选中天的提示横幅
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.surfaceContainerLow,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _tooltipDayLabel(days[_selectedDay]),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  'tracker_statsCountLabel'.trParams({
                    'count': '${counts[_selectedDay]}',
                  }),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 7 天胶囊柱
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _buildChartColumn(theme, i, dayNames, counts),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _tooltipDayLabel(DateTime day) {
    final isToday = day == _dayOf(DateTime.now());
    final label = statsWeekdayLabel(day.weekday);
    return isToday ? '$label (${'tracker_statsToday'.tr})' : label;
  }

  Widget _buildChartColumn(
    ThemeData theme,
    int i,
    List<String> dayNames,
    List<int> counts,
  ) {
    final days = _last7Days;
    final isToday = i == 6;
    final selected = _selectedDay == i;
    final maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);
    final ratio = maxCount == 0 ? 0.06 : (counts[i] / maxCount).clamp(0.06, 1.0);

    final accent = theme.colorScheme.primary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedDay = i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${counts[i]}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isToday ? accent : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: isToday
                    ? accent.withValues(alpha: 0.25)
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
              ),
              padding: const EdgeInsets.all(2.5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox.expand(
                  child: WaveFill(
                    progress: ratio,
                    color: isToday ? accent : theme.colorScheme.onSurfaceVariant,
                    amplitude: 3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dayNames[days[i].weekday - 1],
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isToday ? accent : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? accent : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 分组分布 =====

  Widget _buildGroupCard(ThemeData theme, List<Goal> goals) {
    final counts = <String, int>{};
    for (final g in goals) {
      counts[g.group] = (counts[g.group] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return const SizedBox.shrink();

    final dsTheme = DSThemeBridge.resolve(context);
    final palette = [
      dsTheme.primary,
      dsTheme.success,
      dsTheme.warning,
      dsTheme.danger,
      dsTheme.secondary,
    ];

    return StatsSketchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.donut_small,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'tracker_statsGroupChart'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < entries.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: palette[i % palette.length].withValues(alpha: 0.12),
                  ),
                  child: Text(
                    '${entries[i].key} ${entries[i].value}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette[i % palette.length],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
