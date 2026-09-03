import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';

import 'widgets/jelly_daily_tasks_card.dart';
import 'widgets/jelly_growth_card.dart';
import 'widgets/jelly_mood_card.dart';
import 'widgets/jelly_profile_card.dart';
import 'widgets/jelly_quick_action.dart';
import 'widgets/jelly_speech_bubble.dart';
import 'widgets/jelly_stat_card.dart';
import 'widgets/jelly_store_banner.dart';

/// 果冻小屋主页（软糖果冻风布局还原）
///
/// 参考设计稿自上而下：资料卡 + 统计卡 → 对话气泡 → 角色区（占位）+ 心情卡
/// → 快捷操作（写日记/打卡/记账 + 新增键）→ 每日任务 + 成长 → 商店横幅 → 底部导航。
/// 中间 3D 角色素材暂缺，以浅色圆形占位保留布局高度。
///
/// 路由：/jelly_home
class JellyHomeScreen extends StatefulWidget {
  const JellyHomeScreen({super.key});

  @override
  State<JellyHomeScreen> createState() => _JellyHomeScreenState();
}

class _JellyHomeScreenState extends State<JellyHomeScreen> {
  int _navIndex = 0;

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
        child: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, viewport) => SingleChildScrollView(
                    padding:
                        EdgeInsets.symmetric(horizontal: theme.spacing.lg),
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
                              Center(
                                child: JellySpeechBubble(
                                    text: '今天想记录点什么呢？'),
                              ),
                              SizedBox(height: theme.spacing.sm),
                              _buildCharacterArea(theme),
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
            // 底部导航（固定）
            SafeArea(
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
                    DSNavItem(icon: DsIconKind.calendar, label: '日历'),
                    DSNavItem(icon: DsIconKind.chat, label: '对话'),
                    DSNavItem(
                        icon: DsIconKind.store, label: '商店', showBadge: true),
                    DSNavItem(
                        icon: DsIconKind.user, label: '我的', showBadge: true),
                  ],
                  currentIndex: _navIndex,
                  onTap: (i) => setState(() => _navIndex = i),
                ),
              ),
            ),
          ],
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

  /// 中部角色区：3D 角色素材暂缺，先以浅色圆斑占位 + 点缀星星；右侧挂心情卡
  Widget _buildCharacterArea(AppThemeData theme) {
    return SizedBox(
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 角色占位（素材到位后替换）；不用 emoji——Windows 缺字形会渲染成方框
          Center(
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.surface.withValues(alpha: 0.55),
                border: Border.all(
                  color: theme.stroke,
                  width: 2,
                ),
              ),
            ),
          ),
          Positioned(
            left: theme.spacing.xl,
            top: theme.spacing.xs,
            child: DsIcon(
              DsIconKind.star,
              size: 13,
              color: theme.warning.withValues(alpha: 0.8),
            ),
          ),
          Positioned(
            left: theme.spacing.xxxl,
            bottom: theme.spacing.xxxl,
            child: DsIcon(
              DsIconKind.star,
              size: 9,
              color: theme.secondary.withValues(alpha: 0.9),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: JellyMoodCard(
              title: '今日心情',
              emoji: '😊',
              message: '心情超棒！你认真记录的样子真的很闪耀~',
              onAction: () {},
            ),
          ),
        ],
      ),
    );
  }

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
