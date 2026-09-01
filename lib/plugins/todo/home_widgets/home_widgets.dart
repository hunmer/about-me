/// 待办插件的主页小组件注册
///
/// 提供多个主页小组件：
/// - [registerIconWidget] - 1x1 简单图标组件
/// - [registerOverviewWidget] - 2x2 详细卡片组件
/// - [registerQuickAddWidget] - 1x1 快速添加小组件
/// - [registerTodoListWidget] - 2x2 待办列表小组件
library;

export 'data.dart';
export 'utils.dart';
export 'providers.dart';
export 'providers/command_widgets_provider.dart';
export 'widgets.dart';

// 注册文件
export 'register_icon_widget.dart';
export 'register_overview_widget.dart';
export 'register_quick_add_widget.dart';
export 'register_todo_list_widget.dart';
export 'register_day_card.dart';
export 'register_quick_create.dart';

import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/managers/quick_create_registry.dart';
import 'register_icon_widget.dart';
import 'register_overview_widget.dart';
import 'register_quick_add_widget.dart';
import 'register_todo_list_widget.dart';
import 'register_day_card.dart';
import 'register_quick_create.dart';

/// 注册所有待办插件的小组件
void register() {
  final registry = HomeWidgetRegistry();

  registerIconWidget(registry);
  registerOverviewWidget(registry);
  registerQuickAddWidget(registry);
  registerTodoListWidget(registry);
  registerDayCardWidget(registry);

  // 注册快速创建项（主页底部 ＋ 按钮）
  registerQuickCreate(QuickCreateRegistry());
}
