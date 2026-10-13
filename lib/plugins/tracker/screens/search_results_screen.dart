import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aboutme/plugins/tracker/tracker_plugin.dart';

class SearchResultsScreen extends StatefulWidget {
  final String searchQuery;
  final bool isGridView;

  const SearchResultsScreen({
    super.key,
    required this.searchQuery,
    this.isGridView = true,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerController>(
      builder: (context, controller, child) {
        final filteredGoals = _filterGoals(
          controller.goals,
          widget.searchQuery,
        );

        if (widget.searchQuery.isEmpty) {
          return DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DsIcon(
                        DsIconKind.search,
                        size: 64,
                        color: theme.disabled,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '输入关键词搜索目标',
                        style: DsTypography.body.copyWith(color: theme.textSub),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }

        if (filteredGoals.isEmpty) {
          return DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // DS 无收件箱图标，用列表图标顶替
                      DsIcon(DsIconKind.list, size: 64, color: theme.disabled),
                      const SizedBox(height: 16),
                      Text(
                        '未找到相关目标',
                        style: DsTypography.body.copyWith(color: theme.textSub),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '尝试使用其他关键词',
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }

        return DSThemeBridge(
          // SuperCupertinoNavigationWrapper 搜索体内无 AppTheme，DS 组件先过桥
          child: Builder(
            builder: (context) {
              final controller = Provider.of<TrackerController>(context);
              // 搜索结果跟随主界面视图模式：网格卡片 / 列表卡片（水平波纹）
              if (widget.isGridView) {
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 190, // 与 GoalCard 固定高度一致
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: filteredGoals.length,
                  itemBuilder: (context, index) {
                    final goal = filteredGoals[index];
                    return GoalCard(
                      goal: goal,
                      controller: controller,
                      onTap:
                          () => TrackerPlugin.instance.openGoalDetail(
                            context,
                            goal,
                          ),
                    );
                  },
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: filteredGoals.length,
                itemBuilder: (context, index) {
                  final goal = filteredGoals[index];
                  return GoalListCard(
                    goal: goal,
                    controller: controller,
                    onTap:
                        () => TrackerPlugin.instance.openGoalDetail(
                          context,
                          goal,
                        ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  List<Goal> _filterGoals(List<Goal> goals, String query) {
    if (query.isEmpty) return goals;

    final lowercaseQuery = query.toLowerCase();

    return goals.where((goal) {
      // 搜索目标名称
      if (goal.name.toLowerCase().contains(lowercaseQuery)) {
        return true;
      }

      // 搜索分组名称
      if (goal.group.toLowerCase().contains(lowercaseQuery)) {
        return true;
      }

      // 搜索单位类型
      if (goal.unitType.toLowerCase().contains(lowercaseQuery)) {
        return true;
      }

      return false;
    }).toList();
  }
}
