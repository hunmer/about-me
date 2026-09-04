import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/route.dart';
import 'package:flutter/material.dart';

/// 果冻小屋主导航的四个页签
enum JellyTab { cottage, schedule, board, mine }

/// 果冻小屋底部导航（小屋 / 日程 / 看板 / 我的）
///
/// 各页签对应独立路由：日程=日期数据视图主页，看板=固定布局网格主页，
/// 我的=设置页。切换时保留栈底路由（小屋为启动页），从任意页签
/// 返回都能回到小屋。
class JellyBottomNav extends StatelessWidget {
  const JellyBottomNav({super.key, required this.current});

  /// 当前所在页签
  final JellyTab current;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          theme.spacing.lg,
          theme.spacing.sm,
          theme.spacing.lg,
          theme.spacing.lg,
        ),
        child: DSBottomNavigation(
          items: const [
            DSNavItem(icon: DsIconKind.home, label: '小屋'),
            DSNavItem(icon: DsIconKind.calendar, label: '日程'),
            DSNavItem(icon: DsIconKind.grid, label: '看板'),
            DSNavItem(icon: DsIconKind.user, label: '我的', showBadge: true),
          ],
          currentIndex: current.index,
          onTap: (index) => _switchTab(context, JellyTab.values[index]),
        ),
      ),
    );
  }

  void _switchTab(BuildContext context, JellyTab tab) {
    if (tab == current) return;

    switch (tab) {
      case JellyTab.cottage:
        Navigator.of(context).popUntil((route) => route.isFirst);
      case JellyTab.schedule:
        _push(context, AppRoutes.homeSchedule);
      case JellyTab.board:
        _push(context, AppRoutes.homeBoard);
      case JellyTab.mine:
        _push(context, AppRoutes.settings);
    }
  }

  void _push(BuildContext context, String routeName) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      (route) => route.isFirst,
    );
  }
}
