import 'package:extended_tabs/extended_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 导入所有 example widgets
import 'package:aboutme/screens/widgets_gallery/screens/half_circle_gauge_widget_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/segmented_progress_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/task_progress_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/circular_metrics_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/monthly_progress_with_dots_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/nutrition_progress_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/rounded_task_progress_widget_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/chart_icon_display_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/stress_level_monitor_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/sleep_duration_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/blood_pressure_tracker_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/activity_progress_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/weekly_steps_progress_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/route_tracking_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/weekly_dot_tracker_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/event_calendar_widget_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/daily_events_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/timeline_schedule_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/line_chart_trend_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/trend_line_chart_widget_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/smooth_line_chart_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/vertical_bar_chart_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/stacked_bar_chart_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/stacked_bar_chart_widget_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/ranked_bar_chart_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/bar_chart_stats_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/daily_bar_chart_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/weekly_bar_chart_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/donut_chart_stats_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/mini_trend_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/trend_value_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/trend_list_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/weight_trend_chart_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/screen_time_chart_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/vertical_bar_chart_widget_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/sleep_stage_chart_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/performance_bar_chart_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/portfolio_stacked_chart_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/revenue_trend_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/task_list_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/notes_list_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/color_tag_task_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/inbox_message_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/upcoming_tasks_widget_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/rounded_task_list_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/daily_todo_list_widget_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/rounded_reminders_list_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/earnings_trend_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/spending_trend_chart_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/expense_comparison_chart_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/category_stack_widget_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/wallet_balance_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/modern_rounded_balance_widget_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/monthly_bill_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/audio_waveform_widget_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/score_card_widget_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/storage_breakdown_widget_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/gradient_progress_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/period_score_gauge_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/habit_heatmap_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/health_score_ring_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/petal_radial_chart_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/semicircle_gauge_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/expense_tracker_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/total_sales_analytics_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/spending_overview_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/striped_weekly_chart_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/monthly_capsule_chart_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/stacked_folder_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/stacked_accordion_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/cute_notepad_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/scrapbook_canvas_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/illustrated_metric_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/cutout_stat_grid_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/sparkle_stat_grid_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/linked_task_flow_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/arc_rotary_wheel_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/walk_stack_card_example.dart';
import 'package:aboutme/screens/widgets_gallery/screens/marquee_button_list_card_example.dart';

