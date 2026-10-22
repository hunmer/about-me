import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/todo/controllers/task_controller.dart';
import 'package:aboutme/plugins/todo/models/task.dart';
import 'package:aboutme/widgets/stats/sketch_stats.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/wave_fill.dart';

/// 待办统计页（视觉风格同 timer/chat 统计页）
///
/// - Hero 卡：今日完成数 + 较昨日增量胶囊 + 进行中/已完成 + 连续完成天数
/// - 今日完成分布：0–22 点手绘墨线曲线
/// - 每日完成分布：7 天胶囊柱状图，今日高亮
/// - 优先级分布：全部任务按四象限徽章
class TodoStatsView extends StatefulWidget {
  final TaskController taskController;

  /// 刷新令牌：变化时重新统计（bottom bar 切到统计 tab 时递增）
  final int refreshToken;

  const TodoStatsView({
    super.key,
    required this.taskController,
    this.refreshToken = 0,
  });

  @override
  State<TodoStatsView> createState() => _TodoStatsViewState();
}

class _TodoStatsViewState extends State<TodoStatsView> {
  List<Task> _completed = [];
  List<Task> _all = [];
  bool _loading = true;
  int _selectedDay = 6; // 柱状图选中的天（默认今天，即第 7 天）

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(TodoStatsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadStats();
    }
  }

  void _loadStats() {
    final completed = List<Task>.from(widget.taskController.completedTasks);
    final all = [...widget.taskController.tasks, ...completed];
    if (mounted) {
      setState(() {
        _completed = completed;
        _all = all;
        _loading = false;
      });
    }
  }

  // ===== 数据聚合 =====

  DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  List<Task> _completedOf(DateTime day) {
    return _completed.where((t) {
      final d = t.completedDate;
      return d != null && _dayOf(d) == day;
    }).toList();
  }

  /// 从今天开始往前连续有完成记录的天数
  int get _streakDays {
    var streak = 0;
    var day = _dayOf(DateTime.now());
    if (_completedOf(day).isEmpty) {
      day = day.subtract(const Duration(days: 1));
    }
    while (_completedOf(day).isNotEmpty) {
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    return SuperCupertinoNavigationWrapper(
      title: Text('todo_statsTab'.tr),
      largeTitle: 'todo_statsTab'.tr,
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
            const SizedBox(height: 16),
            _buildPriorityCard(theme),
          ],
        ),
      ),
    );
  }

  // ===== Hero 卡：今日完成数 =====

  Widget _buildHeroCard(ThemeData theme) {
    final now = DateTime.now();
    final today = _completedOf(_dayOf(now)).length;
    final yesterday =
        _completedOf(_dayOf(now.subtract(const Duration(days: 1)))).length;
    final diff = today - yesterday;
    final active = widget.taskController.tasks.length;

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
                      'todo_statsTodayCompleted'.tr,
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
                            'todo_statsUnit'.tr,
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
                      'todo_statsVsYesterday'.trParams({
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
                  'todo_statsSummary'.trParams({
                    'active': '$active',
                    'done': '${_completed.length}',
                  }),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                _streakDays > 0
                    ? 'todo_statsStreak'.trParams({'count': '$_streakDays'})
                    : 'todo_statsNotStarted'.tr,
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

  // ===== 今日完成分布曲线（手绘墨线） =====

  Widget _buildTodayLineChartCard(ThemeData theme) {
    final now = DateTime.now();
    final today = _completedOf(_dayOf(now));

    // 每 2 小时聚合一档完成数（0–22 点共 12 档）
    final buckets = List.filled(12, 0.0);
    for (final t in today) {
      final d = t.completedDate;
      if (d != null) buckets[d.hour ~/ 2] += 1;
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
                  'todo_statsTodayChart'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${statsDateLabel(now)} · ${today.length} ${'todo_statsUnit'.tr}',
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

  // ===== 每日完成分布柱状图 =====

  Widget _buildBarChartCard(ThemeData theme) {
    final days = _last7Days;
    final counts = days.map((d) => _completedOf(d).length).toList();
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
                  'todo_statsDailyChart'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                'todo_statsDailyAvg'.trParams({
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
                  'todo_statsCountLabel'.trParams({
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
    return isToday ? '$label (${'todo_statsToday'.tr})' : label;
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

  // ===== 优先级分布 =====

  Widget _buildPriorityCard(ThemeData theme) {
    final counts = <TaskPriority, int>{};
    for (final t in _all) {
      counts[t.priority] = (counts[t.priority] ?? 0) + 1;
    }

    const keys = [
      TaskPriority.q1,
      TaskPriority.q2,
      TaskPriority.q3,
      TaskPriority.q4,
    ];
    final entries = keys
        .where((k) => counts[k] != null && counts[k]! > 0)
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    // 优先级语义色（与四象限视图一致：q1 红 / q2 绿 / q3 黄 / q4 蓝）
    final dsTheme = DSThemeBridge.resolve(context);
    final colors = {
      TaskPriority.q1: dsTheme.danger,
      TaskPriority.q2: dsTheme.success,
      TaskPriority.q3: dsTheme.warning,
      TaskPriority.q4: dsTheme.primary,
    };

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
                  'todo_statsPriorityChart'.tr,
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
              for (final k in entries)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: colors[k]!.withValues(alpha: 0.12),
                  ),
                  child: Text(
                    '${_priorityLabel(k)} ${counts[k]}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors[k],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _priorityLabel(TaskPriority p) => switch (p) {
    TaskPriority.q1 => 'todo_q1'.tr,
    TaskPriority.q2 => 'todo_q2'.tr,
    TaskPriority.q3 => 'todo_q3'.tr,
    TaskPriority.q4 => 'todo_q4'.tr,
  };
}
