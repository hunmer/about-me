import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

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
              child: DSButton(label: '开始游戏', onPressed: () {}),
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
        SizedBox(height: DSThemeBridge.resolve(context).spacing.lg),
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
            DemoBlock(label: '悬浮按钮', child: DSFab(onPressed: () {})),
          ],
        ),
        SizedBox(height: DSThemeBridge.resolve(context).spacing.lg),
        DemoFlow(
          children: [
            DemoBlock(
              label: '禁用态',
              child: DSButton(label: '开始游戏', onPressed: null),
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
            DemoBlock(label: '禁用态', child: DSFab(onPressed: null)),
          ],
        ),
        SizedBox(height: DSThemeBridge.resolve(context).spacing.lg),
        const DemoSubHeader('新状态（loading / 虚线，实底类按压有错位阴影手感）'),
        DemoFlow(
          children: [
            DemoBlock(
              label: 'loading 态',
              child: DSButton(label: '保存中', loading: true, onPressed: () {}),
            ),
            DemoBlock(
              label: '虚线 dashed',
              child: DSButton(
                label: '添加习惯',
                variant: DSButtonVariant.dashed,
                onPressed: () {},
              ),
            ),
            DemoBlock(
              label: '危险 loading',
              child: DSButton(
                label: '删除中',
                variant: DSButtonVariant.destructive,
                loading: true,
                onPressed: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}
