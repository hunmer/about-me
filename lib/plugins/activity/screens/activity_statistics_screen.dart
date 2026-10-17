import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/activity/services/activity_service.dart';
import 'package:aboutme/widgets/statistics/models/statistics_models.dart';
import 'package:aboutme/widgets/statistics/utils/statistics_calculator.dart';
import 'package:aboutme/widgets/stats/sketch_stats.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'tag_statistics_screen.dart';

/// 活动统计页（统一手绘统计风格）
///
/// - 范围切换胶囊：今日 / 本周 / 本月
/// - Hero 卡：范围内总时长（小时）+ 活动数
/// - 今日范围：24 小时活动分布手绘墨线曲线
/// - 标签时长排行：时间线风格，点击跳转标签统计页
class ActivityStatisticsScreen extends StatefulWidget {
  final ActivityService activityService;

  const ActivityStatisticsScreen({super.key, required this.activityService});

  @override
  State<ActivityStatisticsScreen> createState() =>
      _ActivityStatisticsScreenState();
}

enum _StatsRange { today, week, month }

class _ActivityStatisticsScreenState extends State<ActivityStatisticsScreen> {
  _StatsRange _range = _StatsRange.week;
  StatisticsData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime start;
    switch (_range) {
      case _StatsRange.today:
        start = today;
      case _StatsRange.week:
        start = today.subtract(Duration(days: now.weekday - 1));
      case _StatsRange.month:
        start = DateTime(now.year, now.month, 1);
    }
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final data = await loadStatisticsData(
      widget.activityService,
      _range == _StatsRange.today
          ? DateRangeOption.today
          : _range == _StatsRange.week
          ? DateRangeOption.thisWeek
          : DateRangeOption.thisMonth,
      start,
      end,
    );
    if (mounted) {
      setState(() {
        _data = data;
        _loading = false;
      });
    }
  }

  void _switchRange(_StatsRange range) {
    if (_range == range) return;
    setState(() => _range = range);
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    return SuperCupertinoNavigationWrapper(
      title: Text('activity_activityStatistics'.tr),
      largeTitle: 'activity_activityStatistics'.tr,
      enableSearchBar: false,
      largeTitleActions: [_buildRangePill(theme)],
      // 页面挂载时墨线描画入场
      body: WiredDraw(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _buildHeroCard(theme),
            if (_range == _StatsRange.today &&
                (_data?.hourlyDistribution?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 16),
              _buildHourlyChartCard(theme),
            ],
            if ((_data?.distributionData?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 16),
              _buildDistributionSection(theme),
            ],
          ],
        ),
      ),
    );
  }

  // ===== 范围切换胶囊（大标题行右侧 action） =====

  Widget _buildRangePill(ThemeData theme) {
    Widget seg(_StatsRange range, String label) {
      final selected = _range == range;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _switchRange(range),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(_StatsRange.today, 'activity_statsToday'.tr),
          seg(_StatsRange.week, 'activity_statsWeek'.tr),
          seg(_StatsRange.month, 'activity_statsMonth'.tr),
        ],
      ),
    );
  }

  // ===== Hero 卡：总时长 =====

  Widget _buildHeroCard(ThemeData theme) {
    final totalHours = _data?.totalValue ?? 0;
    final totalActivities =
        _data?.extraData?['totalActivities'] as int? ?? 0;
    final isSingleDay = _range == _StatsRange.today;

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
                      isSingleDay
                          ? 'activity_statsTodayDuration'.tr
                          : 'activity_statsTotalDuration'.tr,
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
                          totalHours.toStringAsFixed(1),
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
                            'activity_hours'.tr,
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
                  'activity_statsActivities'.trParams({
                    'count': '$totalActivities',
                  }),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '${statsDateLabel(_data!.startDate)} - ${statsDateLabel(_data!.endDate)}',
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

  // ===== 24 小时活动分布曲线（手绘墨线） =====

  Widget _buildHourlyChartCard(ThemeData theme) {
    final hourly = _data!.hourlyDistribution!;
    // 每 2 小时聚合一档时长（0–22 点共 12 档）
    final buckets = List.filled(12, 0.0);
    for (final p in hourly) {
      buckets[p.date.hour ~/ 2] += p.value;
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
                  'activity_statsHourlyChart'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                'activity_statsMinutes'.tr,
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

  // ===== 标签时长排行 =====

  Widget _buildDistributionSection(ThemeData theme) {
    final distribution = _data!.distributionData!;
    final total = distribution.fold<double>(0, (sum, d) => sum + d.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.tag,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'activity_statsTagRanking'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${distribution.length} ${'activity_statsTagUnit'.tr}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StatsSketchCard(
          child: Column(
            children: [
              for (var i = 0; i < distribution.length; i++)
                _buildDistributionItem(
                  theme,
                  distribution[i],
                  total,
                  i < distribution.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionItem(
    ThemeData theme,
    DistributionData item,
    double total,
    bool showLine,
  ) {
    final color = item.color ?? theme.colorScheme.primary;
    final hours = item.value / 60;
    final percent = total > 0 ? item.value / total * 100 : 0.0;

    return IntrinsicHeight(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 点击标签跳转标签统计页
        onTap: () {
          if (item.label.isEmpty) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TagStatisticsScreen(
                tagName: item.label,
                activityService: widget.activityService,
              ),
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 时间线：圆点 + 连接线
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  const SizedBox(height: 5),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: dsSketchDecoration(
                      theme: DSThemeBridge.resolve(context),
                      circle: true,
                      fillColor: color,
                      strokeWidth: 1.4,
                    ),
                  ),
                  if (showLine)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.only(top: 4),
                        color: theme.colorScheme.surfaceContainerHigh,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: showLine ? 16 : 0),
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percent.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${hours.toStringAsFixed(1)} ${'activity_hours'.tr}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 加载活动统计数据（计算逻辑沿用原实现，标签平分时长）
Future<StatisticsData> loadStatisticsData(
  ActivityService activityService,
  DateRangeOption range,
  DateTime? startDate,
  DateTime? endDate,
) async {
  assert(
    startDate != null && endDate != null,
    'Start date and end date must not be null',
  );

  // 收集指定日期范围内的所有活动
  final allActivities = <Map<String, dynamic>>[];

  for (
    var date = DateTime(startDate!.year, startDate.month, startDate.day);
    date.isBefore(
      DateTime(
        endDate!.year,
        endDate.month,
        endDate.day,
      ).add(const Duration(days: 1)),
    );
    date = date.add(const Duration(days: 1))
  ) {
    final dailyActivities = await activityService.getActivitiesForDate(date);
    for (var activity in dailyActivities) {
      // 如果活动有标签，为每个标签创建一条记录用于统计
      if (activity.tags.isNotEmpty) {
        // 将时长平分到每个标签
        final durationPerTag =
            activity.durationInMinutes.toDouble() / activity.tags.length;
        for (var tag in activity.tags) {
          allActivities.add({
            'title': activity.title,
            'startTime': activity.startTime.toIso8601String(),
            'endTime': activity.endTime.toIso8601String(),
            'duration': durationPerTag, // 平分后的时长
            'tags': tag, // 单个标签字符串
            'description': activity.description ?? '',
            'mood': activity.mood ?? '',
          });
        }
      } else {
        // 如果活动没有标签，创建一条记录标记为"未分类"
        allActivities.add({
          'title': activity.title,
          'startTime': activity.startTime.toIso8601String(),
          'endTime': activity.endTime.toIso8601String(),
          'duration': activity.durationInMinutes.toDouble(),
          'tags': '未分类',
          'description': activity.description ?? '',
          'mood': activity.mood ?? '',
        });
      }
    }
  }

  // 计算统计指标
  final distributionData = StatisticsCalculator.calculateDistributionByTag(
    allActivities,
    tagField: 'tags',
    valueField: 'duration',
    totalMinutes: null,
  );

  // 为分布数据分配颜色
  final coloredDistributionData =
      StatisticsCalculator.assignColorsToDistribution(distributionData, const [
        Color(0xFF60A5FA), // blue-400
        Color(0xFF4ADE80), // green-400
        Color(0xFF818CF8), // indigo-400
        Color(0xFFFB923C), // orange-400
        Color(0xFFF87171), // red-400
        Color(0xFFFACC15), // yellow-400
        Color(0xFF2DD4BF), // teal-400
        Color(0xFFA78BFA), // purple-400
      ]);

  // 计算24小时分布（仅单日有效）
  List<TimeSeriesPoint>? hourlyDistribution;
  final isSingleDay =
      startDate.year == endDate.year &&
      startDate.month == endDate.month &&
      startDate.day == endDate.day;

  if (isSingleDay) {
    hourlyDistribution = StatisticsCalculator.calculateHourlyDistribution(
      allActivities,
      dateField: 'startTime',
      valueField: 'duration',
    );
  }

  // 计算总时长
  final totalDuration = allActivities.fold(
    0.0,
    (sum, activity) => sum + activity['duration'],
  );

  return StatisticsData(
    title: 'activity_activityStatistics'.tr,
    startDate: startDate,
    endDate: endDate,
    totalValue: totalDuration / 60, // 转换为小时
    totalValueLabel: 'activity_hours'.tr,
    distributionData: coloredDistributionData,
    hourlyDistribution: hourlyDistribution,
    extraData: {
      'totalActivities': allActivities.length,
    },
  );
}
