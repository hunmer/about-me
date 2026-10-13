import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 时间选择组件
///
/// 功能特性：
/// - 点击弹出时间选择器（DS 暂无时间选择器，保留 Material showTimePicker）
/// - DS 果冻风格容器
/// - 显示标签和时间值
class TimePickerField extends StatelessWidget {
  /// 标签文本
  final String label;

  /// 当前时间值
  final TimeOfDay time;

  /// 时间变化的回调
  final ValueChanged<TimeOfDay>? onTimeChanged;

  /// 是否启用
  final bool enabled;

  const TimePickerField({
    super.key,
    required this.label,
    required this.time,
    this.onTimeChanged,
    this.enabled = true,
  });

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _selectTime(BuildContext context) async {
    if (!enabled || onTimeChanged == null) return;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: time,
    );

    if (picked != null) {
      onTimeChanged!(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Pressable(
      onPressed: enabled ? () => _selectTime(context) : null,
      child: JellyBox(
        radius: theme.radii.lg,
        strokeColor: theme.textSub.withValues(alpha: 0.45),
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          children: [
            Text(
              label,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
            SizedBox(height: theme.spacing.xs),
            Text(
              _formatTime(time),
              style: DsTypography.title.copyWith(color: theme.text),
            ),
          ],
        ),
      ),
    );
  }
}
