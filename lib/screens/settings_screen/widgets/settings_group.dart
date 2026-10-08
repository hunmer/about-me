import 'package:flutter/material.dart';

/// 设置分组：可选分组标题 + 圆角卡片包裹的一组设置项
///
/// 参考设计：卡片式列表，组内条目之间以细分隔线隔开，
/// 标题位于卡片外部上方（小号灰字）。
class SettingsGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const SettingsGroup({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> cardChildren = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        cardChildren.add(Divider(
          height: 1,
          thickness: 0.6,
          indent: 56,
          color: theme.dividerColor,
        ));
      }
      cardChildren.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
            child: Text(
              title!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
          ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: cardChildren,
          ),
        ),
      ],
    );
  }
}
