import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/home_screen.dart';
import 'package:aboutme/screens/settings_screen/settings_screen.dart';

import 'widgets/jelly_bottom_nav.dart';
import 'widgets/jelly_daily_tasks_card.dart';
import 'widgets/jelly_growth_card.dart';
import 'widgets/jelly_profile_card.dart';
import 'widgets/jelly_quick_action.dart';
import 'widgets/jelly_stat_card.dart';
import 'widgets/jelly_store_banner.dart';

/// 果冻小屋主页（应用默认启动页）
///
/// 底部导航在四个页签间切换内容（不切换路由）：
/// 小屋（果冻风布局）/ 日程（日期数据视图）/ 看板（固定布局网格）/ 我的（设置）。
///
/// 路由：/jelly_home
class JellyHomeScreen extends StatefulWidget {
  const JellyHomeScreen({super.key});

  @override
  State<JellyHomeScreen> createState() => _JellyHomeScreenState();
}

class _JellyHomeScreenState extends State<JellyHomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          // IndexedStack 保活各页签状态（滚动位置、编辑进度等）
          child: IndexedStack(
            index: _tabIndex,
            children: const [
              _CottageTab(),
              HomeScreen(dateView: true, asRoot: false),
              HomeScreen(asRoot: false),
              SettingsScreen(),
            ],
          ),
        ),
        JellyBottomNav(
          current: JellyTab.values[_tabIndex],
          onTap: (index) => setState(() => _tabIndex = index),
        ),
      ],
    );
  }
}

/// 小屋页签（软糖果冻风布局还原）
///
/// 参考设计稿自上而下：资料卡 + 统计卡
/// → 快捷操作（写日记/打卡/记账 + 新增键）→ 每日任务 + 成长 → 商店横幅。
class _CottageTab extends StatelessWidget {
  const _CottageTab();

  @override
  Widget build(BuildContext context) {
    // 演示页自带浅色主题
    final theme = AppThemeData.light();

    return AppTheme(
      data: theme,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.backgroundAlt, theme.background],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
              // 内容不足一屏时也撑满视口高度，让底部卡片组贴住底部导航
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: viewport.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  // 富余空间全部落在上下两组之间：上组贴顶、底部组贴底
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: theme.spacing.lg),
                        _buildHeader(theme),
                        SizedBox(height: theme.spacing.xl),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 富余空间都在角色区之上，快捷操作行贴着底部卡片组
                        SizedBox(height: theme.spacing.md),
                        _buildQuickActions(theme),
                        SizedBox(height: theme.spacing.lg),
                        _buildTaskRow(theme),
                        SizedBox(height: theme.spacing.lg),
                        JellyStoreBanner(
                          title: '插件商店上新',
                          subtitle: '新插件限时免费领',
                          onTap: () {},
                        ),
                        SizedBox(height: theme.spacing.lg),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 顶部：左资料卡 + 右三张统计卡
  Widget _buildHeader(AppThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: JellyProfileCard(
            name: '小智',
            level: 17,
            exp: 568,
            expMax: 1250,
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < _stats.length; i++) ...[
                if (i > 0) SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: JellyStatCard(
                    icon: _stats[i].$1,
                    label: _stats[i].$2,
                    value: _stats[i].$3,
                    color: [
                      theme.warning,
                      theme.success,
                      theme.primary,
                    ][i],
                    onAdd: () {},
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static const List<(DsIconKind, String, String)> _stats = [
    (DsIconKind.clipboard, '今日待办', '3/8'),
    (DsIconKind.calendarCheck, '连续打卡', '26 天'),
    (DsIconKind.book, '本月记录', '128 条'),
  ];

  /// 快捷操作行：三个果冻圆钮居中，右侧悬浮「+」
  Widget _buildQuickActions(AppThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              JellyQuickAction(
                icon: DsIconKind.book,
                label: '写日记',
                color: theme.secondary,
                size: 56,
                onPressed: () {},
              ),
              SizedBox(width: theme.spacing.xl),
              JellyQuickAction(
                icon: DsIconKind.calendarCheck,
                label: '打卡',
                color: theme.success,
                size: 56,
                onPressed: () {},
              ),
              SizedBox(width: theme.spacing.xl),
              JellyQuickAction(
                icon: DsIconKind.piggy,
                label: '记账',
                color: theme.primary,
                size: 56,
                onPressed: () {},
              ),
            ],
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        DSFab(onPressed: () {}),
      ],
    );
  }

  /// 任务 + 成长双卡
  ///
  /// 滚动视图内高度无界，不能用 IntrinsicHeight 拉等高——成长卡里的
  /// DSLinearProgress 内部是 LayoutBuilder，不支持固有尺寸探测
  /// （LayoutBuilder does not support returning intrinsic dimensions）。
  /// 这里直接给定行高让 stretch 生效，高度取任务卡自然高度（约 136）+ 余量。
  Widget _buildTaskRow(AppThemeData theme) {
    return SizedBox(
      height: 148,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Expanded(
          child: JellyDailyTasksCard(
            tasks: [
              JellyDailyTask(
                name: '写日记',
                progress: '1/1',
                reward: 10,
                leadingIcon: DsIconKind.book,
                leadingColor: theme.secondary,
                done: true,
              ),
              JellyDailyTask(
                name: '喝水打卡',
                progress: '1/2',
                reward: 10,
                leadingIcon: DsIconKind.drop,
                leadingColor: theme.primary,
              ),
              JellyDailyTask(
                name: '记账',
                progress: '3 笔',
                reward: 15,
                leadingIcon: DsIconKind.piggy,
                leadingColor: theme.primary.mixBlack(0.08),
              ),
            ],
            onTaskTap: (_) {},
          ),
        ),
        SizedBox(width: theme.spacing.md),
        Expanded(
          child: JellyGrowthCard(
            exp: 625,
            expMax: 1000,
            nextUnlock: '下一级解锁年度报告',
          ),
        ),
        ],
      ),
    );
  }
}
