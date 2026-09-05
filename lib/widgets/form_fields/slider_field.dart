import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 滑块选择组件
///
/// 功能特性：
/// - DS 果冻滑杆（渐变进度 + 星形滑块）
/// - 支持标签和当前值显示
/// - 可配置范围
/// - 可选的快捷值标签
class SliderField extends StatelessWidget {
  /// 标签文本
  final String label;

  /// 当前值显示文本
  final String valueText;

  /// 最小值
  final double min;

  /// 最大值
  final double max;

  /// 当前值
  final double value;

  /// 刻度数量（DSSlider 为连续滑杆，此参数保留以兼容配置）
  final int? divisions;

  /// 值变化的回调
  final ValueChanged<double>? onChanged;

  /// 是否启用
  final bool enabled;

  /// 主题色（默认使用主题 primary 颜色）
  final Color? primaryColor;

  /// 快捷值列表（可选）
  final List<double>? quickValues;

  /// 快捷值标签生成器（可选）
  final String Function(double value)? quickValueLabel;

  /// 快捷值按钮点击回调（可选）
  final ValueChanged<double>? onQuickValueTap;

  const SliderField({
    super.key,
    required this.label,
    required this.valueText,
    required this.min,
    required this.max,
    required this.value,
    this.divisions,
    this.onChanged,
    this.enabled = true,
    this.primaryColor,
    this.quickValues,
    this.quickValueLabel,
    this.onQuickValueTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    final clamped = value.clamp(min, max);
    final ratio = max > min ? (clamped - min) / (max - min) : 0.0;
    final effectiveOnChanged = enabled ? onChanged : null;

    return JellyBox(
      radius: theme.radii.lg,
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和当前值
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
              Text(
                valueText,
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),

          // DSSlider（0.0 ~ 1.0 归一化）
          DSSlider(
            value: ratio,
            activeColor: primaryColor,
            onChanged:
                effectiveOnChanged == null
                    ? null
                    : (r) => effectiveOnChanged(min + r * (max - min)),
          ),

          // 快捷值标签（如果提供）
          if (quickValues != null &&
              quickValues!.isNotEmpty &&
              quickValueLabel != null) ...[
            SizedBox(height: theme.spacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final quickValue in quickValues!)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: DSChip(
                        label: quickValueLabel!(quickValue),
                        selected: (clamped - quickValue).abs() < 0.01,
                        onSelected:
                            enabled && onQuickValueTap != null
                                ? (_) => onQuickValueTap!(quickValue)
                                : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
