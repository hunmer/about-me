import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// 果冻小屋主导航的四个页签
enum JellyTab { cottage, schedule, board, mine }

/// 果冻小屋底部导航（小屋 / 日程 / 看板 / 我的）
///
/// 纯内容切换：点击页签通过 [onTap] 通知宿主切换展示内容，
/// 不涉及路由跳转。
class JellyBottomNav extends StatelessWidget {
  const JellyBottomNav({super.key, required this.current, this.onTap});

  /// 当前所在页签
  final JellyTab current;

  final ValueChanged<int>? onTap;

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
          onTap: onTap,
        ),
      ),
    );
  }
}
