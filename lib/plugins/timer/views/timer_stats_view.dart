import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/services/timer/models/timer_state.dart';
import 'package:aboutme/core/services/timer/storage/timer_storage.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/widgets/stats/sketch_stats.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/timer/models/timer_task.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/wave_fill.dart';

/// 计时器统计页（专注统计）
///
/// 视觉风格参考 Warm Minimalist Habit Companion：
/// - 顶部：小标签 + 大标题 + 本周日期胶囊
/// - Hero 卡：今日专注时长大数字 + 较昨日增量胶囊 + 底部元信息
/// - 每日专注分布：7 天胶囊柱状图，今日橙色高亮
/// - 今日专注流水：彩色圆点时间线 + 类型徽章
class TimerStatsView extends StatefulWidget {
  final List<TimerTask> tasks;

  /// 刷新令牌：变化时重新加载历史记录（宿主切到统计 tab 时递增）
  final int refreshToken;

  const TimerStatsView({super.key, required this.tasks, this.refreshToken = 0});

  @override
  State<TimerStatsView> createState() => _TimerStatsViewState();
}

class _TimerStatsViewState extends State<TimerStatsView> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  int _selectedDay = 6; // 柱状图选中的天（默认今天，即第 7 天）

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didUpdateWidget(TimerStatsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    final history = await TimerStorage.loadTimerHistory();
    if (mounted) {
      setState(() {
        _history = history;
        _loading = false;
      });
    }
  }

  // ===== 数据聚合 =====

  DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// 某天的记录列表
  List<Map<String, dynamic>> _recordsOf(DateTime day) {
    return _history.where((r) {
      final ts = DateTime.tryParse(r['timestamp'] as String? ?? '');
      return ts != null && _dayOf(ts) == day;
    }).toList();
  }

  /// 某天的专注总时长
  Duration _durationOf(DateTime day) {
    return _recordsOf(day).fold(
      Duration.zero,
      (sum, r) => sum + Duration(milliseconds: r['duration'] as int? ?? 0),
    );
  }

  /// 从今天开始往前连续有记录的天数
  int get _streakDays {
    var streak = 0;
    var day = _dayOf(DateTime.now());
    // 今天还没记录时从昨天起算，避免显示 0
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

  /// 从任务的计时器项里查类型，用于类型徽章配色。
  /// 历史记录的 timerId 是启动方传入的 id——可能是 item.id 也可能是
  /// task.id（TimerTask._startUnifiedTimer 用任务 id 注册），两者都匹配
  TimerType? _typeOf(String timerId) {
    for (final task in widget.tasks) {
      if (task.id == timerId && task.timerItems.isNotEmpty) {
        return task.timerItems.first.type;
      }
      for (final item in task.timerItems) {
        if (item.id == timerId) return item.type;
      }
    }
    return null;
  }

  // ===== 样式常量 =====

  static const _typeColors = {
    TimerType.pomodoro: Color(0xFFFA5E1E),
    TimerType.countDown: Color(0xFF2563EB),
    TimerType.countUp: Color(0xFF059669),
  };

  static const _typeLabels = {
    TimerType.pomodoro: '番茄钟',
    TimerType.countDown: '倒计时',
    TimerType.countUp: '正计时',
  };

  Color _typeColor(Map<String, dynamic> record) {
    final type = _typeOf(record['timerId'] as String? ?? '');
    return _typeColors[type] ?? Color(record['color'] as int? ?? 0xFF635D5A);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    return SuperCupertinoNavigationWrapper(
      // 收缩态标题；大标题与日期胶囊由导航栏承担（原页面内 header 移除）
      title: Text('timer_focusStats'.tr),
      largeTitle: '专注统计',
      enableSearchBar: false,
      largeTitleActions: [_buildWeekPill(theme)],
      // Tab 切换挂载时墨线描画入场（design.md §10）
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
            _buildTimelineSection(theme),
          ],
        ),
      ),
    );
  }

  // ===== 本周日期胶囊（大标题行右侧 action） =====

  Widget _buildWeekPill(ThemeData theme) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final label =
        '${weekStart.month}.${weekStart.day} - ${now.month}.${now.day}';

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            '本周 ($label)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.expand_more,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  // ===== Hero 卡：今日专注时长 =====

  Widget _buildHeroCard(ThemeData theme) {
    final now = DateTime.now();
    final today = _durationOf(_dayOf(now));
    final yesterday = _durationOf(
      _dayOf(now.subtract(const Duration(days: 1))),
    );
    final diffMin = today.inMinutes - yesterday.inMinutes;
    final todayCount = _recordsOf(_dayOf(now)).length;

    final hours = today.inHours;
    final minutes = today.inMinutes.remainder(60);

    return StatsSketchCard(
      child: Stack(
        children: [
          Column(
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
                          '今日专注时长',
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
                              '$hours',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            _unit('h', theme),
                            Text(
                              ' $minutes',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            _unit('m', theme),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 较昨日增量胶囊
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: const Color(0xFFFFDBCF),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 13,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${diffMin >= 0 ? '+' : ''}$diffMin${diffMin >= 0 ? '' : ''}m 较昨日',
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
              Divider(
                height: 1,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
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
                      '今日 $todayCount 次专注',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    _streakDays > 0 ? '连续沉浸 $_streakDays 天' : '尚未开始专注',
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
        ],
      ),
    );
  }

  Widget _unit(String u, ThemeData theme) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(
      u,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );

  // ===== 今日专注时段曲线（手绘墨线） =====

  Widget _buildTodayLineChartCard(ThemeData theme) {
    final now = DateTime.now();
    final today = _recordsOf(_dayOf(now));

    // 每 2 小时聚合一档专注分钟数（0–22 点共 12 档）
    final buckets = List.filled(12, 0.0);
    for (final r in today) {
      final ts = DateTime.tryParse(r['timestamp'] as String? ?? '');
      if (ts == null) continue;
      buckets[ts.hour ~/ 2] += (r['duration'] as int? ?? 0) / 60000.0;
    }
    // 全天无记录时保底 10 分钟，避免 maxValue 为 0 画不出线
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
                  '今日专注分布',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${now.month}月${now.day}日 · ${today.length} 次',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 手绘墨线曲线（CustomPaint 无 child，需 tight 约束撑满）
          SizedBox(
            width: double.infinity,
            height: 170,
            child: Builder(
              builder: (context) {
                final dsTheme = DSThemeBridge.resolve(context);
                return SketchLineChart(
                  values: buckets,
                  maxValue: maxBucket < 10 ? 10.0 : maxBucket,
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
                      '${i * 2}点',
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

  // ===== 每日专注分布柱状图 =====

  Widget _buildBarChartCard(ThemeData theme) {
    final days = _last7Days;
    final durations = days.map(_durationOf).toList();
    final avg = durations.fold<int>(0, (a, d) => a + d.inMinutes) / 7;

    final dayNames = ['一', '二', '三', '四', '五', '六', '日'];

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
                  '每日专注分布',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '日均 ${avg.toStringAsFixed(1)} 小时',
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
                  _tooltipTimeLabel(days[_selectedDay]),
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
                  Expanded(child: _buildChartColumn(theme, i, dayNames)),
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
    final weekday = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][day.weekday - 1];
    return isToday ? '$weekday (今日)' : weekday;
  }

  String _tooltipTimeLabel(DateTime day) {
    final duration = _durationOf(day);
    if (duration.inMinutes == 0) return '未开始专注记录';
    final count = _recordsOf(day).length;
    final label = '${duration.inHours}小时 ${duration.inMinutes.remainder(60)}分钟';
    return '$label · $count 次专注';
  }

  Widget _buildChartColumn(ThemeData theme, int i, List<String> dayNames) {
    final days = _last7Days;
    final isToday = i == 6;
    final selected = _selectedDay == i;
    final minutes = days.map(_durationOf).toList()[i].inMinutes;
    final maxMinutes = days
        .map(_durationOf)
        .map((d) => d.inMinutes)
        .fold<int>(0, (a, b) => a > b ? a : b);
    // 高度比例相对本周最长的一天；全周无记录时给最小可见高度
    final ratio = maxMinutes == 0
        ? 0.06
        : (minutes / maxMinutes).clamp(0.06, 1.0);

    final accent = theme.colorScheme.primary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedDay = i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            minutes >= 60
                ? '${(minutes / 60).toStringAsFixed(1)}h'
                : '${minutes}m',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isToday ? accent : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          // 胶囊轨道：波纹按比例自下而上填充。
          // SizedBox.expand 撑满轨道——WaveFill 的 CustomPaint 无 child，
          // loose 约束下会收缩为 0
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
                    // 波体自带 0.24–0.6 渐变透明度，传不透明色避免叠加后过淡
                    color: isToday ? accent : theme.colorScheme.onSurfaceVariant,
                    // 柱体窄，收敛波幅避免波浪吞掉整根
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
          // 选中天底部小圆点指示
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

  // ===== 今日专注流水时间线 =====

  Widget _buildTimelineSection(ThemeData theme) {
    final today = _recordsOf(_dayOf(DateTime.now()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.history_toggle_off,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '今日专注流水',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${today.length} 条记录',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (today.isEmpty)
          StatsSketchCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '今天还没有专注记录',
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
                for (var i = 0; i < today.length; i++)
                  _buildTimelineItem(theme, today[i], i < today.length - 1),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTimelineItem(
    ThemeData theme,
    Map<String, dynamic> record,
    bool showLine,
  ) {
    final color = _typeColor(record);
    final duration = Duration(milliseconds: record['duration'] as int? ?? 0);
    final start = DateTime.tryParse(record['timestamp'] as String? ?? '');
    final type = _typeOf(record['timerId'] as String? ?? '');

    // 记录时间戳为结束时刻，回推得到开始时刻
    final end = start;
    final begin = start?.subtract(duration);
    String timeLabel = '';
    if (begin != null && end != null) {
      String two(int n) => n.toString().padLeft(2, '0');
      timeLabel =
          '${two(begin.hour)}:${two(begin.minute)} - ${two(end.hour)}:${two(end.minute)}'
          ' · ${(record['completed'] as bool? ?? false) ? 'timer_completed'.tr : 'timer_pausedEarly'.tr}';
    }

    final minutes = duration.inMinutes;
    final durationLabel = minutes >= 60
        ? '+${duration.inHours}h'
        : '+${minutes}m';

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
                // 手绘圆点：任务色实底 + 墨线描边
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record['timerName'] as String? ?? '未命名',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (type != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: color.withValues(alpha: 0.15),
                          ),
                          child: Text(
                            _typeLabels[type]!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (timeLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            durationLabel,
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
