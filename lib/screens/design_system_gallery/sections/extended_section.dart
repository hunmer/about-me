import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

import 'gallery_section.dart';

/// 08 布局与装饰：Tabs / Accordion / Popover / EmptyState / Skeleton / 分隔线 / 壁纸
class ExtendedSection extends StatefulWidget {
  const ExtendedSection({super.key});

  @override
  State<ExtendedSection> createState() => _ExtendedSectionState();
}

class _ExtendedSectionState extends State<ExtendedSection> {
  int _tabIndex = 0;
  int _swipeTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return SectionCard(
      index: '08',
      title: '布局与装饰',
      children: [
        const DemoSubHeader('标签页（Tabs）'),
        DSTabs(
          labels: const ['动态', '日记', '相册'],
          selected: _tabIndex,
          onChanged: (i) => setState(() => _tabIndex = i),
        ),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('标签页 · 可滑动内容（Tabs + Swipe）'),
        DSTabs(
          labels: const ['动态', '日记', '相册'],
          selected: _swipeTabIndex,
          onChanged: (i) => setState(() => _swipeTabIndex = i),
          contentHeight: 120,
          children: [
            _buildSwipeTabDemoPage('左右滑动或点击标签切换'),
            _buildSwipeTabDemoPage('指示条随拖动实时跟手'),
            _buildSwipeTabDemoPage('最后一页，滑回去吧'),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('手风琴（Accordion）'),
        DSAccordion(
          entries: [
            DSAccordionEntry(
              title: '什么是手绘风？',
              builder:
                  (context) => Text(
                    'claymorphism 立体质感：圆润可爱、顶部高光、白色描边、彩色投影。',
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
            ),
            DSAccordionEntry(
              title: '如何自定义主题？',
              builder:
                  (context) => Text(
                    '替换 AppThemeData 的语义色即可，所有组件样式由令牌派生。',
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
            ),
            DSAccordionEntry(
              title: '支持多开吗？',
              builder:
                  (context) => Text(
                    '设置 multiple: true 即可同时展开多项。',
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const DemoSubHeader('气泡卡（Popover，点击展开）'),
            DSPopover(
              contentBuilder:
                  (context, close) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '更多操作',
                        style: DsTypography.heading.copyWith(
                          color: theme.text,
                        ),
                      ),
                      SizedBox(height: theme.spacing.sm),
                      DSButton(
                        label: '重命名',
                        variant: DSButtonVariant.ghost,
                        size: DSButtonSize.sm,
                        onPressed: () {
                          close();
                          showDSToast(
                            context,
                            message: '已重命名',
                            type: DSToastType.success,
                          );
                        },
                      ),
                      DSButton(
                        label: '删除',
                        variant: DSButtonVariant.destructive,
                        size: DSButtonSize.sm,
                        onPressed: () {
                          close();
                          showDSToast(context, message: '已删除');
                        },
                      ),
                    ],
                  ),
              child: IgnorePointer(
                // 按钮仅作视觉载体：内层手势会抢走点击，触发交给外层气泡
                child: DSButton(
                  label: '更多操作',
                  variant: DSButtonVariant.outline,
                  size: DSButtonSize.sm,
                  onPressed: () {},
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('空状态（Empty State）'),
        Center(
          child: DSEmptyState(
            emoji: '🐰',
            title: '还没有记录哦',
            message: '快去记录你的第一笔吧~',
            actionLabel: '立即记录',
            onAction:
                () => showDSToast(
                  context,
                  message: '去记录啦',
                  type: DSToastType.info,
                ),
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('骨架屏（Skeleton）'),
        const DSSkeletonListItem(),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('骨架屏预设（带斜向流光）'),
        DemoFlow(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const SizedBox(width: 200, child: SkeletonParagraph(lines: 3)),
            const SkeletonButton(width: 140),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('旗标标题与分隔线'),
        const DsTitleBanner(text: '今日手帐'),
        SizedBox(height: theme.spacing.md),
        const DSDivider(style: DsDividerStyle.dots),
        SizedBox(height: theme.spacing.sm),
        DSDivider(style: DsDividerStyle.dashed, color: theme.primary),
        SizedBox(height: theme.spacing.sm),
        const DSDivider(style: DsDividerStyle.plain),
        SizedBox(height: theme.spacing.sm),
        const DSDivider(style: DsDividerStyle.dots, label: '带文字的分隔线'),
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
      ],
    );
  }

  Widget _wallpaperSample(AppThemeData theme, DsWallpaperPattern p, String label) {
    return DsWallpaper(
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
    );
  }

  Widget _buildSwipeTabDemoPage(String text) {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: theme.surfaceAlt,
            radius: theme.radii.md,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: DsTypography.body.copyWith(color: theme.textSub),
          ),
        );
      },
    );
  }
}
