import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';

import 'gallery_section.dart';

/// 08 扩展组件：Tabs / Accordion / Combobox / Popover / EmptyState / Skeleton
class ExtendedSection extends StatefulWidget {
  const ExtendedSection({super.key});

  @override
  State<ExtendedSection> createState() => _ExtendedSectionState();
}

class _ExtendedSectionState extends State<ExtendedSection> {
  int _tabIndex = 0;
  String? _comboValue;

  static const _comboOptions = ['布丁', '软糖', '果冻', '奶昔', '雪糕', '冰沙'];

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SectionCard(
      index: '08',
      title: '扩展组件',
      children: [
        const DemoSubHeader('标签页（Tabs）'),
        DSTabs(
          labels: const ['动态', '日记', '相册'],
          selected: _tabIndex,
          onChanged: (i) => setState(() => _tabIndex = i),
        ),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('手风琴（Accordion）'),
        DSAccordion(
          entries: [
            DSAccordionEntry(
              title: '什么是软糖果冻风？',
              builder: (context) => Text(
                'claymorphism 立体质感：圆润可爱、顶部高光、白色描边、彩色投影。',
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ),
            DSAccordionEntry(
              title: '如何自定义主题？',
              builder: (context) => Text(
                '替换 AppThemeData 的语义色即可，所有组件样式由令牌派生。',
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ),
            DSAccordionEntry(
              title: '支持多开吗？',
              builder: (context) => Text(
                '设置 multiple: true 即可同时展开多项。',
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
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
                const DemoSubHeader('可搜索下拉（Combobox）'),
                DSCombobox<String>(
                  width: 200,
                  hint: '选一个甜品',
                  value: _comboValue,
                  items: [
                    for (final option in _comboOptions)
                      DSSelectItem(label: option, value: option),
                  ],
                  onChanged: (v) => setState(() => _comboValue = v),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const DemoSubHeader('气泡卡（Popover，点击展开）'),
                DSPopover(
                  contentBuilder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '更多操作',
                        style: DsTypography.heading
                            .copyWith(color: theme.text),
                      ),
                      SizedBox(height: theme.spacing.sm),
                      DSButton(
                        label: '重命名',
                        variant: DSButtonVariant.ghost,
                        size: DSButtonSize.sm,
                        onPressed: () => showDSToast(
                          context,
                          message: '已重命名',
                          type: DSToastType.success,
                        ),
                      ),
                      DSButton(
                        label: '删除',
                        variant: DSButtonVariant.destructive,
                        size: DSButtonSize.sm,
                        onPressed: () =>
                            showDSToast(context, message: '已删除'),
                      ),
                    ],
                  ),
                  child: DSButton(
                    label: '更多操作',
                    variant: DSButtonVariant.outline,
                    size: DSButtonSize.sm,
                    onPressed: () {},
                  ),
                ),
              ],
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
            onAction: () => showDSToast(
              context,
              message: '去记录啦',
              type: DSToastType.info,
            ),
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('骨架屏（Skeleton）'),
        const DSSkeletonListItem(),
      ],
    );
  }
}
