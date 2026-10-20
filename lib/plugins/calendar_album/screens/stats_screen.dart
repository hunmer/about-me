import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/calendar_album/controllers/calendar_controller.dart';
import 'package:aboutme/plugins/calendar_album/controllers/tag_controller.dart';
import 'package:aboutme/plugins/calendar_album/models/calendar_entry.dart';
import 'package:aboutme/widgets/stats/sketch_stats.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/wave_fill.dart';

/// 日历相册统计页（视觉风格同 todo 统计页）
///
/// - Hero 卡：今日日记数 + 较昨日增量胶囊 + 总日记/照片/标签 + 连续记录天数
/// - 今日记录分布：0–22 点手绘墨线曲线
/// - 每日记录分布：7 天胶囊柱状图，今日高亮
/// - 标签分布：日记标签计数徽章
class CalendarAlbumStatsView extends StatefulWidget {
  final CalendarController calendarController;
  final TagController tagController;

  const CalendarAlbumStatsView({
    super.key,
    required this.calendarController,
    required this.tagController,
  });

  @override
  State<CalendarAlbumStatsView> createState() => _CalendarAlbumStatsViewState();
}

class _CalendarAlbumStatsViewState extends State<CalendarAlbumStatsView> {
  int _selectedDay = 6; // 柱状图选中的天（默认今天，即第 7 天）

  @override
  void initState() {
    super.initState();
    // tab 懒加载挂载即上报路由上下文，供"询问当前上下文"识别
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateRouteContext());
  }

  /// 更新路由上下文，使"询问当前上下文"功能能获取到统计概况
  void _updateRouteContext() {
    if (!mounted) return;
    RouteHistoryManager.updateCurrentContext(
      pageId: '/calendar_album_stats',
      title: 'calendar_album_statsTab'.tr,
      params: {
        'entryCount': _allEntries.length,
        'streakDays': _streakDays,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SuperCupertinoNavigationWrapper(
      title: Text('calendar_album_statsTab'.tr),
      largeTitle: 'calendar_album_statsTab'.tr,
      enableSearchBar: false,
      // Tab 切换挂载时墨线描画入场
      body: WiredDraw(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            widget.calendarController,
            widget.tagController,
          ]),
          builder: (context, _) {
            if (_allEntries.isEmpty) {
              return Center(
                child: DSEmptyState(
                  icon: DsIconKind.image,
                  title: 'calendar_album_statsNoEntries'.tr,
                  message: 'calendar_album_tags_empty_hint'.tr,
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
              children: [
                _buildHeroCard(theme),
                const SizedBox(height: 16),
                _buildTodayLineChartCard(theme),
                const SizedBox(height: 16),
                _buildBarChartCard(theme),
                const SizedBox(height: 16),
                _buildTagCard(theme),
                const SizedBox(height: 16),
                _buildMoodCard(theme),
                const SizedBox(height: 16),
                _buildWeatherCard(theme),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===== 数据聚合 =====

  List<CalendarEntry> get _allEntries {
    final all = <CalendarEntry>[];
    widget.calendarController.entries.forEach((_, entries) {
      all.addAll(entries);
    });
    return all;
  }

  DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  int _countOf(DateTime day) =>
      widget.calendarController.getEntriesForDate(day).length;

  /// 从今天开始往前连续有日记的天数
  int get _streakDays {
    var streak = 0;
    var day = _dayOf(DateTime.now());
    if (_countOf(day) == 0) {
      day = day.subtract(const Duration(days: 1));
    }
    while (_countOf(day) > 0) {
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

  // ===== Hero 卡：今日日记数 =====

  Widget _buildHeroCard(ThemeData theme) {
    final now = DateTime.now();
    final today = _countOf(_dayOf(now));
    final yesterday = _countOf(_dayOf(now.subtract(const Duration(days: 1))));
    final diff = today - yesterday;
    final all = _allEntries;
    final photoCount = widget.calendarController.getAllImages().length;
    final tagCount = widget.tagController.tags.length;

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
                      'calendar_album_statsTodayEntries'.tr,
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
                            'calendar_album_statsUnit'.tr,
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
                      'calendar_album_statsVsYesterday'.trParams({
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
                  'calendar_album_statsSummary'.trParams({
                    'total': '${all.length}',
                    'photos': '$photoCount',
                    'tags': '$tagCount',
                  }),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                _streakDays > 0
                    ? 'calendar_album_statsStreak'.trParams({
                        'count': '$_streakDays',
                      })
                    : 'calendar_album_statsNoEntries'.tr,
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

  Widget _buildTodayLineChartCard(ThemeData theme) {
    final now = DateTime.now();
    final today = widget.calendarController.getEntriesForDate(_dayOf(now));

    // 每 2 小时聚合一档记录数（0–22 点共 12 档）
    final buckets = List.filled(12, 0.0);
    for (final e in today) {
      buckets[e.createdAt.hour ~/ 2] += 1;
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
                  'calendar_album_statsTodayChart'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${statsDateLabel(now)} · ${today.length} ${'calendar_album_statsUnit'.tr}',
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

  Widget _buildBarChartCard(ThemeData theme) {
    final days = _last7Days;
    final counts = days.map(_countOf).toList();
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
                  'calendar_album_statsDailyChart'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                'calendar_album_statsDailyAvg'.trParams({
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
                  'calendar_album_statsCountLabel'.trParams({
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
    return isToday
        ? '$label (${'calendar_album_statsToday'.tr})'
        : label;
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

  // ===== 心情/天气分布 =====

  Widget _buildMoodCard(ThemeData theme) {
    return _buildEnumDistCard(
      theme,
      title: 'calendar_album_statsMoodChart'.tr,
      icon: Icons.mood,
      labelOf: (v) => _optionLabel('calendar_album_mood_${v.toLowerCase()}', v),
      valueOf: (e) => e.mood,
    );
  }

  Widget _buildWeatherCard(ThemeData theme) {
    return _buildEnumDistCard(
      theme,
      title: 'calendar_album_statsWeatherChart'.tr,
      icon: Icons.cloud_outlined,
      labelOf: (v) =>
          _optionLabel('calendar_album_weather_${v.toLowerCase()}', v),
      valueOf: (e) => e.weather,
    );
  }

  /// 翻译 key 缺失时回退原始值（日记里可能存自定义心情/天气）
  String _optionLabel(String key, String raw) {
    final t = key.tr;
    return t == key ? raw : t;
  }

  Widget _buildEnumDistCard(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required String Function(String) labelOf,
    required String? Function(CalendarEntry) valueOf,
  }) {
    final counts = <String, int>{};
    for (final e in _allEntries) {
      final v = valueOf(e);
      if (v == null || v.isEmpty) continue;
      counts[v] = (counts[v] ?? 0) + 1;
    }
    if (counts.isEmpty) return const SizedBox.shrink();

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = entries.first.value;

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
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
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
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == entries.length - 1 ? 0 : 10,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      labelOf(entries[i].key),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (entries[i].value / maxCount).clamp(
                          0.04,
                          1.0,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: palette[i % palette.length].withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entries[i].value}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette[i % palette.length],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ===== 标签分布 =====

  Widget _buildTagCard(ThemeData theme) {
    final counts = <String, int>{};
    for (final e in _allEntries) {
      for (final tag in e.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
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
                  'calendar_album_statsTagChart'.tr,
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