/// 小组件预览项数据模型
class WidgetPreviewItem {
  final String category;
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  WidgetPreviewItem({
    required this.category,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}

/// 所有小组件预览页面 - 使用垂直标签页展示
class AllWidgetsPreviewPage extends StatefulWidget {
  final List<WidgetPreviewItem> widgetItems;

  const AllWidgetsPreviewPage({super.key, required this.widgetItems});

  @override
  State<AllWidgetsPreviewPage> createState() => _AllWidgetsPreviewPageState();
}

class _AllWidgetsPreviewPageState extends State<AllWidgetsPreviewPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedCategory;

  /// 所有可用分类
  List<String> get _allCategories {
    final categories = widget.widgetItems.map((e) => e.category).toSet().toList();
    categories.sort();
    return categories;
  }

  /// 根据选择过滤后的小组件列表
  List<WidgetPreviewItem> get _filteredWidgetItems {
    if (_selectedCategory == null) {
      return widget.widgetItems;
    }
    return widget.widgetItems.where((item) => item.category == _selectedCategory).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.widgetItems.length,
      vsync: this,
    );
    // 默认选中第一个
    if (widget.widgetItems.isNotEmpty) {
      _tabController.animateTo(0);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => _showCategoryDialog(context),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selectedCategory ?? '全部',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
        actions: [
          if (_selectedCategory != null)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedCategory = null;
                  _updateTabController();
                });
              },
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('清除'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 8),
        ],
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // 顶部水平 TabBar - 可滚动
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: ExtendedTabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorSize: TabBarIndicatorSize.tab,
              labelPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              tabs:
                  _filteredWidgetItems.map((item) {
                    return Tab(
                      icon: Icon(item.icon, size: 18),
                      text: item.title,
                    );
                  }).toList(),
            ),
          ),
          // 下方 TabBarView 展示预览
          Expanded(
            child: ExtendedTabBarView(
              controller: _tabController,
              children:
                  _filteredWidgetItems.map((item) {
                    return _buildWidgetPreviewContent(item);
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示分类选择对话框
  void _showCategoryDialog(BuildContext context) {
    final categories = _allCategories;
    final filteredCount = Map.fromEntries(
      categories.map((c) => MapEntry(
            c,
            widget.widgetItems.where((item) => item.category == c).length,
          )),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择分类'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 全部选项
              ListTile(
                leading: Radio<String?>(
                  value: null,
                  groupValue: _selectedCategory,
                  onChanged: (value) {
                    setState(() => _selectedCategory = value);
                    Navigator.pop(context);
                    _updateTabController();
                  },
                ),
                title: Row(
                  children: [
                    const Text('全部'),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('${widget.widgetItems.length}'),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...categories.map((category) {
                return ListTile(
                  leading: Radio<String?>(
                    value: category,
                    groupValue: _selectedCategory,
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                      Navigator.pop(context);
                      _updateTabController();
                    },
                  ),
                  title: Row(
                    children: [
                      Text(category),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text('${filteredCount[category]}'),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                ),
                onTap: () {
                  setState(() => _selectedCategory = category);
                  Navigator.pop(context);
                  _updateTabController();
                },
              );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 更新 TabController 的长度
  void _updateTabController() {
    final filteredLength = _filteredWidgetItems.length;
    if (filteredLength != _tabController.length) {
      _tabController.dispose();
      _tabController = TabController(
        length: filteredLength,
        vsync: this,
      );
      if (filteredLength > 0) {
        _tabController.animateTo(0);
      }
    }
  }

  /// 构建单个小组件的预览内容
  Widget _buildWidgetPreviewContent(WidgetPreviewItem item) {
    // 获取对应的 Widget
    final widget = _WidgetRegistry.getWidget(item.route);

    return Column(
      children: [
        // 顶部标题栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      item.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: '复制类名',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: item.subtitle));
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.category,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Widget 内容区域
        Expanded(
          child:
              widget ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '未找到组件',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '路由: ${item.route}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ],
    );
  }
}

/// Widget 注册表 - 从路由路径获取对应的 Widget
class _WidgetRegistry {
  static final Map<String, Widget Function()> _widgets = {
    // 进度类
    '/widgets_gallery/half_circle_gauge_widget':
        () => const HalfCircleGaugeWidgetExample(),
    '/widgets_gallery/segmented_progress_card':
        () => const SegmentedProgressCardExample(),
    '/widgets_gallery/task_progress_card':
        () => const TaskProgressCardExample(),
    '/widgets_gallery/circular_metrics_card':
        () => const CircularMetricsCardExample(),
    '/widgets_gallery/monthly_progress_with_dots_card':
        () => const MonthlyProgressWithDotsCardExample(),
    '/widgets_gallery/nutrition_progress_card':
        () => const NutritionProgressCardExample(),
    '/widgets_gallery/rounded_task_progress_widget':
        () => const RoundedTaskProgressWidgetExample(),
    // 追踪类
    '/widgets_gallery/mood_chart_card':
        () => const ChartIconDisplayCardExample(),
    '/widgets_gallery/stress_level_monitor':
        () => const StressLevelMonitorExample(),
    '/widgets_gallery/sleep_duration_card':
        () => const SleepDurationCardExample(),
    '/widgets_gallery/blood_pressure_tracker':
        () => const BloodPressureTrackerExample(),
    '/widgets_gallery/activity_progress_card':
        () => CardDotProgressDisplayExample(),
    '/widgets_gallery/weekly_steps_progress_card':
        () => const WeeklyStepsProgressCardExample(),
    '/widgets_gallery/route_tracking_card':
        () => const RouteTrackingCardExample(),
    '/widgets_gallery/weekly_dot_tracker_card':
        () => const WeeklyDotTrackerCardExample(),
    // 日历类
    '/widgets_gallery/event_calendar_widget':
        () => const EventCalendarWidgetExample(),
    '/widgets_gallery/daily_events_card': () => const DailyEventsCardExample(),
    '/widgets_gallery/timeline_schedule_card':
        () => const TimelineScheduleCardExample(),
    // 图表类
    '/widgets_gallery/line_chart_trend_card':
        () => const LineChartTrendCardExample(),
    '/widgets_gallery/trend_line_chart_widget':
        () => const TrendLineChartWidgetExample(),
    '/widgets_gallery/smooth_line_chart_card':
        () => const SmoothLineChartCardExample(),
    '/widgets_gallery/vertical_bar_chart_card':
        () => const VerticalBarChartCardExample(),
    '/widgets_gallery/stacked_bar_chart_card':
        () => const StackedBarChartCardExample(),
    '/widgets_gallery/stacked_bar_chart_widget':
        () => const StackedBarChartWidgetExample(),
    '/widgets_gallery/ranked_bar_chart_card':
        () => const RankedBarChartCardExample(),
    '/widgets_gallery/bar_chart_stats_card':
        () => const BarChartStatsCardExample(),
    '/widgets_gallery/daily_bar_chart_card':
        () => const DailyBarChartCardExample(),
    '/widgets_gallery/weekly_bar_chart_card':
        () => const WeeklyBarChartCardExample(),
    '/widgets_gallery/donut_chart_stats_card':
        () => const DonutChartStatsCardExample(),
    '/widgets_gallery/mini_trend_card': () => const MiniTrendCardExample(),
    '/widgets_gallery/trend_value_card': () => const TrendValueCardExample(),
    '/widgets_gallery/trend_list_card': () => const TrendListCardExample(),
    '/widgets_gallery/weight_trend_chart':
        () => const WeightTrendChartExample(),
    '/widgets_gallery/screen_time_chart': () => const ScreenTimeChartExample(),
    '/widgets_gallery/vertical_bar_chart_widget':
        () => const VerticalBarChartExample(),
    '/widgets_gallery/sleep_stage_chart': () => const SleepStageChartExample(),
    '/widgets_gallery/performance_bar_chart':
        () => const PerformanceBarChartExample(),
    '/widgets_gallery/portfolio_stacked_chart':
        () => const PortfolioStackedChartExample(),
    '/widgets_gallery/revenue_trend_card':
        () => const RevenueTrendCardExample(),
    // 内容类
    '/widgets_gallery/task_list_card': () => const TaskListCardExample(),
    '/widgets_gallery/notes_list_card': () => const NotesListCardExample(),
    '/widgets_gallery/color_tag_task_card':
        () => const ColorTagTaskCardExample(),
    '/widgets_gallery/inbox_message_card':
        () => const InboxMessageCardExample(),
    '/widgets_gallery/upcoming_tasks_widget':
        () => const UpcomingTasksWidgetExample(),
    '/widgets_gallery/rounded_task_list_card':
        () => const RoundedTaskListCardExample(),
    '/widgets_gallery/daily_todo_list_widget':
        () => const DailyTodoListWidgetExample(),
    '/widgets_gallery/rounded_reminders_list':
        () => const RoundedRemindersListExample(),
    // 财务类
    '/widgets_gallery/earnings_trend_card':
        () => const EarningsTrendCardExample(),
    '/widgets_gallery/spending_trend_chart':
        () => const SpendingTrendChartExample(),
    '/widgets_gallery/expense_comparison_chart':
        () => const ExpenseComparisonChartExample(),
    '/widgets_gallery/category_stack_widget':
        () => const CategoryStackWidgetExample(),
    '/widgets_gallery/wallet_balance_card':
        () => const WalletBalanceCardExample(),
    '/widgets_gallery/modern_rounded_balance_widget':
        () => const ModernRoundedBalanceWidgetExample(),
    '/widgets_gallery/monthly_bill_card': () => const MonthlyBillCardExample(),
    // 媒体类
    '/widgets_gallery/audio_waveform_widget':
        () => const AudioWaveformWidgetExample(),
    // 工具类
    '/widgets_gallery/score_card_widget': () => const ScoreCardWidgetExample(),
    '/widgets_gallery/storage_breakdown_widget':
        () => const StorageBreakdownWidgetExample(),
    // 创意类
    '/widgets_gallery/gradient_progress_card':
        () => const GradientProgressCardExample(),
    '/widgets_gallery/period_score_gauge_card':
        () => const PeriodScoreGaugeCardExample(),
    '/widgets_gallery/habit_heatmap_card':
        () => const HabitHeatmapCardExample(),
    '/widgets_gallery/health_score_ring_card':
        () => const HealthScoreRingCardExample(),
    '/widgets_gallery/petal_radial_chart_card':
        () => const PetalRadialChartCardExample(),
    '/widgets_gallery/semicircle_gauge_card':
        () => const SemicircleGaugeCardExample(),
    '/widgets_gallery/expense_tracker_card':
        () => const ExpenseTrackerCardExample(),
    '/widgets_gallery/total_sales_analytics_card':
        () => const TotalSalesAnalyticsCardExample(),
    '/widgets_gallery/spending_overview_card':
        () => const SpendingOverviewCardExample(),
    '/widgets_gallery/striped_weekly_chart_card':
        () => const StripedWeeklyChartCardExample(),
    '/widgets_gallery/monthly_capsule_chart_card':
        () => const MonthlyCapsuleChartCardExample(),
    '/widgets_gallery/stacked_folder_card':
        () => const StackedFolderCardExample(),
    '/widgets_gallery/stacked_accordion_card':
        () => const StackedAccordionCardExample(),
    '/widgets_gallery/cute_notepad_card': () => const CuteNotepadCardExample(),
    '/widgets_gallery/scrapbook_canvas_card':
        () => const ScrapbookCanvasCardExample(),
    '/widgets_gallery/illustrated_metric_card':
        () => const IllustratedMetricCardExample(),
    '/widgets_gallery/cutout_stat_grid_card':
        () => const CutoutStatGridCardExample(),
    '/widgets_gallery/sparkle_stat_grid_card':
        () => const SparkleStatGridCardExample(),
    '/widgets_gallery/linked_task_flow_card':
        () => LinkedTaskFlowCardExample(),
    '/widgets_gallery/arc_rotary_wheel_card':
        () => const ArcRotaryWheelCardExample(),
    '/widgets_gallery/walk_stack_card': () => const WalkStackCardExample(),
    '/widgets_gallery/marquee_button_list_card':
        () => const MarqueeButtonListCardExample(),
  };

  static Widget? getWidget(String route) {
    final builder = _widgets[route];
    return builder?.call();
  }
}
