import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/habits/controllers/completion_record_controller.dart';
import 'package:aboutme/plugins/habits/controllers/habit_controller.dart';
import 'package:aboutme/plugins/habits/models/completion_record.dart';
import 'package:aboutme/plugins/habits/models/habit.dart';
import 'package:aboutme/plugins/habits/utils/habits_utils.dart';
import 'package:aboutme/widgets/stats/sketch_stats.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/wave_fill.dart';

/// 习惯统计页（视觉风格同 timer/chat 统计页）
///
/// - Hero 卡：今日打卡次数 + 较昨日增量胶囊 + 总打卡/习惯数 + 连续天数
/// - 今日打卡分布：0–22 点手绘墨线曲线
/// - 每日打卡分布：7 天胶囊柱状图，今日高亮
/// - 习惯活跃排行：打卡次数 + 累计时长时间线
class HabitsStatsView extends StatefulWidget {
  final HabitController habitController;
  final CompletionRecordController recordController;

  /// 刷新令牌：变化时重新统计（bottom bar 切到统计 tab 时递增）
  final int refreshToken;

  const HabitsStatsView({
    super.key,
    required this.habitController,
    required this.recordController,
    this.refreshToken = 0,
  });

  @override
  State<HabitsStatsView> createState() => _HabitsStatsViewState();
}

class _HabitsStatsViewState extends State<HabitsStatsView> {
  List<Habit> _habits = [];
  List<CompletionRecord> _records = [];
  bool _loading = true;
  int _selectedDay = 6; // 柱状图选中的天（默认今天，即第 7 天）

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(HabitsStatsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    // 记录按习惯分文件存储，逐习惯读取后合并
    final habits = widget.habitController.getHabits();
    final records = <CompletionRecord>[];
    for (final habit in habits) {
      records.addAll(
        await widget.recordController.getHabitCompletionRecords(habit.id),
      );
    }
    records.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) {
      setState(() {
        _habits = habits;
        _records = records;
        _loading = false;
      });
    }
  }

  // ===== 数据聚合 =====

  DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  List<CompletionRecord> _recordsOf(DateTime day) {
    return _records.where((r) => _dayOf(r.date) == day).toList();
  }

  /// 从今天开始往前连续有打卡的天数
  int get _streakDays {
    var streak = 0;
    var day = _dayOf(DateTime.now());
    if (_recordsOf(day).isEmpty) {
      day = day.subtract(const Duration(days: 1));
    }
    while (_recordsOf(day).isNotEmpty) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// 最近 7 天（含今天）
  List<DateTime> get _last7Days => List.generate(
    7,
    (i) => _dayOf(DateTime.now()).subtract(Duration(days: 6 - i)),
  );

  /// 习惯活跃排行（按打卡次数倒序，取前 8）
  List<(Habit, int, Duration)> get _habitRanking {
    final ranking = [
      for (final habit in _habits)
        (
          habit,
          _records.where((r) => r.parentId == habit.id).length,
          Duration(
            milliseconds: _records
                .where((r) => r.parentId == habit.id)
                .fold<int>(0, (sum, r) => sum + r.duration.inMilliseconds),
          ),
        ),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return ranking.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    return SuperCupertinoNavigationWrapper(
      title: Text('habits_statsTab'.tr),
      largeTitle: 'habits_statsTab'.tr,
      enableSearchBar: false,
      // Tab 切换挂载时墨线描画入场
      body: WiredDraw(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
          children: [
            _buildHeroCard(theme),
            const SizedBox(height: 16),
            _buildTodayLineChartCard(theme),
            const SizedBox(height: 16),
            _buildBarChartCard(theme),
            const SizedBox(height: 24),
            _buildHabitRankingSection(theme),
          ],
        ),
      ),
    );
  }

  // ===== Hero 卡：今日打卡次数 =====

  Widget _buildHeroCard(ThemeData theme) {
    final now = DateTime.now();
    final today = _recordsOf(_dayOf(now)).length;
    final yesterday =
        _recordsOf(_dayOf(now.subtract(const Duration(days: 1)))).length;
    final diff = today - yesterday;

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
                      'habits_statsTodayCheckin'.tr,
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
                            'habits_statsUnit'.tr,
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
                      'habits_statsVsYesterday'.trParams({
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
                  'habits_statsSummary'.trParams({
                    'total': '${_records.length}',
                    'habits': '${_habits.length}',
                  }),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                _streakDays > 0
                    ? 'habits_statsStreak'.trParams({'count': '$_streakDays'})
                    : 'habits_statsNotStarted'.tr,
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

  // ===== 今日打卡分布曲线（手绘墨线） =====

  Widget _buildTodayLineChartCard(ThemeData theme) {
    final now = DateTime.now();
    final today = _recordsOf(_dayOf(now));

    // 每 2 小时聚合一档打卡数（0–22 点共 12 档）
    final buckets = List.filled(12, 0.0);
    for (final r in today) {
      buckets[r.date.hour ~/ 2] += 1;
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
                  'habits_statsTodayChart'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${statsDateLabel(now)} · ${today.length} ${'habits_statsUnit'.tr}',
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

  // ===== 每日打卡分布柱状图 =====

  Widget _buildBarChartCard(ThemeData theme) {
    final days = _last7Days;
    final counts = days.map((d) => _recordsOf(d).length).toList();
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
                  'habits_statsDailyChart'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                'habits_statsDailyAvg'.trParams({
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
                  'habits_statsCountLabel'.trParams({
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
    return isToday ? '$label (${'habits_statsToday'.tr})' : label;
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
    final ratio = counts[i] == 0 ? 0.0 : (counts[i] / maxCount).clamp(0.06, 1.0);

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

  // ===== 习惯活跃排行 =====

  Widget _buildHabitRankingSection(ThemeData theme) {
    final ranking = _habitRanking;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'habits_statsRanking'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                'Top ${ranking.length}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (ranking.isEmpty)
          StatsSketchCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'habits_statsNotStarted'.tr,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          StatsSketchCard(
            child: Column(
              children: [
                for (var i = 0; i < ranking.length; i++)
                  _buildRankingItem(
                    theme,
                    ranking[i].$1,
                    ranking[i].$2,
                    ranking[i].$3,
                    i < ranking.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRankingItem(
    ThemeData theme,
    Habit habit,
    int count,
    Duration duration,
    bool showLine,
  ) {
    return IntrinsicHeight(
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
                    fillColor: theme.colorScheme.primary,
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
                habit.title,
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
          if (duration.inMinutes > 0) ...[
            Text(
              HabitsUtils.formatDuration(duration.inMinutes),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            '$count ${'habits_statsUnit'.tr}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
