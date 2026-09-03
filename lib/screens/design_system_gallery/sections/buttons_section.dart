import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';

import 'gallery_section.dart';

/// 01 按钮
class ButtonsSection extends StatelessWidget {
  const ButtonsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: '01',
      title: '按钮',
      children: [
        DemoFlow(
          children: [
            DemoBlock(
              label: '主按钮',
              child: DSButton(
                label: '开始游戏',
                onPressed: () {},
              ),
            ),
            DemoBlock(
              label: '次要按钮',
              child: DSButton(
                label: '查看更多',
                variant: DSButtonVariant.outline,
                onPressed: () {},
              ),
            ),
            DemoBlock(
              label: '辅助色按钮',
              child: DSButton(
                label: '开始游戏',
                variant: DSButtonVariant.secondary,
                onPressed: () {},
              ),
            ),
            DemoBlock(
              label: '危险操作',
              child: DSButton(
                label: '删除记录',
                variant: DSButtonVariant.destructive,
                onPressed: () {},
              ),
            ),
            DemoBlock(
              label: '幽灵按钮',
              child: DSButton(
                label: '稍后再说',
                variant: DSButtonVariant.ghost,
                onPressed: () {},
              ),
            ),
          ],
        ),
        SizedBox(height: AppTheme.of(context).spacing.lg),
        DemoFlow(
          children: [
            DemoBlock(
              label: '图标按钮',
              child: DSIconButton(icon: DsIconKind.heart, onPressed: () {}),
            ),
            DemoBlock(
              label: '图标按钮',
              child: DSIconButton(icon: DsIconKind.gear, onPressed: () {}),
            ),
            DemoBlock(
              label: '悬浮按钮',
              child: DSFab(onPressed: () {}),
            ),
          ],
        ),
        SizedBox(height: AppTheme.of(context).spacing.lg),
        DemoFlow(
          children: [
            DemoBlock(
              label: '禁用态',
              child: DSButton(
                label: '开始游戏',
                onPressed: null,
              ),
            ),
            DemoBlock(
              label: '禁用态',
              child: DSButton(
                label: '查看更多',
                variant: DSButtonVariant.outline,
                onPressed: null,
              ),
            ),
            DemoBlock(
              label: '禁用态',
              child: DSIconButton(icon: DsIconKind.heart, onPressed: null),
            ),
            DemoBlock(
              label: '禁用态',
              child: DSFab(onPressed: null),
            ),
          ],
        ),
      ],
    );
  }
}
