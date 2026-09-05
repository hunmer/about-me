import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aboutme/plugins/tracker/tracker_plugin.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

class SearchResultsScreen extends StatefulWidget {
  final String searchQuery;

  const SearchResultsScreen({super.key, required this.searchQuery});

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
              final theme = DSThemeBridge.resolve(context);
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: filteredGoals.length,
                itemBuilder: (context, index) {
                  final goal = filteredGoals[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DSListItem(
                      title: goal.name,
                      subtitle:
                          '${goal.group} • ${goal.currentValue.toStringAsFixed(0)}/${goal.targetValue} ${goal.unitType}',
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: _buildGoalIcon(theme, goal)),
                      ),
                      // 空心圆未完成态无 DS 对应（已知图标缺口），保留 Material 图标对
                      trailing: Icon(
                        goal.isCompleted
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: goal.isCompleted ? theme.success : theme.textSub,
                        size: 24,
                      ),
                      onTap:
                          () => TrackerPlugin.instance.openGoalDetail(
                            context,
                            goal,
                          ),
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

  Widget _buildGoalIcon(AppThemeData theme, Goal goal) {
    // 尝试解析图标代码点，使用 IconData 显示（goal.icon 为持久化数据，保留 Material）
    try {
      final codePoint = int.tryParse(goal.icon);
      if (codePoint != null) {
        return Icon(
          dynamicIconData(codePoint, fontFamily: 'MaterialIcons'),
          size: 20,
          color: theme.primary,
        );
      }
    } catch (e) {
      // 图标解析失败，使用默认图标
    }
    // 默认图标（与解析结果同为 Material 图标，保持一致）
    return Icon(Icons.track_changes, size: 20, color: theme.textSub);
  }
}
