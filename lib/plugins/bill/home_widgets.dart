/// 账单插件的主页小组件注册
///
/// 提供多个主页小组件：
/// - [registerIconWidget] - 1x1 简单图标组件
/// - [registerOverviewWidget] - 2x2 详细卡片组件
/// - [registerCreateShortcutWidget] - 创建账单快捷入口
/// - [registerBillStatsWidget] - 支出统计组件（公共组件）
/// - [registerMonthlyBillWidget] - 月份账单组件（公共组件）
library;

// 导出所有子模块
export 'home_widgets/bill_colors.dart';
export 'home_widgets/providers.dart';
export 'home_widgets/utils.dart';
export 'home_widgets/widgets.dart';

// 导出注册文件
export 'home_widgets/register_icon_widget.dart';
export 'home_widgets/register_overview_widget.dart';
export 'home_widgets/register_create_shortcut.dart';
export 'home_widgets/register_bill_stats_widget.dart';
export 'home_widgets/register_monthly_bill_widget.dart';
export 'home_widgets/register_day_card.dart';
export 'home_widgets/register_quick_create.dart';

import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/managers/quick_create_registry.dart';
import 'home_widgets/register_icon_widget.dart';
import 'home_widgets/register_overview_widget.dart';
import 'home_widgets/register_create_shortcut.dart';
import 'home_widgets/register_bill_stats_widget.dart';
import 'home_widgets/register_monthly_bill_widget.dart';
import 'home_widgets/register_day_card.dart';
import 'home_widgets/register_quick_create.dart';

/// 注册所有账单插件的小组件
void register() {
  final registry = HomeWidgetRegistry();

  // 注册公共组件
  registerBillStatsWidget(registry);
  registerMonthlyBillWidget(registry);

  // 注册自定义组件
  registerIconWidget(registry);
  registerOverviewWidget(registry);
  registerCreateShortcutWidget(registry);
  registerDayCardWidget(registry);

  // 注册快速创建项（主页底部 ＋ 按钮）
  registerQuickCreate(QuickCreateRegistry());
}
