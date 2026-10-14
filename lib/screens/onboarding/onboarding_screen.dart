import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart' show dsScaffoldBackground;
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/route.dart';

/// 引导页（onboarding）
///
/// 三页滑动介绍应用核心功能：管理日常习惯 / 与好友比拼 / 挑战自我。
/// 插图暂以图标占位，后续替换为设计稿插画。
///
/// 路由：/onboarding（首次启动作为 initialRoute 展示）；
/// 走完最后一页后写入 `onboardingCompleted` 配置并进入果冻小屋。
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const int _pageCount = 3;

  /// 完成引导：记录标记并替换为果冻小屋，避免返回键回到引导页
  Future<void> _finish() async {
    await globalConfigManager.setAppConfigValue('onboardingCompleted', true);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.jellyHome,
      (route) => false,
    );
  }

  void _next() {
    if (_index >= _pageCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_OnboardingPage> _pages(AppThemeData theme) => [
        _OnboardingPage(
          icon: DsIconKind.clipboard,
          badge: DsIconKind.check,
          tint: theme.secondary,
          title: 'app_onboarding_habitsTitle'.tr,
          description: 'app_onboarding_habitsDesc'.tr,
        ),
        _OnboardingPage(
          icon: DsIconKind.mood,
          badge: DsIconKind.heart,
          tint: theme.success,
          title: 'app_onboarding_competeTitle'.tr,
          description: 'app_onboarding_competeDesc'.tr,
        ),
        _OnboardingPage(
          icon: DsIconKind.star,
          badge: DsIconKind.calendarCheck,
          tint: theme.warning,
          title: 'app_onboarding_challengeTitle'.tr,
          description: 'app_onboarding_challengeDesc'.tr,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final pages = _pages(theme);
    final isLast = _index >= _pageCount - 1;

    return Scaffold(
      backgroundColor: dsScaffoldBackground(theme),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.backgroundAlt, theme.background],
          ),
        ),
        child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pageCount,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) =>
                    _buildPage(context, theme, pages[index]),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.xl,
                theme.spacing.sm,
                theme.spacing.xl,
                theme.spacing.xl,
              ),
              child: DSButton(
                label: isLast
                    ? 'app_onboarding_getStarted'.tr
                    : 'app_onboarding_next'.tr,
                variant: DSButtonVariant.secondary,
                size: DSButtonSize.lg,
                expand: true,
                onPressed: _next,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// 单页内容：图标占位插图 → 指示器 → 标题 → 描述
  Widget _buildPage(
    BuildContext context,
    AppThemeData theme,
    _OnboardingPage page,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIllustration(theme, page),
          SizedBox(height: theme.spacing.xxxl),
          DSPageIndicator(count: _pageCount, index: _index),
          SizedBox(height: theme.spacing.xxl),
          Text(
            page.title,
            style: DsTypography.display.copyWith(color: theme.text),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: theme.spacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              page.description,
              style: DsTypography.body.copyWith(
                color: theme.textSub,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// 插图占位：大果冻圆 + 图标，周围点缀两个白色小圆徽章；
  /// 后续整体替换为插画图片
  Widget _buildIllustration(AppThemeData theme, _OnboardingPage page) {
    return SizedBox(
      width: 280,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            right: 28,
            child: _satellite(theme, page.badge, theme.primary, 56),
          ),
          Positioned(
            bottom: 6,
            left: 22,
            child: _satellite(theme, page.icon, page.tint, 46),
          ),
          JellyBox(
            width: 180,
            height: 180,
            radius: theme.radii.circle,
            color: page.tint,
            child: DsIcon(page.icon, size: 84, color: DsColors.white),
          ),
        ],
      ),
    );
  }

  /// 白色小圆徽章（点缀）
  Widget _satellite(AppThemeData theme, DsIconKind icon, Color color, double size) {
    return JellyBox(
      width: size,
      height: size,
      radius: theme.radii.circle,
      child: DsIcon(icon, size: size * 0.5, color: color),
    );
  }
}

/// 引导页单页数据
class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.badge,
    required this.tint,
    required this.title,
    required this.description,
  });

  /// 主图标（插图占位）
  final DsIconKind icon;

  /// 点缀徽章图标
  final DsIconKind badge;

  /// 插图底色
  final Color tint;
  final String title;
  final String description;
}
