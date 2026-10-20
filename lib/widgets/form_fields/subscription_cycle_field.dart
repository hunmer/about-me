import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 订阅周期选择器字段
///
/// 手绘分段控件（月度30/季度90/年度365）+ 自定义天数输入：
/// 输入非预设天数时分段控件无选中，两端联动互斥
class SubscriptionCycleField extends StatefulWidget {
  /// 当前选中的天数
  final int currentDays;

  /// 天数变化回调
  final ValueChanged<int> onDaysChanged;

  /// 是否启用
  final bool enabled;

  /// 月度按钮文本
  final String monthlyLabel;

  /// 季度按钮文本
  final String quarterlyLabel;

  /// 年度按钮文本
  final String yearlyLabel;

  const SubscriptionCycleField({
    super.key,
    required this.currentDays,
    required this.onDaysChanged,
    this.enabled = true,
    this.monthlyLabel = '月度',
    this.quarterlyLabel = '季度',
    this.yearlyLabel = '年度',
  });

  @override
  State<SubscriptionCycleField> createState() => _SubscriptionCycleFieldState();
}

class _SubscriptionCycleFieldState extends State<SubscriptionCycleField> {
  late final TextEditingController _controller;

  static bool _isPreset(int days) =>
      days == 30 || days == 90 || days >= 360;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _isPreset(widget.currentDays) ? '' : '${widget.currentDays}',
    );
  }

  @override
  void didUpdateWidget(SubscriptionCycleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部值变化（如表单重置）时同步输入框，避免与分段选中态脱节
    if (widget.currentDays != oldWidget.currentDays) {
      final expected = _isPreset(widget.currentDays)
          ? ''
          : '${widget.currentDays}';
      if (_controller.text != expected) {
        _controller.text = expected;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSegmentChanged(int index) {
    // 程序赋值不触发 TextField.onChanged，无循环回调
    _controller.clear();
    widget.onDaysChanged([30, 90, 365][index]);
  }

  void _onInputChanged(String text) {
    final days = int.tryParse(text.trim());
    if (days != null && days > 0) {
      widget.onDaysChanged(days);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 自定义天数（非 30/90/365）时无选中项
    final selectedIndex = switch (widget.currentDays) {
      30 => 0,
      90 => 1,
      _ when widget.currentDays >= 360 => 2,
      _ => -1,
    };
    final theme = DSThemeBridge.resolve(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DSSegmentedControl(
            options: [
              widget.monthlyLabel,
              widget.quarterlyLabel,
              widget.yearlyLabel,
            ],
            selected: selectedIndex,
            onChanged: widget.enabled ? _onSegmentChanged : null,
          ),
          const SizedBox(height: 12),
          DSInput(
            controller: _controller,
            hint: 'app_customDays'.tr,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            onChanged: _onInputChanged,
            suffix: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                'app_daysUnit'.tr,
                style: DsTypography.body.copyWith(color: theme.textSub),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
