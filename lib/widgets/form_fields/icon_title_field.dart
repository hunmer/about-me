import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 带图标选择的标题输入组件
///
/// 功能特性：
/// - 左侧可点击的图标选择器（果冻方块）
/// - 右侧标题输入框（编辑原语）
/// - DS 令牌驱动配色
class IconTitleField extends StatelessWidget {
  /// 输入控制器
  final TextEditingController controller;

  /// 当前选择的图标（持久化 IconData）
  final IconData? icon;

  /// 点击图标选择器的回调
  final VoidCallback onIconTap;

  /// 提示文本
  final String hintText;

  /// 文本样式
  final TextStyle? textStyle;

  /// 文本变化回调
  final ValueChanged<String>? onChanged;

  const IconTitleField({
    super.key,
    required this.controller,
    required this.icon,
    required this.onIconTap,
    required this.hintText,
    this.textStyle,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Row(
      children: [
        // 图标选择器（果冻方块）
        Pressable(
          onPressed: onIconTap,
          semanticLabel: '选择图标',
          child: JellyBox(
            width: 56,
            height: 56,
            radius: theme.radii.lg,
            color: theme.primary.mixWhite(0.88),
            alignment: Alignment.center,
            child: Icon(
              icon ?? Icons.assignment,
              color: theme.primaryText,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // 标题输入框（嵌入自绘容器的编辑原语）
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: textStyle ?? DsTypography.title.copyWith(color: theme.text),
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
              hintStyle: DsTypography.title.copyWith(
                color: theme.textSub.withValues(alpha: 0.75),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}
