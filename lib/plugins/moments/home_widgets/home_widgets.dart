/// 朋友圈插件的主页小组件注册
library;

export 'register_icon_widget.dart';

import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'register_icon_widget.dart';

/// 注册所有朋友圈插件的小组件
void register() {
  final registry = HomeWidgetRegistry();
  registerIconWidget(registry);
}
