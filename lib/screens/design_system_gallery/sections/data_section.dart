import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

import 'gallery_section.dart';

/// 05 数据展示
class DataSection extends StatefulWidget {
  const DataSection({super.key});

  @override
  State<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<DataSection> {
  double _rating = 3;
  int _count = 42;
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return SectionCard(
      index: '05',
      title: '数据展示',
      children: [
        Wrap(
          spacing: theme.spacing.lg,
          runSpacing: theme.spacing.lg,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            // 卡片
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const DemoSubHeader('卡片（Card）'),
                SizedBox(
                  width: 180,
                  child: DSCard(
                    onTap: () {},
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('🐰', style: TextStyle(fontSize: 30)),
                            SizedBox(width: theme.spacing.md),
                            Expanded(
                              child: Text(
                                '每日心情',
                                style: DsTypography.heading.copyWith(
                                  color: theme.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: theme.spacing.sm),
                        Text(
                          '记录今天的美好瞬间',
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // 列表项
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const DemoSubHeader('列表项（List Item）'),
                SizedBox(
                  width: 280,
                  child: Column(
                    children: [
                      DSListItem(
                        title: '喝水提醒',
                        subtitle: '每天8杯水，身体棒棒',
                        trailingText: '10:30',
                        leading: DSAvatar(
                          size: 40,
                          label: '💧',
                          color: theme.primary,
                        ),
                        onTap: () {},
                      ),
                      SizedBox(height: theme.spacing.sm),
                      DSListItem(
                        title: '晨间运动',
                        subtitle: '活力一整天',
                        trailingText: '已完成',
                        leading: DSAvatar(
                          size: 40,
                          label: '🏃',
                          color: theme.secondary,
                        ),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 头像
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const DemoSubHeader('头像（Avatar）'),
                Row(
                  children: [
                    for (final (label, size) in const [
                      ('🐹', 24.0),
                      ('🐱', 48.0),
                      ('🐵', 72.0),
                    ])
                      Padding(
                        padding: EdgeInsets.only(right: theme.spacing.md),
                        child: Column(
                          children: [
                            DSAvatar(label: label, size: size),
                            SizedBox(height: theme.spacing.xs),
                            Text(
                              '${size.round()}px',
                              style: DsTypography.label.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        Wrap(
          spacing: theme.spacing.xl,
          runSpacing: theme.spacing.lg,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const DemoSubHeader('徽标与角标'),
                Row(
                  children: [
                    DSIconBadge(icon: DsIconKind.bell, count: 3, size: 26),
                    SizedBox(width: theme.spacing.lg),
                    DSBadge(label: '新功能'),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const DemoSubHeader('进度条（Linear）'),
                SizedBox(
                  width: 240,
                  child: DSLinearProgress(
                    value: 0.75,
                    thumb: DsIcon(
                      DsIconKind.star,
                      size: 26,
                      color: theme.warning,
                    ),
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
                SizedBox(
                  width: 240,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '75%',
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const DemoSubHeader('环形进度'),
                const DSRingProgressLabeled(
                  value: 6 / 8,
                  label: '6/8',
                  subLabel: '打卡',
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('星级评分'),
        Row(
          children: [
            DSRating(
              value: _rating,
              onChanged: (v) => setState(() => _rating = v),
            ),
            SizedBox(width: theme.spacing.md),
            Text(
              '${_rating.round()}/5',
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('彩色卡片 accent × 波点 pattern'),
        DemoFlow(
          children: [
            _accentCard(theme, DsAccentColors.teal, '青柠卡', pattern: false),
            _accentCard(theme, DsAccentColors.pink, '波点粉卡', pattern: true),
            _accentCard(theme, null, '纸底波点', pattern: true),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('头像贴纸与堆叠'),
        DemoFlow(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DSAvatar(label: '糖', size: 44, peel: true),
            DSAvatarStack(
              radius: 16,
              avatars: [
                for (final name in ['糖', '盐', '醋', '茶', '米', '豆'])
                  DSAvatar(label: name, size: 32),
              ],
            ),
          ],
        ),
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
      ],
    );
  }

  Widget _accentCard(
    AppThemeData theme,
    Color? accent,
    String title, {
    required bool pattern,
  }) {
    return SizedBox(
      width: 168,
      child: DSCard(
        accent: accent,
        pattern: pattern,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: DsTypography.heading.copyWith(
                color: accent?.mixBlack(0.25) ?? theme.text,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            Text(
              'accent 与 pattern 可自由组合',
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
        ),
      ),
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
