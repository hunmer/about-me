import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';

/// 手绘滑杆：skribble WiredSlider
///
/// 内部委托 [WiredSlider]（手绘轨道 + 墨线滑块，跟随全局 Ink style
/// 档位）；[activeColor] 经 [DsInkScope] 映射到 Wired 主题的标记色。
/// [onChangeEnd] 通过 Pointer 监听桥接（WiredSlider 无该参数）。
class DSSlider extends StatefulWidget {
  const DSSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.activeColor,
  });

  /// 0.0 ~ 1.0
  final double value;
  final ValueChanged<double>? onChanged;

  /// 拖动/点击结束时触发（值已在结束时经由 [onChanged] 更新）
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;

  @override
  State<DSSlider> createState() => _DSSliderState();
}

class _DSSliderState extends State<DSSlider> {
  double? _pendingValue;

  void _end() {
    final v = _pendingValue;
    if (v != null) {
      _pendingValue = null;
      widget.onChangeEnd?.call(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final color = widget.activeColor ?? theme.primary;
    final value = widget.value.clamp(0.0, 1.0);
    final disabled = widget.onChanged == null;

    return Semantics(
      slider: true,
      value: '${(value * 100).round()}%',
      increasedValue: '${((value + 0.1).clamp(0.0, 1.0) * 100).round()}%',
      decreasedValue: '${((value - 0.1).clamp(0.0, 1.0) * 100).round()}%',
      onIncrease: disabled
          ? null
          : () {
              final v = (value + 0.1).clamp(0.0, 1.0);
              widget.onChanged?.call(v);
              widget.onChangeEnd?.call(v);
            },
      onDecrease: disabled
          ? null
          : () {
              final v = (value - 0.1).clamp(0.0, 1.0);
              widget.onChanged?.call(v);
              widget.onChangeEnd?.call(v);
            },
      child: DsInkScope(
        marker: color,
        child: Listener(
          // WiredSlider 无 onChangeEnd 参数：指针抬起/取消即视为结束
          onPointerUp: (_) => _end(),
          onPointerCancel: (_) => _end(),
          child: WiredSlider(
            value: value,
            // 受控协议：返回 true 表示接受变更
            onChanged: disabled
                ? null
                : (v) {
                    _pendingValue = v;
                    widget.onChanged?.call(v);
                    return true;
                  },
          ),
        ),
      ),
    );
  }
}

/// 带百分比标签的滑杆（展示用组合）
class DSSliderWithLabel extends StatelessWidget {
  const DSSliderWithLabel({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DSSlider(value: value, onChanged: onChanged),
        SizedBox(height: theme.spacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${(value * 100).round()}%',
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ),
      ],
    );
  }
}
