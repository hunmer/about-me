import 'package:get/get.dart';
import 'package:aboutme/plugins/habits/controllers/completion_record_controller.dart';
import 'package:aboutme/plugins/habits/controllers/habit_controller.dart';
import 'package:aboutme/plugins/habits/controllers/skill_controller.dart';
import 'package:aboutme/plugins/habits/widgets/habits_list/habits_view.dart';
import 'package:aboutme/plugins/habits/widgets/skills_list.dart';
import 'package:aboutme/plugins/habits/widgets/habit_form.dart';
import 'package:aboutme/plugins/habits/widgets/skill_form.dart';
import 'package:aboutme/plugins/habits/habits_plugin.dart';
import 'package:aboutme/core/widgets/keep_alive_wrapper.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/custom_bottom_bar.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

/// Habits 插件的底部栏组件
/// 提供习惯列表和技能列表两个 Tab 的切换功能
class HabitsBottomBar extends StatefulWidget {
  final HabitsPlugin plugin;
  final String? habitId;

  const HabitsBottomBar({super.key, required this.plugin, this.habitId});

  @override
  State<HabitsBottomBar> createState() => _HabitsBottomBarState();
}

class _HabitsBottomBarState extends State<HabitsBottomBar>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _currentPage;
  final GlobalKey _bottomBarKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  late final HabitController _habitController;
  late final SkillController _skillController;
  late final CompletionRecordController _recordController;

  @override
  void initState() {
    super.initState();
    _currentPage = 0;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.animation?.addListener(() {
      final value = _tabController.animation!.value.round();
      if (value != _currentPage && mounted) {
        setState(() {
          _currentPage = value;
        });
      }
    });

    // 获取控制器
    _habitController = widget.plugin.getHabitController();
    _skillController = widget.plugin.getSkillController();
    _recordController = widget.plugin.getRecordController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 构建 FAB
  Widget _buildFab() {
    return DSThemeBridge(
      // DSFab 内部取 AppTheme，需包桥
      child: DSFab(
        key: _fabKey,
        color: widget.plugin.color,
        iconColor: widget.plugin.color.computeLuminance() < 0.5
            ? Colors.white
            : Colors.black,
        icon: _currentPage == 0 ? DsIconKind.clipboard : DsIconKind.heart,
        onPressed: () {
          if (_currentPage == 0) {
            NavigationHelper.openContainerWithHero(
              context,
              (context) => Scaffold(
                appBar: AppBar(
                  title: Text('habits_newHabit'.tr),
                  backgroundColor: Theme.of(
                    context,
                  ).appBarTheme.backgroundColor,
                ),
                backgroundColor: DSThemeBridge.resolve(context).background,
                body: HabitForm(
                  onSave: (habit) async {
                    await _habitController.saveHabit(habit);
                  },
                ),
              ),
              sourceKey: _fabKey,
              heroTag: 'habits_fab_add_habit',
              closedShape: const CircleBorder(),
            );
          } else {
            NavigationHelper.openContainerWithHero(
              context,
              (context) => Scaffold(
                appBar: AppBar(
                  title: Text('habits_createSkill'.tr),
                  backgroundColor: Theme.of(
                    context,
                  ).appBarTheme.backgroundColor,
                ),
                backgroundColor: DSThemeBridge.resolve(context).background,
                body: SkillForm(
                  onSave: (skill) async {
                    await _skillController.saveSkill(skill);
                  },
                ),
              ),
              sourceKey: _fabKey,
              heroTag: 'habits_fab_add_skill',
              closedShape: const CircleBorder(),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomBottomBar(
      currentIndex: _currentPage,
      tabController: _tabController,
      bottomBarKey: _bottomBarKey,
      body: (context, controller) => TabBarView(
        controller: _tabController,
        dragStartBehavior: DragStartBehavior.start,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          KeepAliveWrapper(
            child: CombinedHabitsView(
              controller: _habitController,
              habitId: widget.habitId,
            ),
          ),
          KeepAliveWrapper(
            child: SkillsList(
              skillController: _skillController,
              recordController: _recordController,
            ),
          ),
        ],
      ),
      fab: _buildFab(),
      items: [
        DSNavItem(icon: DsIconKind.check, label: 'habits_habits'.tr),
        DSNavItem(icon: DsIconKind.star, label: 'habits_skills'.tr),
      ],
    );
  }
}
