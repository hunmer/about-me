import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

import 'gallery_section.dart';

/// 10 新组件：对标 animal-island-ui 后新增的手绘组件
///
/// 分隔线 / 燕尾旗标 / 数字动效 / 打字机 / 壁纸 /
/// 图片与查看器 / 分页 / 轮播 / 日历 / 抽屉 / 回到顶部。
class NewComponentsSection extends StatefulWidget {
  const NewComponentsSection({super.key});

  @override
  State<NewComponentsSection> createState() => _NewComponentsSectionState();
}

class _NewComponentsSectionState extends State<NewComponentsSection> {
  int _count = 42;
  int _page = 1;
  final _listController = ScrollController();

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return SectionCard(index: '10', title: '新组件', children: [
      const DemoSubHeader('旗标标题与分隔线'),
      DsTitleBanner(text: '今日手帐'),
      SizedBox(height: theme.spacing.md),
      const DSDivider(style: DsDividerStyle.dots),
      SizedBox(height: theme.spacing.sm),
      DSDivider(style: DsDividerStyle.dashed, color: theme.primary),
      SizedBox(height: theme.spacing.sm),
      const DSDivider(style: DsDividerStyle.plain),
      SizedBox(height: theme.spacing.sm),
      const DSDivider(style: DsDividerStyle.dots, label: '带文字的分隔线'),
      SizedBox(height: theme.spacing.lg),

      const DemoSubHeader('数字动效（果冻弹跳 + 墨点扩散）'),
      DemoFlow(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DSButton(
            label: '−',
            size: DSButtonSize.sm,
            onPressed: () => setState(() => _count -= 7),
          ),
          SizedBox(
            width: 120,
            child: Center(
              child: DsCountUp(
                value: _count,
                splash: true,
                style: DsTypography.display.copyWith(color: theme.primary),
              ),
            ),
          ),
          DSButton(
            label: '+',
            size: DSButtonSize.sm,
            onPressed: () => setState(() => _count += 7),
          ),
        ],
      ),
      SizedBox(height: theme.spacing.lg),

      const DemoSubHeader('打字机文本'),
      DsTypewriter(
        text: '你好，我是手绘打字机，一个字一个字地浮现…',
        style: DsTypography.body.copyWith(color: theme.text),
      ),
      SizedBox(height: theme.spacing.lg),

      const DemoSubHeader('壁纸底纹（波点 / 糖霜彩粒 / 网格）'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _wallpaperSample(theme, DsWallpaperPattern.polka, 'polka 波点'),
          SizedBox(height: theme.spacing.sm),
          _wallpaperSample(theme, DsWallpaperPattern.sprinkles, 'sprinkles 糖霜'),
          SizedBox(height: theme.spacing.sm),
          _wallpaperSample(theme, DsWallpaperPattern.grid, 'grid 网格'),
        ],
      ),
      SizedBox(height: theme.spacing.lg),

      const DemoSubHeader('图片与全屏查看器（点击放大）'),
      DemoFlow(
        children: [
          DsImage.asset(
            'assets/images/default_avatar.jpg',
            width: 150,
            height: 96,
            onTap: () => showDsImageViewer(
              context,
              image: const AssetImage('assets/images/default_avatar.jpg'),
            ),
          ),
        ],
      ),
      SizedBox(height: theme.spacing.lg),

      const DemoSubHeader('分页器'),
      DsPagination(
        total: 95,
        current: _page,
        onChanged: (p) => setState(() => _page = p),
      ),
      SizedBox(height: theme.spacing.lg),

      const DemoSubHeader('轮播（可自动播放）'),
      DSCarousel(
        height: 110,
        children: [
          _carouselPage(theme, theme.secondary, '第 1 页'),
          _carouselPage(theme, theme.success, '第 2 页'),
          _carouselPage(theme, theme.warning, '第 3 页'),
        ],
      ),
      SizedBox(height: theme.spacing.lg),

      const DemoSubHeader('日历'),
      DSCalendar(
        initialMonth: DateTime.now(),
        compact: true,
        onSelected: (_) {},
      ),
      SizedBox(height: theme.spacing.lg),

      const DemoSubHeader('抽屉（左滑入 / 底部弹层）'),
      DemoFlow(
        children: [
          DSButton(
            label: '左侧抽屉',
            size: DSButtonSize.sm,
            onPressed: () => showDSDrawer(
              context,
              side: DsDrawerSide.left,
              width: 280,
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  DsTitleBanner(text: '侧边菜单'),
                  DSListItem(title: '手帐本', subtitle: '12 篇'),
                  DSListItem(title: '待办清单', subtitle: '3 项'),
                  DSListItem(title: '设置'),
                ],
              ),
            ),
          ),
          DSButton(
            label: '底部抽屉',
            size: DSButtonSize.sm,
            onPressed: () => showDSDrawer(
              context,
              side: DsDrawerSide.bottom,
              builder: (context) => const DSListItem(title: '底部弹层', subtitle: '高度随内容'),
            ),
          ),
        ],
      ),
      SizedBox(height: theme.spacing.lg),

      const DemoSubHeader('回到顶部（滚动右侧列表）'),
      SizedBox(
        height: 200,
        child: DsBackTop(
          controller: _listController,
          child: ListView.builder(
            controller: _listController,
            itemCount: 40,
            itemBuilder: (context, i) => DSListItem(
              title: '列表项 ${i + 1}',
              subtitle: '滚过 400px 后右下角出现回顶浮钮',
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _wallpaperSample(AppThemeData theme, DsWallpaperPattern p, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsWallpaper(
          pattern: p,
          child: SizedBox(
            height: 64,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _carouselPage(AppThemeData theme, Color color, String label) {
    return JellyBox(
      color: color,
      radius: theme.radii.xl,
      child: Center(
        child: Text(
          label,
          style: DsTypography.heading.copyWith(color: theme.onPrimary),
        ),
      ),
    );
  }
}
