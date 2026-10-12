import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 手风琴条目数据
class DSAccordionEntry {
  const DSAccordionEntry({required this.title, required this.builder});

  final String title;
  final WidgetBuilder builder;
}

/// 手绘手风琴：默认单开模式，[multiple] 为 true 时可多开
class DSAccordion extends StatefulWidget {
  const DSAccordion({
    super.key,
    required this.entries,
    this.multiple = false,
    this.initialExpanded = const [0],
  });

  final List<DSAccordionEntry> entries;
  final bool multiple;

  /// 初始展开的下标
  final List<int> initialExpanded;

  @override
  State<DSAccordion> createState() => _DSAccordionState();
}

class _DSAccordionState extends State<DSAccordion> {
  late final Set<int> _expanded = widget.initialExpanded.toSet();

  void _toggle(int index) {
    setState(() {
      if (_expanded.contains(index)) {
        _expanded.remove(index);
      } else {
        if (!widget.multiple) _expanded.clear();
        _expanded.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.entries.length; i++) ...[
          if (i > 0) SizedBox(height: theme.spacing.sm),
          _AccordionItem(
            entry: widget.entries[i],
            expanded: _expanded.contains(i),
            onToggle: () => _toggle(i),
          ),
        ],
      ],
    );
  }
}

class _AccordionItem extends StatelessWidget {
  const _AccordionItem({
    required this.entry,
    required this.expanded,
    required this.onToggle,
  });

  final DSAccordionEntry entry;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return JellyBox(
      radius: theme.radii.lg,
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题行
          Pressable(
            onPressed: onToggle,
            builder: (context, states) {
              final hovered = states.contains(WidgetState.hovered);
              return Container(
                color: hovered
                    ? theme.surfaceAlt.withValues(alpha: 0.4)
                    : DsColors.transparent,
                padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        style: DsTypography.body
                            .copyWith(color: theme.text),
                      ),
                    ),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: expanded ? 0.5 : 0,
                      child: DsIcon(
                        DsIconKind.chevronDown,
                        size: 18,
                        color: theme.primary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // 内容（高度动画展开，展开挂载时墨线描画入场）
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? WiredDraw(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: theme.spacing.md),
                      child: entry.builder(context),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
