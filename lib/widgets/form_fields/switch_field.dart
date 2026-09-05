import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 开关选择组件
///
/// 功能特性：
/// - DS 果冻开关（表情滑块 + カチッ回弹动画）
/// - 支持标签、子标题和图标
/// - 可配置启用状态
/// - 支持 inline 模式（适用于 FormFieldGroup）
class SwitchField extends StatelessWidget {
  /// 当前开关状态
  final bool value;

  /// 值变化的回调
  final ValueChanged<bool>? onChanged;

  /// 标签文本
  final String title;

  /// 子标题文本
  final String? subtitle;

  /// 左侧图标（持久化 IconData，由调用方配置）
  final IconData? icon;

  /// 是否启用
  final bool enabled;

  /// 是否使用inline模式（无边框，适用于 FormFieldGroup）
  final bool inline;

  const SwitchField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.icon,
    this.enabled = true,
    this.inline = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final effectiveOnChanged = enabled ? onChanged : null;

    Widget content = Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: theme.textSub),
          SizedBox(width: theme.spacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: DsTypography.body.copyWith(color: theme.text)),
              if (subtitle != null) ...[
                SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ],
          ),
        ),
        DSSwitch(value: value, onChanged: effectiveOnChanged),
      ],
    );

    // inline 模式：无边框，适用于 FormFieldGroup
    if (inline) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: content,
      );
    }

    // 默认模式：果冻卡片样式
    return JellyBox(
      radius: theme.radii.lg,
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.sm,
      ),
      child: content,
    );
  }
}
