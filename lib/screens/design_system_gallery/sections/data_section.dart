import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';

import 'gallery_section.dart';

/// 05 数据展示
class DataSection extends StatefulWidget {
  const DataSection({super.key});

  @override
  State<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<DataSection> {
  double _rating = 3;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
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
                              style: DsTypography.heading
                                  .copyWith(color: theme.text),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: theme.spacing.sm),
                      Text(
                        '记录今天的美好瞬间',
                        style: DsTypography.caption
                            .copyWith(color: theme.textSub),
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
                              style: DsTypography.label
                                  .copyWith(color: theme.textSub),
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
                    DSIconBadge(
                      icon: DsIconKind.bell,
                      count: 3,
                      size: 26,
                    ),
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
                      style: DsTypography.caption
                          .copyWith(color: theme.textSub),
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
      ],
    );
  }
}
