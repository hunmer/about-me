/// 笔记插件主页小组件注册入口
///
/// 此文件负责注册所有笔记插件的主页小组件
library;

import 'package:Memento/screens/home_screen/managers/home_widget_registry.dart';
import 'package:Memento/screens/home_screen/managers/quick_create_registry.dart';

import 'register_icon_widget.dart' show registerIconWidget;
import 'register_overview_widget.dart' show registerOverviewWidget;
import 'register_notes_list_widget.dart' show registerNotesListWidget;
import 'register_day_card.dart' show registerDayCardWidget;
import 'register_quick_create.dart' show registerQuickCreate;

/// 笔记插件的主页小组件注册
void register() {
  final registry = HomeWidgetRegistry();
  registerIconWidget(registry);
  registerOverviewWidget(registry);
  registerNotesListWidget(registry);
  registerDayCardWidget(registry);

  // 注册快速创建项（主页底部 ＋ 按钮）
  registerQuickCreate(QuickCreateRegistry());
}
