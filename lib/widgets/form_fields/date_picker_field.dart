import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 日期选择组件
///
/// 功能特性：
/// - 点击弹出日期选择器
/// - 显示格式化的日期
/// - DS 果冻风格容器
/// - 支持 inline 模式（label在左，日期在右）
class DatePickerField extends StatelessWidget {
  /// 日期值（null表示未选择）
  final DateTime? date;

  /// 日期选择器的回调
  final VoidCallback onTap;

  /// 日期格式化字符串
  final String formattedDate;

  /// 占位符文本
  final String placeholder;

  /// 左侧图标（持久化 IconData，由调用方配置）
  final IconData icon;

  /// 标签文本（inline模式使用）
  final String? labelText;

  /// 是否使用inline模式（label在左，日期在右）
  final bool inline;

  /// inline模式下label的宽度
  final double labelWidth;

  const DatePickerField({
    super.key,
    required this.date,
    required this.onTap,
    required this.formattedDate,
    required this.placeholder,
    this.icon = Icons.calendar_today_outlined,
    this.labelText,
    this.inline = false,
    this.labelWidth = 100,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    // inline 模式：label 在左，日期在右
    if (inline) {
      return Pressable(
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  labelText ?? '',
                  style: DsTypography.body.copyWith(color: theme.text),
                ),
              ),
              Text(
                formattedDate.isEmpty ? placeholder : formattedDate,
                style: DsTypography.body.copyWith(color: theme.textSub),
              ),
            ],
          ),
        ),
      );
    }

    // 默认模式：果冻卡片样式
    return Pressable(
      onPressed: onTap,
      semanticLabel: formattedDate.isEmpty ? placeholder : formattedDate,
      child: JellyBox(
        height: 50,
        radius: theme.radii.lg,
        padding: EdgeInsets.only(
          left: theme.spacing.md,
          right: theme.spacing.lg,
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.textSub, size: 20),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Text(
                formattedDate.isEmpty ? placeholder : formattedDate,
                style: DsTypography.body.copyWith(
                  color: formattedDate.isEmpty ? theme.textSub : theme.text,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DsIcon(DsIconKind.chevronDown, size: 18, color: theme.primary),
          ],
        ),
      ),
    );
  }
}
