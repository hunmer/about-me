import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

/// 展示页分区面板：星标 + 序号标题 + 演示内容
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.index,
    required this.title,
    required this.children,
  });

  final String index;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return DSCard(
      radius: theme.radii.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsIcon(DsIconKind.star, size: 16, color: theme.primary),
              SizedBox(width: theme.spacing.sm),
              Text(
                '$index $title',
                style: DsTypography.title.copyWith(color: theme.text),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.lg),
          ...children,
        ],
      ),
    );
  }
}

/// 单个演示块：小标签 + 内容
class DemoBlock extends StatelessWidget {
  const DemoBlock({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        SizedBox(height: theme.spacing.sm),
        Text(label, style: DsTypography.caption.copyWith(color: theme.textSub)),
      ],
    );
  }
}

/// 演示块横排（自动换行）
class DemoFlow extends StatelessWidget {
  const DemoFlow({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 20,
    this.crossAxisAlignment = WrapCrossAlignment.center,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final WrapCrossAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }
}

/// 分区内小标题
class DemoSubHeader extends StatelessWidget {
  const DemoSubHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.md),
      child: Text(
        text,
        style: DsTypography.heading.copyWith(color: theme.primaryText),
      ),
    );
  }
}
