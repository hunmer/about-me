// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'widgets/circular_progress_card.dart';
import 'widgets/card_dot_progress_display.dart';
import 'widgets/half_gauge_card.dart';
import 'widgets/task_progress_card.dart';
import 'widgets/task_list_card.dart';
import 'widgets/audio_waveform_card.dart';
import 'widgets/line_chart_trend_card.dart';
import 'widgets/earnings_trend_card.dart';
import 'widgets/card_bar_chart_monitor.dart';
import 'widgets/card_bubble_chart_display.dart';
import 'widgets/card_trend_line_chart.dart';
import 'widgets/image_display_card.dart';
import 'widgets/segmented_progress_card.dart';
import 'widgets/profile_card_card.dart';
import 'package:aboutme/widgets/common/inbox_message_card.dart';
import 'package:aboutme/widgets/common/rounded_task_list_card.dart';
import 'package:aboutme/widgets/common/rounded_reminders_list_card.dart';
import 'package:aboutme/widgets/common/timer_card_widget.dart';
import 'widgets/monthly_progress_with_dots_card.dart';
import 'widgets/multi_metric_progress_card.dart';
import 'widgets/circular_metrics_card.dart';
import 'widgets/smooth_line_chart_card.dart';
import 'widgets/goods_item_selector.dart';
import 'widgets/vertical_bar_chart_card.dart';
import 'widgets/revenue_trend_card.dart';
import 'widgets/dual_slider_widget.dart';
import 'widgets/daily_todo_list_widget.dart';
import 'widgets/upcoming_tasks_widget.dart';
import 'widgets/mini_trend_card.dart';
import 'widgets/account_balance_card.dart';
import 'widgets/modern_rounded_spending_widget.dart';
import 'widgets/wallet_balance_card.dart';
import 'widgets/score_card_widget.dart';
import 'widgets/trend_value_card.dart';
import 'widgets/trend_list_card.dart';
import 'widgets/modern_flip_counter_card.dart';
import 'widgets/chart_icon_display_card.dart';
import 'widgets/daily_events_card.dart';
import 'widgets/daily_reflection_card.dart';
import 'widgets/icon_circular_progress_card.dart';
import 'widgets/monthly_bill_card.dart';
import 'widgets/color_tag_task_card.dart';
import 'widgets/spending_trend_chart.dart';
import 'widgets/modern_rounded_bar_icon_card.dart';
import 'widgets/event_calendar_widget.dart';
import 'widgets/rounded_task_progress_widget.dart';
import 'widgets/daily_bar_chart_card.dart';
import 'widgets/split_column_progress_bar_card.dart';
import 'widgets/portfolio_stacked_chart.dart';
import 'widgets/activity_rings_card.dart';
import 'widgets/category_stack_widget.dart';
import 'widgets/performance_bar_chart.dart';
import 'widgets/ranked_bar_chart_card.dart';
import 'widgets/rental_preview_card.dart';
import 'widgets/rounded_property_card.dart';
import 'widgets/task_list_stat_card.dart';
import 'widgets/task_progress_list.dart';
import 'widgets/dark_bar_chart_card.dart';
import 'widgets/card_emoji_icon_display.dart';
import 'widgets/monthly_dot_tracker_card.dart';
import 'widgets/checkin_item_card.dart';
import 'widgets/activity_heatmap_card.dart';
import 'widgets/activity_today_pie_chart_card.dart';
import 'widgets/timeline_schedule_card.dart';
import 'widgets/trend_line_chart_card_wrapper.dart';
import 'widgets/bar_chart_stats_card.dart';
import 'widgets/expense_comparison_chart_card.dart';
import 'widgets/weekly_diary_widget.dart';
import 'package:aboutme/widgets/common/dual_value_tracker_card.dart';
import 'package:aboutme/widgets/common/modern_rounded_balance_card.dart';
import 'package:aboutme/plugins/activity/home_widgets/widgets/activity_last_activity.dart';
import 'widgets/folder_notes_card.dart';
import 'widgets/habit_heatmap_card.dart';
import 'widgets/points_goal_card.dart';
import 'widgets/store_product_selector_card.dart';
import 'widgets/store_user_item_selector_card.dart';
import 'widgets/notebook_list_card.dart';
import 'widgets/node_stats_card.dart';
import 'widgets/todo_nodes_list.dart';
import 'widgets/contact_card.dart';
import 'widgets/recent_contact_card.dart';
import 'package:aboutme/widgets/common/habit_card.dart';
import 'package:aboutme/widgets/common/memorial_day_card.dart';
import 'widgets/health_score_ring_card.dart';
import 'widgets/petal_radial_chart_card.dart';
import 'widgets/stacked_folder_card.dart';
import 'widgets/stacked_accordion_card.dart';
import 'widgets/cute_notepad_card.dart';
import 'widgets/scrapbook_canvas_card/scrapbook_canvas_card.dart';
import 'widgets/arc_rotary_wheel_card.dart';
import 'widgets/walk_stack_card.dart';
import 'widgets/illustrated_metric_card.dart';
import 'widgets/cutout_stat_grid_card.dart';
import 'widgets/gradient_progress_card.dart';
import 'widgets/striped_weekly_chart_card.dart';

