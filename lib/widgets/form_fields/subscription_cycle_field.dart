import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 订阅周期选择器字段
///
/// 手绘分段控件（月度30/季度90/年度365/自定义），选中"自定义"时
/// 在分段控件底部展开天数输入框，选预设项时收起
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

  /// 自定义按钮文本
  final String customLabel;

  const SubscriptionCycleField({
    super.key,
    required this.currentDays,
    required this.onDaysChanged,
    this.enabled = true,
    this.monthlyLabel = '月度',
    this.quarterlyLabel = '季度',
    this.yearlyLabel = '年度',
    this.customLabel = '自定义',
  });

  @override
  State<SubscriptionCycleField> createState() => _SubscriptionCycleFieldState();
}

class _SubscriptionCycleFieldState extends State<SubscriptionCycleField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  /// 是否处于自定义模式（控制底部输入框显隐）
  bool _customMode = false;

  static bool _isPreset(int days) => days == 30 || days == 90 || days >= 360;

  @override
  void initState() {
    super.initState();
    _customMode = !_isPreset(widget.currentDays);
    _controller = TextEditingController(
      text: _customMode ? '${widget.currentDays}' : '',
    );
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(SubscriptionCycleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部值变化（如切换编辑对象）时同步模式与输入框
    if (widget.currentDays != oldWidget.currentDays) {
      final custom = !_isPreset(widget.currentDays);
      final expected = custom ? '${widget.currentDays}' : '';
      if (_controller.text != expected) {
        _controller.text = expected;
      }
      if (_customMode != custom) {
        setState(() => _customMode = custom);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSegmentChanged(int index) {
    if (index == 3) {
      setState(() => _customMode = true);
      // 展开后聚焦，减少一次点击
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.enabled) _focusNode.requestFocus();
      });
      return;
    }
    setState(() => _customMode = false);
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
    // 自定义模式选中第四项，否则按值匹配预设项
    final selectedIndex =
        _customMode
            ? 3
            : switch (widget.currentDays) {
              30 => 0,
              90 => 1,
              _ => 2,
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
              widget.customLabel,
            ],
            selected: selectedIndex,
            onChanged: widget.enabled ? _onSegmentChanged : null,
          ),
          if (_customMode) ...[
            const SizedBox(height: 12),
            DSInput(
              controller: _controller,
              focusNode: _focusNode,
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
        ],
      ),
    );
  }
}
