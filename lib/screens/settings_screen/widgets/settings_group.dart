import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 设置分组：可选分组标题 + 一组设置条目
///
/// 参考稿风格：标题在容器外，条目收进一张次级底色墨线卡片；
/// 子项应为 [SettingsTile]（粉彩圆形图标 + 扁平行）。
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
            padding: const EdgeInsets.only(left: 4, top: 8, bottom: 10),
            child: Text(
              title!,
              // 参考稿：分组标题为加粗大字（与正文同色）
              style: DsTypography.title.copyWith(color: theme.text),
            ),
          ),
        JellyBox(
          color: theme.surfaceAlt,
          radius: theme.radii.xxl,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: theme.spacing.sm),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
