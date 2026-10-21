import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

import 'gallery_section.dart';

/// 09 新变种：animal-island-ui 对标后补充的变种能力
///
/// Chip 变种 × 强调色、彩色/波点卡片、按钮 loading/虚线、
/// 输入框尺寸、开关 loading、头像组、骨架屏预设、
/// Toast 四方向、Tooltip 双变种、键盘焦点环。
class VariantsSection extends StatefulWidget {
  const VariantsSection({super.key});

  @override
  State<VariantsSection> createState() => _VariantsSectionState();
}

class _VariantsSectionState extends State<VariantsSection> {
  /// chip 选中集合（label 唯一），切换时可看到弹跳动效
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return SectionCard(index: '09', title: '新变种', children: [
      const DemoSubHeader('Chip 四变种 × 强调色（点击切换选中）'),
      DemoFlow(
        children: [
          for (final v in DsChipVariant.values)
            DSChip(
              label: v.name,
              icon: DsIconKind.heart,
              variant: v,
              accent: DsAccentColors.teal,
              selected: _selected.contains('${v.name}-teal'),
              onSelected: (_) => setState(
                () => _toggle('${v.name}-teal'),
              ),
            ),
        ],
      ),
      SizedBox(height: theme.spacing.md),
      DemoFlow(
        children: [
          for (final v in DsChipVariant.values)
            DSChip(
              label: v.name,
              icon: DsIconKind.star,
              variant: v,
              accent: DsAccentColors.pink,
              selected: _selected.contains('${v.name}-pink'),
              onSelected: (_) => setState(
                () => _toggle('${v.name}-pink'),
              ),
            ),
        ],
      ),
      SizedBox(height: theme.spacing.md),
      DemoFlow(
        children: [
          // 不传 accent：回落语义色（与旧外观一致）
          for (final v in DsChipVariant.values)
            DSChip(
              label: v.name,
              variant: v,
              selected: _selected.contains(v.name),
              onSelected: (_) => setState(() => _toggle(v.name)),
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

      const DemoSubHeader('按钮新状态（实底类按压有错位阴影手感）'),
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
      SizedBox(height: theme.spacing.lg),

      const DemoSubHeader('输入框尺寸'),
      DemoFlow(
        children: [
          SizedBox(
            width: 180,
            child: DSInput(hint: 'sm 小号', size: DsInputSize.sm),
          ),
          SizedBox(
            width: 200,
            child: DSInput(hint: 'md 默认', size: DsInputSize.md),
          ),
          SizedBox(
            width: 220,
            child: DSInput(hint: 'lg 大号', size: DsInputSize.lg),
          ),
        ],
      ),
      SizedBox(height: theme.spacing.lg),

      const DemoSubHeader('开关 loading · 头像贴纸与堆叠'),
      DemoFlow(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DemoBlock(
            label: 'loading',
            child: DSSwitch(
              value: true,
              loading: true,
              onChanged: (_) {},
            ),
          ),
          const SizedBox(width: 8),
          DSAvatar(label: '糖', size: 44, peel: true),
          const SizedBox(width: 12),
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

      const DemoSubHeader('骨架屏预设（带斜向流光）'),
      DemoFlow(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const SizedBox(width: 200, child: SkeletonParagraph(lines: 3)),
          const SkeletonButton(width: 140),
        ],
      ),
      SizedBox(height: theme.spacing.lg),

      const DemoSubHeader('Toast 四方向入场（点击触发）'),
      DemoFlow(
        children: [
          for (final (label, from) in [
            ('从底部', DSToastFrom.bottom),
            ('从顶部', DSToastFrom.top),
            ('从左侧', DSToastFrom.left),
            ('从右侧', DSToastFrom.right),
          ])
            DSButton(
              label: label,
              size: DSButtonSize.sm,
              onPressed: () => showDSToast(
                context,
                message: label,
                type: DSToastType.info,
                from: from,
              ),
            ),
        ],
      ),
      SizedBox(height: theme.spacing.lg),

      const DemoSubHeader('Tooltip 双变种（悬停查看）'),
      DemoFlow(
        children: [
          DSTooltip(
            message: '主色实底气泡',
            child: DSIconButton(icon: DsIconKind.star, onPressed: () {}),
          ),
          DSTooltip(
            message: '纸底墨线气泡',
            variant: DsTooltipVariant.paper,
            child: DSIconButton(icon: DsIconKind.heart, onPressed: () {}),
          ),
        ],
      ),
      SizedBox(height: theme.spacing.lg),

      const DemoSubHeader('键盘焦点环（Tab 聚焦下列控件）'),
      DemoFlow(
        children: [
          DSButton(label: '聚焦我看虚线环', onPressed: () {}),
          DSIconButton(icon: DsIconKind.gear, onPressed: () {}),
        ],
      ),
    ]);
  }

  void _toggle(String key) {
    if (!_selected.remove(key)) _selected.add(key);
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
}