/// 公共小组件 ID 枚举
enum CommonWidgetId {
  circularProgressCard,
  iconCircularProgressCard,
  colorTagTaskCard,
  activityProgressCard,
  halfGaugeCard,
  taskProgressCard,
  taskListCard,
  audioWaveformCard,
  segmentedProgressCard,
  monthlyProgressDotsCard,
  multiMetricProgressCard,
  circularMetricsCard,
  smoothLineChartCard,
  lineChartTrendCard,
  verticalBarChartCard,
  inboxMessageCard,
  roundedTaskListCard,
  roundedRemindersList,
  dualSliderCard,
  earningsTrendCard,
  timerCard,
  revenueTrendCard,
  stressLevelMonitor,
  dailyTodoListCard,
  upcomingTasksWidget,
  profileCardCard,
  sleepStageChartCard,
  imageDisplayCard,
  weightTrendChart,
  miniTrendCard,
  accountBalanceCard,
  modernRoundedSpendingWidget,
  walletBalanceCard,
  scoreCardWidget,
  trendValueCard,
  trendListCard,
  moodChartCard,
  dailyEventsCard,
  modernEgfrHealthWidget,
  dailyReflectionCard,
  monthlyBillCard,
  spendingTrendChart,
  modernRoundedMoodWidget,
  eventCalendarWidget,
  roundedTaskProgressWidget,
  dailyBarChartCard,
  nutritionProgressCard,
  portfolioStackedChart,
  activityRingsCard,
  categoryStackWidget,
  performanceBarChart,
  rankedBarChartCard,
  rentalPreviewCard,
  roundedPropertyCard,
  taskListStatCard,
  taskProgressList,
  sleepDurationCard,
  moodTrackerCard,
  monthlyDotTrackerCard,
  checkinItemCard,
  activityHeatmapCard,
  activityTodayPieChartCard,
  timelineScheduleCard,
  bloodPressureTracker,
  trendLineChartCard,
  modernRoundedBalanceCard,
  barChartStatsCard,
  expenseComparisonChart,
  weeklyDiaryWidget,
  activityLastActivity,
  folderNotesCard,
  goodsItemSelector,
  habitHeatmapCard,
  pointsGoalCard,
  storeProductSelector,
  storeUserItemSelector,
  notebookListCard,
  nodeStatsCard,
  todoNodesList,
  recentContactCard,
  contactCard,
  habitCard,
  memorialDayCard,
  healthScoreRingCard,
  petalRadialChartCard,
  stackedFolderCard,
  stackedAccordionCard,
  cuteNotepadCard,
  scrapbookCanvasCard,
  arcRotaryWheelCard,
  walkStackCard,
  illustratedMetricCard,
  cutoutStatGridCard,
  gradientProgressCard,
  stripedWeeklyChartCard,
}

/// 公共小组件元数据
class CommonWidgetMetadata {
  final CommonWidgetId id;
  final String name;
  final String description;
  final IconData icon;
  final HomeWidgetSize defaultSize;
  final List<HomeWidgetSize> supportedSizes;

  const CommonWidgetMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.defaultSize,
    required this.supportedSizes,
  });
}

