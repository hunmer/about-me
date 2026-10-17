import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/plugins/checkin/models/checkin_item.dart';
import 'package:aboutme/widgets/stats/sketch_stats.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'widgets/daily_checkin_chart.dart';
import 'widgets/checkin_streak_ranking.dart';
import 'widgets/checkin_group_pie_chart.dart';

/// 打卡统计页（统一手绘统计风格）
///
/// - 范围切换胶囊：本周 / 本月（趋势图随范围切换周/月视图）
/// - Hero 卡：范围内总打卡次数 + 完成项目占比
/// - 打卡趋势 / 连续打卡排行 / 分组占比：沿用 checkin 自有图表，嵌入统计纸卡
class CheckinStatsScreen extends StatefulWidget {
  final List<CheckinItem> checkinItems;

  const CheckinStatsScreen({super.key, required this.checkinItems});

  @override
  State<CheckinStatsScreen> createState() => _CheckinStatsScreenState();
}

enum _StatsRange { week, month }

class _CheckinStatsScreenState extends State<CheckinStatsScreen> {
  _StatsRange _range = _StatsRange.week;
  int _totalCheckins = 0;
  int _completedItems = 0;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    // 初始化时设置路由上下文
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateRouteContext();
    });
  }

  @override
  void didUpdateWidget(CheckinStatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checkinItems != widget.checkinItems ||
        oldWidget.hashCode != widget.hashCode) {
      _loadStats();
    }
  }

  /// 更新路由上下文，使"询问当前上下文"功能知道用户在查看统计界面
  void _updateRouteContext() {
    RouteHistoryManager.updateCurrentContext(
      pageId: "/checkin_stats",
      title: '打卡统计',
      params: {},
    );
  }

  void _loadStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime start;
    switch (_range) {
      case _StatsRange.week:
        start = today.subtract(Duration(days: now.weekday - 1));
      case _StatsRange.month:
        start = DateTime(now.year, now.month, 1);
    }

    // 计算范围内的打卡总数与有记录的项目数
    int totalCheckins = 0;
    int completedItems = 0;
    for (var item in widget.checkinItems) {
      var hasCheckin = false;
      for (var date = start;
          !date.isAfter(today);
          date = date.add(const Duration(days: 1))) {
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final records = item.checkInRecords[dateStr];
        if (records != null && records.isNotEmpty) {
          totalCheckins += records.length;
          hasCheckin = true;
        }
      }
      if (hasCheckin) completedItems++;
    }

    if (mounted) {
      setState(() {
        _startDate = start;
        _endDate = today;
        _totalCheckins = totalCheckins;
        _completedItems = completedItems;
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
      title: Text('checkin_statsTitle'.tr),
      largeTitle: 'checkin_statsTitle'.tr,
      enableSearchBar: false,
      largeTitleActions: [_buildRangePill(theme)],
      // Tab 切换挂载时墨线描画入场
      body: WiredDraw(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
          children: [
            _buildHeroCard(theme),
            const SizedBox(height: 16),
            _buildTrendCard(theme),
            const SizedBox(height: 16),
            _buildRankingCard(theme),
            const SizedBox(height: 16),
            _buildPieCard(theme),
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
          seg(_StatsRange.week, 'checkin_statsWeek'.tr),
          seg(_StatsRange.month, 'checkin_statsMonth'.tr),
        ],
      ),
    );
  }

  // ===== Hero 卡：范围内总打卡 =====

  Widget _buildHeroCard(ThemeData theme) {
    final total = widget.checkinItems.length;
    final rate = total > 0 ? _completedItems / total * 100 : 0.0;

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
                      'checkin_statsTotalCheckins'.tr,
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
                          '$_totalCheckins',
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
                            'checkin_statsUnit'.tr,
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
              // 完成率胶囊
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFFFDBCF),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.task_alt,
                      size: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${rate.toStringAsFixed(0)}%',
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
                  'checkin_statsCompletedItems'.trParams({
                    'completed': '$_completedItems',
                    'total': '$total',
                  }),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '${statsDateLabel(_startDate)} - ${statsDateLabel(_endDate)}',
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

  // ===== 打卡趋势 =====

  Widget _buildTrendCard(ThemeData theme) {
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
                  'checkin_checkinTrendTitle'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: DailyCheckinChart(
              // 月范围切月视图，周范围切周视图
              isMonthly: _range == _StatsRange.month,
              checkinItems: widget.checkinItems,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 连续打卡排行 =====

  Widget _buildRankingCard(ThemeData theme) {
    return StatsSketchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'checkin_checkinRankingTitle'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CheckinStreakRanking(checkinItems: widget.checkinItems),
        ],
      ),
    );
  }

  // ===== 分组占比 =====

  Widget _buildPieCard(ThemeData theme) {
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
                  'checkin_checkinGroupPieTitle'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: CheckinGroupPieChart(checkinItems: widget.checkinItems),
          ),
        ],
      ),
    );
  }
}
