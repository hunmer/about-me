/// 打卡插件的主页小组件注册
///
/// 提供多个主页小组件：
/// - [registerIconWidget] - 1x1 简单图标组件
/// - [registerOverviewWidget] - 2x2 详细卡片组件
/// - [registerItemSelectorWidget] - 签到项目选择器小组件
/// - [registerItemsSelectorWidget] - 多选签到项目小组件
library;

export 'utils.dart';
export 'providers.dart';

// 注册文件
export 'register_icon_widget.dart';
export 'register_overview_widget.dart';
export 'register_item_selector.dart';
export 'register_items_selector.dart';
export 'register_day_card.dart';

import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'register_icon_widget.dart';
import 'register_overview_widget.dart';
import 'register_item_selector.dart';
import 'register_items_selector.dart';
import 'register_day_card.dart';

/// 注册所有打卡插件的小组件
void register() {
  final registry = HomeWidgetRegistry();
  registerIconWidget(registry);
  registerOverviewWidget(registry);
  registerItemSelectorWidget(registry);
  registerItemsSelectorWidget(registry);
  // 签到日卡（按日期聚合；签到是动作而非表单，不注册快速新建）
  registerDayCardWidget(registry);
}
