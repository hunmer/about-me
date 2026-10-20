/// Agent Chat 插件的主页小组件注册
///
/// 提供多个主页小组件：
/// - [registerOverviewWidget] - 2x2 详细卡片组件
/// - [registerConversationSelector] - 会话选择器组件
library;

export 'data.dart';
export 'utils.dart';
export 'providers.dart';
export 'widgets.dart';

// 注册文件
export 'register_overview_widget.dart';
export 'register_conversation_selector.dart';

import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'register_overview_widget.dart';
import 'register_conversation_selector.dart';

/// 注册所有插件的小组件
void register() {
  final registry = HomeWidgetRegistry();
  registerOverviewWidget(registry);
  registerConversationSelector(registry);
}
