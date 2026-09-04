import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// 果冻小屋主导航的四个页签
enum JellyTab { cottage, schedule, board, mine }

/// 果冻小屋底部导航（小屋 / 日程 / 看板 / 我的）
///
/// 漂浮式：[child]（页面内容）铺满全屏并延伸到导航栏下方，
/// 导航栏悬浮在内容之上，不占用布局高度。点击页签通过 [onTap]
/// 通知宿主切换内容，不涉及路由跳转。
///
/// 通过 Scaffold.extendBody 把导航栏高度注入 body 的
/// MediaQuery.padding.bottom，页内 SafeArea、网格滚动区等内容
/// 可读取该内边距避让导航栏；同时同步到 viewPadding.bottom，
/// 让页内悬浮 FAB（按 viewPadding 定位）也上浮避让。
class JellyBottomNav extends StatelessWidget {
  const JellyBottomNav({
    super.key,
    required this.current,
    required this.child,
    this.onTap,
  });

  /// 当前所在页签
  final JellyTab current;

  /// 沉在导航栏下方的页面内容（铺满全屏）
  final Widget child;

  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: _buildBar(context),
      body: Builder(
        builder: (context) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              viewPadding: mq.viewPadding.copyWith(
                bottom: mq.padding.bottom,
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
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
