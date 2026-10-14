import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/tracker/tracker_plugin.dart';
import 'package:aboutme/plugins/tracker/screens/goal_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';

class HomeScreen extends StatefulWidget {
  final bool isGridView;

  const HomeScreen({super.key, this.isGridView = true});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String _filterStatus = '全部';
  String _currentGroup = '全部';

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // SuperCupertinoNavigationWrapper 内无 AppTheme，DS 组件先过桥
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Column(
            children: [
              // 分组切换器
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Consumer<TrackerController>(
                  builder: (context, controller, child) {
                    final groups = ['全部', ...controller.getAllGroups()];
                    return Center(
                      child: DSChipBar(
                        labels: groups,
                        selected: groups.indexOf(_currentGroup).clamp(
                          0,
                          groups.length - 1,
                        ),
                        onChanged: (index) =>
                            setState(() => _currentGroup = groups[index]),
                      ),
                    );
                  },
                ),
              ),
              // 目标列表
              Expanded(child: _buildGoalsList(context, theme)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGoalsList(BuildContext context, AppThemeData theme) {
    final controller = Provider.of<TrackerController>(context);
    final filteredGoals =
        controller.goals.where((goal) {
          if (_currentGroup != '全部' && goal.group != _currentGroup) {
            return false;
          }

          // 根据状态过滤
          if (_filterStatus == '进行中' && goal.isCompleted) return false;
          if (_filterStatus == '已完成' && !goal.isCompleted) return false;

          // 根据日期过滤
          // 这里可以根据需要实现日期过滤逻辑

          return true;
        }).toList();

    if (widget.isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 190, // 与 GoalCard 固定高度一致
          crossAxisSpacing: 8,
          mainAxisSpacing: 16, // ≥16，避免手绘贴条顶部出血被上一行遮挡
        ),
        itemCount: filteredGoals.length,
        itemBuilder: (context, index) {
          final goal = filteredGoals[index];
          return HandDrawnStickyItem(
            tiltKey: goal.id,
            child: GoalCard(
              goal: goal,
              controller: controller,
              onTap: () {
                NavigationHelper.openContainerWithHero(
                  context,
                  (context) => ChangeNotifierProvider.value(
                    value: controller,
                    child: GoalDetailScreen(goal: goal),
                  ),
                  closedColor: theme.surface,
                );
              },
            ),
          );
        },
      );
    }

    return HandDrawnListView(
      padding: const EdgeInsets.all(8),
      itemCount: filteredGoals.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      tiltKeyOf: (index) => filteredGoals[index].id,
      itemBuilder: (context, index) {
        final goal = filteredGoals[index];
        return Dismissible(
          key: Key(goal.id),
          background: Container(
            color: theme.danger,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: DsIcon(DsIconKind.trash, color: DsColors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDSDialog<bool>(
              context: context,
              theme: DSThemeBridge.resolve(context),
              builder:
                  (_) => DSThemeBridge(
                    child: Builder(
                      builder:
                          (context) => DSDialog(
                            title: 'tracker_confirmDeletion'.tr,
                            message:
                                '${'tracker_confirmDeletion'.tr} "${goal.name}"',
                            cancelText: 'app_cancel'.tr,
                            confirmText: 'app_delete'.tr,
                            confirmVariant: DSButtonVariant.destructive,
                          ),
                    ),
                  ),
            );
          },
          onDismissed: (direction) {
            controller.deleteGoal(goal.id);
            Toast.success('${'tracker_goalDeleted'.tr} "${goal.name}"');
          },
          child: GoalListCard(
            goal: goal,
            controller: controller,
            onTap: () {
              NavigationHelper.openContainerWithHero(
                context,
                (context) => ChangeNotifierProvider.value(
                  value: controller,
                  child: GoalDetailScreen(goal: goal),
                ),
                closedColor: theme.surface,
              );
            },
          ),
        );
      },
    );
  }
}