/// 公共小组件注册表
class CommonWidgetsRegistry {
  static final Map<CommonWidgetId, CommonWidgetMetadata> metadata = {
    CommonWidgetId.circularProgressCard: CommonWidgetMetadata(
      id: CommonWidgetId.circularProgressCard,
      name: '圆形进度卡片',
      description: '显示百分比进度，带圆形进度环',
      icon: Icons.circle_outlined,
      defaultSize: Large3Size(),
      supportedSizes: [const MediumSize(), const LargeSize()],
    ),
    CommonWidgetId.iconCircularProgressCard: CommonWidgetMetadata(
      id: CommonWidgetId.iconCircularProgressCard,
      name: '图标圆形进度卡片',
      description: '显示带圆形进度条的卡片，支持图标、通知点、标题和副标题',
      icon: Icons.control_point_duplicate,
      defaultSize: Large3Size(),
      supportedSizes: [const MediumSize(), const LargeSize()],
    ),
    CommonWidgetId.colorTagTaskCard: CommonWidgetMetadata(
      id: CommonWidgetId.colorTagTaskCard,
      name: '彩色标签任务列表卡片',
      description: '显示带彩色标签的任务列表，支持翻转计数动画和入场效果',
      icon: Icons.label,
      defaultSize: Large3Size(),
      supportedSizes: const [LargeSize()],
    ),
    CommonWidgetId.activityProgressCard: CommonWidgetMetadata(
      id: CommonWidgetId.activityProgressCard,
      name: '活动进度卡片',
      description: '显示活动数值、单位、活动数和进度点',
      icon: Icons.directions_run,
      defaultSize: Large3Size(),
      supportedSizes: [const MediumSize(), const LargeSize()],
    ),
    CommonWidgetId.halfGaugeCard: const CommonWidgetMetadata(
      id: CommonWidgetId.halfGaugeCard,
      name: '半圆形仪表盘',
      description: '显示预算/余额的半圆形仪表盘',
      icon: Icons.speed,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.taskProgressCard: const CommonWidgetMetadata(
      id: CommonWidgetId.taskProgressCard,
      name: '任务进度卡片',
      description: '显示任务进度、待办列表',
      icon: Icons.task_alt,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.taskListCard: CommonWidgetMetadata(
      id: CommonWidgetId.taskListCard,
      name: '任务列表卡片',
      description: '显示任务列表和计数信息',
      icon: Icons.format_list_bulleted,
      defaultSize: Large3Size(),
      supportedSizes: const [LargeSize()],
    ),
    CommonWidgetId.audioWaveformCard: const CommonWidgetMetadata(
      id: CommonWidgetId.audioWaveformCard,
      name: '音频波形卡片',
      description: '显示音频录制信息、时长和波形可视化',
      icon: Icons.graphic_eq,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.segmentedProgressCard: const CommonWidgetMetadata(
      id: CommonWidgetId.segmentedProgressCard,
      name: '分段进度条卡片',
      description: '多类别分段统计卡片',
      icon: Icons.bar_chart,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.monthlyProgressDotsCard: const CommonWidgetMetadata(
      id: CommonWidgetId.monthlyProgressDotsCard,
      name: '月度进度圆点卡片',
      description: '圆点矩阵月度进度卡片',
      icon: Icons.calendar_month,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.multiMetricProgressCard: const CommonWidgetMetadata(
      id: CommonWidgetId.multiMetricProgressCard,
      name: '多指标进度卡片',
      description: '多指标进度展示卡片，带圆形进度环',
      icon: Icons.dashboard,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.circularMetricsCard: const CommonWidgetMetadata(
      id: CommonWidgetId.circularMetricsCard,
      name: '环形指标卡片',
      description: '显示多个环形指标，带进度环和图标',
      icon: Icons.donut_large,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.smoothLineChartCard: const CommonWidgetMetadata(
      id: CommonWidgetId.smoothLineChartCard,
      name: '平滑折线图卡片',
      description: '带渐变填充的平滑折线图卡片',
      icon: Icons.show_chart,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.verticalBarChartCard: const CommonWidgetMetadata(
      id: CommonWidgetId.verticalBarChartCard,
      name: '垂直柱状图卡片',
      description: '双数据系列垂直柱状图展示卡片',
      icon: Icons.bar_chart,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.lineChartTrendCard: const CommonWidgetMetadata(
      id: CommonWidgetId.lineChartTrendCard,
      name: '折线图趋势卡片',
      description: '折线图趋势统计卡片',
      icon: Icons.show_chart,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.inboxMessageCard: const CommonWidgetMetadata(
      id: CommonWidgetId.inboxMessageCard,
      name: '收件箱消息卡片',
      description: '显示消息列表和计数信息',
      icon: Icons.inbox,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.roundedTaskListCard: const CommonWidgetMetadata(
      id: CommonWidgetId.roundedTaskListCard,
      name: '圆角任务列表卡片',
      description: '显示任务列表和日期信息',
      icon: Icons.list_alt,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.roundedRemindersList: const CommonWidgetMetadata(
      id: CommonWidgetId.roundedRemindersList,
      name: '圆角提醒事项列表',
      description: '显示提醒事项列表和计数',
      icon: Icons.notification_important,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.dualSliderCard: const CommonWidgetMetadata(
      id: CommonWidgetId.dualSliderCard,
      name: '双滑块小组件',
      description: '通用双滑块数值显示组件，支持自定义标签和进度',
      icon: Icons.access_time,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.earningsTrendCard: const CommonWidgetMetadata(
      id: CommonWidgetId.earningsTrendCard,
      name: '收益趋势卡片',
      description: '显示收益趋势、货币数值、百分比变化和平滑折线图',
      icon: Icons.trending_up,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.revenueTrendCard: const CommonWidgetMetadata(
      id: CommonWidgetId.revenueTrendCard,
      name: '收入趋势卡片',
      description: '显示收入趋势、货币数值、百分比变化和曲线图，支持日期标签和高亮点',
      icon: Icons.trending_up,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.stressLevelMonitor: const CommonWidgetMetadata(
      id: CommonWidgetId.stressLevelMonitor,
      name: '压力水平监测',
      description: '显示当前压力分数、状态描述和每周7天的柱状图数据，支持动画效果',
      icon: Icons.psychology_outlined,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.dailyTodoListCard: const CommonWidgetMetadata(
      id: CommonWidgetId.dailyTodoListCard,
      name: '每日待办事项卡片',
      description: '显示日期、时间和待办任务列表，支持任务切换和提醒信息',
      icon: Icons.check_circle_outline,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.upcomingTasksWidget: const CommonWidgetMetadata(
      id: CommonWidgetId.upcomingTasksWidget,
      name: '即将到来的任务小组件',
      description: '显示任务计数、任务列表和更多任务数量，支持动画效果',
      icon: Icons.task_alt,
      defaultSize: Large3Size(),
      supportedSizes: [MediumSize(), LargeSize()],
    ),
    CommonWidgetId.profileCardCard: const CommonWidgetMetadata(
      id: CommonWidgetId.profileCardCard,
      name: '个人资料卡片',
      description: '展示用户个人信息，包括背景图、姓名、认证标志、简介和关注统计',
      icon: Icons.account_circle,
      defaultSize: Large3Size(),
      supportedSizes: [MediumSize(), LargeSize()],
    ),
    CommonWidgetId.sleepStageChartCard: const CommonWidgetMetadata(
      id: CommonWidgetId.sleepStageChartCard,
      name: '睡眠阶段图表',
      description: '展示睡眠阶段的可视化图表，支持动画效果和时间范围选择',
      icon: Icons.bedtime_outlined,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.miniTrendCard: const CommonWidgetMetadata(
      id: CommonWidgetId.miniTrendCard,
      name: '迷你趋势卡片',
      description: '显示标题、图标、当前数值、单位、副标题、星期标签和趋势折线图',
      icon: Icons.show_chart,
      defaultSize: Large3Size(),
      supportedSizes: [MediumSize(), LargeSize()],
    ),
    CommonWidgetId.accountBalanceCard: const CommonWidgetMetadata(
      id: CommonWidgetId.accountBalanceCard,
      name: '账户余额卡片',
      description: '显示多个账户的余额信息，包括账户名称、图标、账单数量和余额，支持正负余额显示和入场动画效果',
      icon: Icons.account_balance,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.modernRoundedSpendingWidget: const CommonWidgetMetadata(
      id: CommonWidgetId.modernRoundedSpendingWidget,
      name: '现代圆角消费卡片',
      description: '显示当前消费、预算、分类进度条和分类列表，支持动画效果',
      icon: Icons.payments_outlined,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.walletBalanceCard: const CommonWidgetMetadata(
      id: CommonWidgetId.walletBalanceCard,
      name: '钱包余额概览卡片',
      description: '显示钱包余额、可用余额、收入支出统计和操作按钮，支持动画效果',
      icon: Icons.account_balance_wallet,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.scoreCardWidget: const CommonWidgetMetadata(
      id: CommonWidgetId.scoreCardWidget,
      name: '分数卡片',
      description: '显示分数、等级和行为列表，支持翻转计数动画和渐变背景',
      icon: Icons.scoreboard,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.trendValueCard: const CommonWidgetMetadata(
      id: CommonWidgetId.trendValueCard,
      name: '趋势数值卡片',
      description:
          '通用的数值展示卡片，支持数值和单位显示（带翻转动画）、趋势指示（上升/下降）、曲线图表（带渐变填充）和附加信息（日期、BMI等）',
      icon: Icons.trending_up,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.trendListCard: const CommonWidgetMetadata(
      id: CommonWidgetId.trendListCard,
      name: '趋势列表卡片',
      description: '股票/指数价格与涨跌幅列表卡片，支持多个趋势项展示，带翻转计数动画和入场效果',
      icon: Icons.trending_up,
      defaultSize: Large3Size(),
      supportedSizes: [MediumSize(), LargeSize()],
    ),
    CommonWidgetId.modernEgfrHealthWidget: const CommonWidgetMetadata(
      id: CommonWidgetId.modernEgfrHealthWidget,
      name: '健康指标卡片',
      description: '通用的健康指标展示卡片，支持标题、图标、数值（带翻转动画）、单位和状态指示器',
      icon: Icons.favorite,
      defaultSize: Large3Size(),
      supportedSizes: [MediumSize(), LargeSize()],
    ),

    CommonWidgetId.moodChartCard: const CommonWidgetMetadata(
      id: CommonWidgetId.moodChartCard,
      name: '心情图表卡片',
      description: '显示每日情绪柱状图和每周心情历史记录，支持动画效果和多种心情表情',
      icon: Icons.sentiment_satisfied_alt,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.dailyEventsCard: CommonWidgetMetadata(
      id: CommonWidgetId.dailyEventsCard,
      name: '每日事件卡片',
      description: '显示星期、日期和当日事件列表，支持翻转计数动画',
      icon: Icons.event,
      defaultSize: Large3Size(),
      supportedSizes: const [MediumSize(), LargeSize()],
    ),
    CommonWidgetId.dailyReflectionCard: const CommonWidgetMetadata(
      id: CommonWidgetId.dailyReflectionCard,
      name: '每日反思卡片',
      description: '引导用户每日思考和记录的卡片，包含星期几、引导性问题和操作按钮',
      icon: Icons.lightbulb_outline,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.monthlyBillCard: const CommonWidgetMetadata(
      id: CommonWidgetId.monthlyBillCard,
      name: '月度账单卡片',
      description: '显示月度账单信息，包括收入、支出和结余，支持翻转计数动画和入场效果',
      icon: Icons.receipt_long,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.spendingTrendChart: const CommonWidgetMetadata(
      id: CommonWidgetId.spendingTrendChart,
      name: '支出趋势折线图',
      description: '显示支出趋势对比的折线图卡片，支持当前月与上月对比、预算线显示和平滑曲线动画',
      icon: Icons.show_chart,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.modernRoundedMoodWidget: const CommonWidgetMetadata(
      id: CommonWidgetId.modernRoundedMoodWidget,
      name: '现代化心情追踪',
      description: '周视图柱状图显示每日心情值，支持积极/消极情绪区分、7天心情历史和当前日期高亮',
      icon: Icons.sentiment_satisfied_alt,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.eventCalendarWidget: const CommonWidgetMetadata(
      id: CommonWidgetId.eventCalendarWidget,
      name: '日历事件小组件',
      description: '显示日期、周日历和事件列表，支持活动计数和提醒信息',
      icon: Icons.calendar_today,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.roundedTaskProgressWidget: const CommonWidgetMetadata(
      id: CommonWidgetId.roundedTaskProgressWidget,
      name: '圆角任务进度小组件',
      description: '显示项目标题、进度条、待办任务列表、评论数、附件数和团队成员头像',
      icon: Icons.task_alt,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.dailyBarChartCard: const CommonWidgetMetadata(
      id: CommonWidgetId.dailyBarChartCard,
      name: '每日条形图卡片',
      description: '显示每日数据条形图，支持标题、副标题、数值显示和多种颜色',
      icon: Icons.bar_chart,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.nutritionProgressCard: const CommonWidgetMetadata(
      id: CommonWidgetId.nutritionProgressCard,
      name: '营养进度卡片',
      description: '显示卡路里和营养素（蛋白质、碳水化合物、脂肪）进度，支持动画计数',
      icon: Icons.restaurant,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.portfolioStackedChart: const CommonWidgetMetadata(
      id: CommonWidgetId.portfolioStackedChart,
      name: '投资组合堆叠图',
      description: '显示投资组合的堆叠柱状图，支持多种资产类型和月度数据展示',
      icon: Icons.show_chart,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.activityRingsCard: const CommonWidgetMetadata(
      id: CommonWidgetId.activityRingsCard,
      name: '活动圆环卡片',
      description: '显示活动圆环（步数、卡路里等），支持日期和状态显示',
      icon: Icons.fitness_center,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.categoryStackWidget: CommonWidgetMetadata(
      id: CommonWidgetId.categoryStackWidget,
      name: '分类堆叠消费卡片',
      description: '显示分类消费堆叠图，支持当前金额、目标金额和分类列表',
      icon: Icons.pie_chart,
      defaultSize: Large3Size(),
      supportedSizes: const [LargeSize()],
    ),
    CommonWidgetId.performanceBarChart: CommonWidgetMetadata(
      id: CommonWidgetId.performanceBarChart,
      name: '性能指标柱状图',
      description: '显示性能指标柱状图，支持增长百分比和时间周期',
      icon: Icons.bar_chart,
      defaultSize: Large3Size(),
      supportedSizes: const [LargeSize()],
    ),
    CommonWidgetId.rankedBarChartCard: CommonWidgetMetadata(
      id: CommonWidgetId.rankedBarChartCard,
      name: '排名条形图卡片',
      description: '显示排名条形图列表，支持标题、副标题、条目计数和页脚文本',
      icon: Icons.bar_chart,
      defaultSize: Large3Size(),
      supportedSizes: const [LargeSize()],
    ),
    CommonWidgetId.rentalPreviewCard: const CommonWidgetMetadata(
      id: CommonWidgetId.rentalPreviewCard,
      name: '租赁预览卡片',
      description: '显示租赁信息的卡片，包含图片、标题、评分、描述和时间',
      icon: Icons.home_work,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.roundedPropertyCard: const CommonWidgetMetadata(
      id: CommonWidgetId.roundedPropertyCard,
      name: '圆角属性卡片',
      description: '显示房地产属性的卡片，包含图片、标题、元数据和描述',
      icon: Icons.home,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.taskListStatCard: const CommonWidgetMetadata(
      id: CommonWidgetId.taskListStatCard,
      name: '任务统计列表卡片',
      description: '显示任务统计和列表的卡片，包含图标、计数和任务列表',
      icon: Icons.format_list_bulleted,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.taskProgressList: const CommonWidgetMetadata(
      id: CommonWidgetId.taskProgressList,
      name: '任务进度列表',
      description: '显示任务进度列表，包含任务标题、时间和进度条',
      icon: Icons.task_alt,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.sleepDurationCard: const CommonWidgetMetadata(
      id: CommonWidgetId.sleepDurationCard,
      name: '睡眠时长统计卡片',
      description: '显示睡眠时长、趋势和睡眠周期可视化',
      icon: Icons.bedtime_outlined,
      defaultSize: Large3Size(),
      supportedSizes: [MediumSize(), LargeSize()],
    ),
    CommonWidgetId.moodTrackerCard: const CommonWidgetMetadata(
      id: CommonWidgetId.moodTrackerCard,
      name: '心情追踪卡片',
      description: '显示情绪记录和每周情绪数据',
      icon: Icons.sentiment_satisfied_alt,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.monthlyDotTrackerCard: const CommonWidgetMetadata(
      id: CommonWidgetId.monthlyDotTrackerCard,
      name: '月度点追踪卡片',
      description: '显示当月的签到状态点阵、进度统计和状态标签',
      icon: Icons.calendar_month,
      defaultSize: Large3Size(),
      supportedSizes: [MediumSize(), LargeSize()],
    ),
    CommonWidgetId.checkinItemCard: const CommonWidgetMetadata(
      id: CommonWidgetId.checkinItemCard,
      name: '签到项目卡片',
      description: '显示签到项目的图标、名称、今日打卡状态和热力图',
      icon: Icons.checklist,
      defaultSize: MediumSize(),
      supportedSizes: [MediumSize(), LargeSize()],
    ),
    CommonWidgetId.activityHeatmapCard: const CommonWidgetMetadata(
      id: CommonWidgetId.activityHeatmapCard,
      name: '活动热力图卡片',
      description: '展示今日24小时的活动热力图，支持不同时间粒度（5/10/15/30/60分钟）',
      icon: Icons.grid_on,
      defaultSize: Large3Size(),
      supportedSizes: [Large3Size()],
    ),
    CommonWidgetId.activityTodayPieChartCard: const CommonWidgetMetadata(
      id: CommonWidgetId.activityTodayPieChartCard,
      name: '今日活动统计卡片',
      description: '使用饼状图展示今日活动统计，按标签统计时长',
      icon: Icons.pie_chart,
      defaultSize: Large3Size(),
      supportedSizes: [Large3Size()],
    ),
    CommonWidgetId.timelineScheduleCard: const CommonWidgetMetadata(
      id: CommonWidgetId.timelineScheduleCard,
      name: '时间线日程卡片',
      description: '显示今天和昨天的活动日程，支持动画效果',
      icon: Icons.timeline,
      defaultSize: Large3Size(),
      supportedSizes: [Large3Size()],
    ),
    CommonWidgetId.bloodPressureTracker: const CommonWidgetMetadata(
      id: CommonWidgetId.bloodPressureTracker,
      name: '双数值追踪卡片',
      description: '显示两个关联数值和周趋势柱状图，适用于血压、血糖等健康指标',
      icon: Icons.water_drop,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.trendLineChartCard: const CommonWidgetMetadata(
      id: CommonWidgetId.trendLineChartCard,
      name: '趋势折线图卡片',
      description: '带动画效果的折线图组件，支持显示标题、图标、数值和时间轴标签',
      icon: Icons.show_chart,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.modernRoundedBalanceCard: const CommonWidgetMetadata(
      id: CommonWidgetId.modernRoundedBalanceCard,
      name: '现代圆角余额卡片',
      description: '展示余额和可用额度，带有每周数据柱状图',
      icon: Icons.account_balance_wallet,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.barChartStatsCard: const CommonWidgetMetadata(
      id: CommonWidgetId.barChartStatsCard,
      name: '柱状图统计卡片',
      description: '显示统计数据和日期范围的柱状图，支持动画效果',
      icon: Icons.bar_chart,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.expenseComparisonChart: const CommonWidgetMetadata(
      id: CommonWidgetId.expenseComparisonChart,
      name: '支出对比图表',
      description: '显示本月与上月对比，双数据系列柱状图',
      icon: Icons.compare_arrows,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.weeklyDiaryWidget: CommonWidgetMetadata(
      id: CommonWidgetId.weeklyDiaryWidget,
      name: '七日周报小组件',
      description: '显示本周七天日记的概览，包括日期、心情和标题',
      icon: Icons.calendar_view_week,
      defaultSize: Wide2Size(),
      supportedSizes: [const WideSize(), const Wide2Size()],
    ),
    CommonWidgetId.activityLastActivity: CommonWidgetMetadata(
      id: CommonWidgetId.activityLastActivity,
      name: '上次活动小组件',
      description: '显示距离上次活动经过的时间和上次活动的时间',
      icon: Icons.history,
      defaultSize: MediumSize(),
      supportedSizes: [MediumSize()],
    ),
    CommonWidgetId.folderNotesCard: CommonWidgetMetadata(
      id: CommonWidgetId.folderNotesCard,
      name: '文件夹笔记卡片',
      description: '显示文件夹名称和最近的笔记列表',
      icon: Icons.folder_open,
      defaultSize: LargeSize(),
      supportedSizes: [MediumSize(), LargeSize()],
    ),
    CommonWidgetId.goodsItemSelector: CommonWidgetMetadata(
      id: CommonWidgetId.goodsItemSelector,
      name: '物品选择器',
      description: '显示单个或多个物品信息，支持列表和网格视图',
      icon: Icons.inventory_2,
      defaultSize: MediumSize(),
      supportedSizes: [MediumSize(), LargeSize()],
    ),
    CommonWidgetId.habitHeatmapCard: CommonWidgetMetadata(
      id: CommonWidgetId.habitHeatmapCard,
      name: '习惯热力图卡片',
      description: '显示习惯的每日热力图，支持过去7天和当月两种视图模式',
      icon: Icons.grid_on,
      defaultSize: MediumSize(),
      supportedSizes: [MediumSize(), LargeSize()],
    ),
    CommonWidgetId.pointsGoalCard: CommonWidgetMetadata(
      id: CommonWidgetId.pointsGoalCard,
      name: '积分目标进度',
      description: '显示今日积分与目标的进度',
      icon: Icons.flag,
      defaultSize: MediumSize(),
      supportedSizes: [MediumSize(), LargeSize()],
    ),
    CommonWidgetId.storeProductSelector: CommonWidgetMetadata(
      id: CommonWidgetId.storeProductSelector,
      name: '商品选择器',
      description: '显示商品列表，支持单个或多个商品展示',
      icon: Icons.shopping_bag,
      defaultSize: LargeSize(),
      supportedSizes: [MediumSize(), LargeSize()],
    ),
    CommonWidgetId.storeUserItemSelector: CommonWidgetMetadata(
      id: CommonWidgetId.storeUserItemSelector,
      name: '用户物品选择器',
      description: '显示用户物品列表，支持单个或多个物品展示',
      icon: Icons.inventory_2,
      defaultSize: MediumSize(),
      supportedSizes: [MediumSize(), LargeSize()],
    ),
    CommonWidgetId.notebookListCard: CommonWidgetMetadata(
      id: CommonWidgetId.notebookListCard,
      name: '笔记本列表卡片',
      description: '显示笔记本和节点列表，支持展开/折叠',
      icon: Icons.book,
      defaultSize: LargeSize(),
      supportedSizes: [const LargeSize(), const Large3Size()],
    ),
    CommonWidgetId.nodeStatsCard: CommonWidgetMetadata(
      id: CommonWidgetId.nodeStatsCard,
      name: '节点统计卡片',
      description: '显示节点统计信息（总数、待办、进行中、已完成）',
      icon: Icons.bar_chart,
      defaultSize: LargeSize(),
      supportedSizes: [const LargeSize(), const Large3Size()],
    ),
    CommonWidgetId.todoNodesList: CommonWidgetMetadata(
      id: CommonWidgetId.todoNodesList,
      name: '待办节点列表',
      description: '显示所有待办节点列表',
      icon: Icons.check_circle_outline,
      defaultSize: LargeSize(),
      supportedSizes: [const LargeSize(), const Large3Size()],
    ),
    CommonWidgetId.recentContactCard: CommonWidgetMetadata(
      id: CommonWidgetId.recentContactCard,
      name: '最近联系人卡片',
      description: '显示最近30天内的联系人列表',
      icon: Icons.people,
      defaultSize: MediumSize(),
      supportedSizes: [MediumSize(), LargeSize()],
    ),
    CommonWidgetId.contactCard: CommonWidgetMetadata(
      id: CommonWidgetId.contactCard,
      name: '联系人卡片',
      description: '显示联系人信息（头像、姓名、最后联系时间、标签）',
      icon: Icons.person,
      defaultSize: MediumSize(),
      supportedSizes: [MediumSize(), LargeSize()],
    ),
    CommonWidgetId.timerCard: CommonWidgetMetadata(
      id: CommonWidgetId.timerCard,
      name: '计时器卡片',
      description: '显示计时器任务卡片，支持播放/暂停/重置功能',
      icon: Icons.timer,
      defaultSize: LargeSize(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.habitCard: CommonWidgetMetadata(
      id: CommonWidgetId.habitCard,
      name: '习惯卡片',
      description: '显示习惯的打卡记录、统计和计时状态',
      icon: Icons.auto_awesome,
      defaultSize: LargeSize(),
      supportedSizes: [LargeSize()],
    ),
    CommonWidgetId.memorialDayCard: const CommonWidgetMetadata(
      id: CommonWidgetId.memorialDayCard,
      name: '纪念日卡片',
      description: '显示纪念日的日期、倒计时和背景样式',
      icon: Icons.calendar_today,
      defaultSize: Large3Size(),
      supportedSizes: [Large3Size()],
    ),
    CommonWidgetId.healthScoreRingCard: const CommonWidgetMetadata(
      id: CommonWidgetId.healthScoreRingCard,
      name: '健康分数环形统计卡片',
      description: '分段圆环统计图（每段带图标，中心显示总分数）+ 统计项目列表（图标、进度条、分数）',
      icon: Icons.monitor_heart,
      defaultSize: Large3Size(),
      supportedSizes: [Large3Size(), Wide2Size()],
    ),
    CommonWidgetId.petalRadialChartCard: const CommonWidgetMetadata(
      id: CommonWidgetId.petalRadialChartCard,
      name: '花瓣径向统计卡片',
      description: '圆等分为圆角扇形花瓣，满幅底瓣 + 按数值比例填充彩色花瓣，沿分角线标注数值与标签',
      icon: Icons.filter_vintage,
      defaultSize: LargeSize(),
      supportedSizes: [LargeSize(), Large3Size()],
    ),
    CommonWidgetId.stackedFolderCard: const CommonWidgetMetadata(
      id: CommonWidgetId.stackedFolderCard,
      name: '堆叠文件夹卡片',
      description: '层叠内容（照片/便签/文档）+ 底部口袋卡片，点击或悬停扇出展开',
      icon: Icons.folder_copy,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize(), Large3Size()],
    ),
    CommonWidgetId.stackedAccordionCard: const CommonWidgetMetadata(
      id: CommonWidgetId.stackedAccordionCard,
      name: '堆叠手风琴卡片',
      description: '卡片层叠覆盖，点击互斥展开手风琴面板：进度条生长 + 条目交错渐入 + 箭头旋转',
      icon: Icons.layers,
      defaultSize: Large3Size(),
      supportedSizes: [Large3Size(), Wide3Size()],
    ),
    CommonWidgetId.cuteNotepadCard: const CommonWidgetMetadata(
      id: CommonWidgetId.cuteNotepadCard,
      name: '可爱手账便签卡片',
      description: '手绘便签纸（16 种风格预设：方格/格纹/波浪框/撕边/活页孔等）+ 可爱贴纸与手写内容，高度随内容自适应',
      icon: Icons.sticky_note_2,
      defaultSize: Large3Size(),
      supportedSizes: [LargeSize(), Large3Size()],
    ),
    CommonWidgetId.scrapbookCanvasCard: const CommonWidgetMetadata(
      id: CommonWidgetId.scrapbookCanvasCard,
      name: '手帐无限画布卡片',
      description: '可平移缩放的网格画布 + 可拖拽/旋转/删除的手帐拼贴元素 + 手绘涂鸦与创建抽屉',
      icon: Icons.dashboard_customize,
      defaultSize: Large3Size(),
      supportedSizes: [Large3Size()],
    ),
    CommonWidgetId.arcRotaryWheelCard: const CommonWidgetMetadata(
      id: CommonWidgetId.arcRotaryWheelCard,
      name: '弧形圆盘选择卡片',
      description: '选项沿右侧大圆弧排布的手绘转轮：拖拽/甩动/点击选择，弹簧吸附 + 指针回弹（仅一个默认尺寸）',
      icon: Icons.album,
      defaultSize: Large3Size(),
      supportedSizes: [Large3Size()],
    ),
    CommonWidgetId.walkStackCard: const CommonWidgetMetadata(
      id: CommonWidgetId.walkStackCard,
      name: '随机漫步卡片堆叠',
      description: '手绘书摘卡堆叠：拖拽顶层卡片飞出切卡、后层弹性补位，支持顺序循环与随机漫步两种取卡模式',
      icon: Icons.style,
      defaultSize: Large3Size(),
      supportedSizes: [Large3Size()],
    ),
    CommonWidgetId.illustratedMetricCard: const CommonWidgetMetadata(
      id: CommonWidgetId.illustratedMetricCard,
      name: '插画指标卡片',
      description: '彩色插画区域搭配标题、数值和单位，适合展示学习与活动指标',
      icon: Icons.auto_stories,
      defaultSize: WideSize(),
      supportedSizes: [WideSize(), Wide2Size()],
    ),
    CommonWidgetId.cutoutStatGridCard: const CommonWidgetMetadata(
      id: CommonWidgetId.cutoutStatGridCard,
      name: '切角统计网格卡片',
      description: '液体切角圆形图标与多列统计数据网格',
      icon: Icons.dashboard_customize,
      defaultSize: Wide2Size(),
      supportedSizes: [Wide2Size(), Large3Size()],
    ),
    CommonWidgetId.gradientProgressCard: const CommonWidgetMetadata(
      id: CommonWidgetId.gradientProgressCard,
      name: '渐变进度卡片',
      description: '渐变轨道、斜线纹理与可拖动圆形滑块的百分比进度卡片',
      icon: Icons.linear_scale,
      defaultSize: WideSize(),
      supportedSizes: [WideSize(), Wide2Size()],
    ),
    CommonWidgetId.stripedWeeklyChartCard: const CommonWidgetMetadata(
      id: CommonWidgetId.stripedWeeklyChartCard,
      name: '斜线周图表卡片',
      description: '带虚线网格、斜线胶囊柱和选中提示的每周数据图表',
      icon: Icons.bar_chart,
      defaultSize: Wide2Size(),
      supportedSizes: [Wide2Size(), Large3Size()],
    ),
  };

  /// 获取元数据
  static CommonWidgetMetadata getMetadata(CommonWidgetId id) {
    return metadata[id]!;
  }

  /// 获取所有元数据
  static List<CommonWidgetMetadata> getAllMetadata() {
    return metadata.values.toList();
  }

  /// 根据 ID 字符串获取枚举值
  static CommonWidgetId? fromString(String id) {
    return CommonWidgetId.values.asNameMap()[id];
  }
}

/// 公共小组件构建器
class CommonWidgetBuilder {
  /// 构建公共小组件
  ///
  /// 如果 props 中包含 `_pixelCategory`，会根据像素尺寸创建有效的 size，
  /// 使公共组件能响应窗口大小变化。
  static Widget build(
    BuildContext context,
    CommonWidgetId widgetId,
    Map<String, dynamic> props,
    HomeWidgetSize size, {
    bool inline = false,
  }) {
    // 将 inline 参数添加到 props 中，以便各个小组件可以读取
    final finalProps = Map<String, dynamic>.from(props);
    finalProps['inline'] = inline;

    // 如果 props 中有 _pixelCategory，使用它创建基于像素尺寸的有效 size
    // 这样公共组件可以根据实际像素尺寸调整布局
    final pixelCategory = props['_pixelCategory'] as SizeCategory?;
    final effectiveSize = pixelCategory != null
        ? HomeWidgetSize.fromCategory(pixelCategory)
        : size;

    switch (widgetId) {
      case CommonWidgetId.circularProgressCard:
        return CircularProgressCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.iconCircularProgressCard:
        return IconCircularProgressCardWidget.fromProps(
          finalProps,
          effectiveSize,
        );
      case CommonWidgetId.colorTagTaskCard:
        return ColorTagTaskCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.activityProgressCard:
        return CardDotProgressDisplay.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.halfGaugeCard:
        return HalfGaugeCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.taskProgressCard:
        return TaskProgressCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.taskListCard:
        return TaskListCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.audioWaveformCard:
        return AudioWaveformCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.segmentedProgressCard:
        return SegmentedProgressCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.monthlyProgressDotsCard:
        return MonthlyProgressWithDotsCardWidget.fromProps(
          finalProps,
          effectiveSize,
        );
      case CommonWidgetId.multiMetricProgressCard:
        return MultiMetricProgressCardWidget.fromProps(
          finalProps,
          effectiveSize,
        );
      case CommonWidgetId.circularMetricsCard:
        return CircularMetricsCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.smoothLineChartCard:
        return SmoothLineChartCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.lineChartTrendCard:
        return LineChartTrendCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.verticalBarChartCard:
        return VerticalBarChartCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.inboxMessageCard:
        return InboxMessageCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.roundedTaskListCard:
        return RoundedTaskListCard.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.roundedRemindersList:
        return ReminderListCard.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.dualSliderCard:
        return DualSliderWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.earningsTrendCard:
        return EarningsTrendCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.revenueTrendCard:
        return RevenueTrendCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.stressLevelMonitor:
        return CardBarChartMonitor.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.dailyTodoListCard:
        return DailyTodoListWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.upcomingTasksWidget:
        return UpcomingTasksWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.profileCardCard:
        return ProfileCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.sleepStageChartCard:
        return CardBubbleChartDisplay.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.imageDisplayCard:
        return ImageDisplayCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.weightTrendChart:
        return CardTrendLineChart.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.miniTrendCard:
        return MiniTrendCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.accountBalanceCard:
        return AccountBalanceCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.modernRoundedSpendingWidget:
        return ModernRoundedSpendingWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.walletBalanceCard:
        return WalletBalanceCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.scoreCardWidget:
        return ScoreCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.trendValueCard:
        return TrendValueCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.trendListCard:
        return TrendListCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.modernEgfrHealthWidget:
        return ModernFlipCounterCard.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.moodChartCard:
        return ChartIconDisplayCard.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.dailyEventsCard:
        return DailyEventsCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.dailyReflectionCard:
        return DailyReflectionCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.monthlyBillCard:
        return MonthlyBillCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.spendingTrendChart:
        return SpendingTrendChartWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.modernRoundedMoodWidget:
        return ModernRoundedBarIconCard.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.eventCalendarWidget:
        return EventCalendarWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.roundedTaskProgressWidget:
        return RoundedTaskProgressWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.dailyBarChartCard:
        return DailyBarChartCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.nutritionProgressCard:
        return SplitColumnProgressBarCard.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.portfolioStackedChart:
        return PortfolioStackedChartWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.activityRingsCard:
        return ActivityRingsCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.categoryStackWidget:
        return CategoryStackWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.performanceBarChart:
        return PerformanceBarChartWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.rankedBarChartCard:
        return RankedBarChartCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.rentalPreviewCard:
        return RentalPreviewCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.roundedPropertyCard:
        return RoundedPropertyCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.taskListStatCard:
        return TaskListStatCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.taskProgressList:
        return TaskProgressListWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.sleepDurationCard:
        return DarkBarChartCard.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.moodTrackerCard:
        return CardEmojiIconDisplay.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.monthlyDotTrackerCard:
        return MonthlyDotTrackerCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.checkinItemCard:
        return CheckinItemCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.activityHeatmapCard:
        return ActivityHeatmapCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.activityTodayPieChartCard:
        return ActivityTodayPieChartCardWidget.fromProps(
          finalProps,
          effectiveSize,
        );
      case CommonWidgetId.timelineScheduleCard:
        return TimelineScheduleCard.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.bloodPressureTracker:
        return DualValueTrackerCardWrapper.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.trendLineChartCard:
        return TrendLineChartCardWrapper.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.modernRoundedBalanceCard:
        return ModernRoundedBalanceCard.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.barChartStatsCard:
        return BarChartStatsCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.expenseComparisonChart:
        return ExpenseComparisonChartCardWidget.fromProps(
          finalProps,
          effectiveSize,
        );
      case CommonWidgetId.weeklyDiaryWidget:
        return WeeklyDiaryWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.activityLastActivity:
        return ActivityLastActivityWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.folderNotesCard:
        return FolderNotesCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.goodsItemSelector:
        return GoodsItemSelectorWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.habitHeatmapCard:
        return HabitHeatmapCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.pointsGoalCard:
        return PointsGoalCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.storeProductSelector:
        return StoreProductSelectorCardWidget.fromProps(
          finalProps,
          effectiveSize,
        );
      case CommonWidgetId.storeUserItemSelector:
        return StoreUserItemSelectorCardWidget.fromProps(
          finalProps,
          effectiveSize,
        );
      case CommonWidgetId.notebookListCard:
        return NotebookListCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.nodeStatsCard:
        return NodeStatsCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.todoNodesList:
        return TodoNodesListWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.contactCard:
        return ContactCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.recentContactCard:
        return RecentContactCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.habitCard:
        return HabitCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.memorialDayCard:
        return MemorialDayCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.healthScoreRingCard:
        return HealthScoreRingCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.petalRadialChartCard:
        return PetalRadialChartCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.stackedFolderCard:
        return StackedFolderCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.stackedAccordionCard:
        return StackedAccordionCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.cuteNotepadCard:
        return CuteNotepadCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.scrapbookCanvasCard:
        return ScrapbookCanvasCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.arcRotaryWheelCard:
        return ArcRotaryWheelCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.walkStackCard:
        return WalkStackCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.illustratedMetricCard:
        return IllustratedMetricCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.cutoutStatGridCard:
        return CutoutStatGridCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.gradientProgressCard:
        return GradientProgressCardWidget.fromProps(finalProps, effectiveSize);
      case CommonWidgetId.stripedWeeklyChartCard:
        return StripedWeeklyChartCardWidget.fromProps(
          finalProps,
          effectiveSize,
        );
      case CommonWidgetId.timerCard:
        return TimerCardWidget.fromProps(finalProps, effectiveSize);
    }
  }
}
