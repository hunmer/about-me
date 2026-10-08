import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 设置分组：可选分组标题 + 一组 DS 风格列表项
///
/// 子项应为 [DSListItem]（自带半透明描边面板与按压反馈），
/// 组内条目之间以主题小间距排列。
class SettingsGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const SettingsGroup({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8),
            child: Text(
              title!,
              style: DsTypography.caption.copyWith(
                color: theme.textSub,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: theme.spacing.sm),
          children[i],
        ],
      ],
    );
  }
}
