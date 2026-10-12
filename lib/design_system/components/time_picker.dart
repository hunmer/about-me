import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../tokens/sketch.dart';
import '../tokens/typography.dart';
import 'button.dart';
import 'dialog.dart';
import 'segmented_control.dart';

/// 手绘时间选择器：时/分双滚轮 + 手绘选中带
///
/// 纸面滚轮本体 + 中央手绘胶囊选中带（实底 + 墨线描边），
/// 字体走 [DsTypography] 手写体，颜色一律取主题。
/// [use24Hour] 为 false 时小时轮显示 1-12 并附 AM/PM 分段切换。
class DSTimePicker extends StatefulWidget {
  const DSTimePicker({
    super.key,
    required this.initialTime,
    this.onChanged,
    this.itemExtent = 44,
    this.visibleRowCount = 5,
    this.use24Hour = true,
  });

  final TimeOfDay initialTime;

  final ValueChanged<TimeOfDay>? onChanged;

  /// 单行高度（也是选中带高度）
  final double itemExtent;

  /// 可见行数（滚轮总高 = itemExtent × visibleRowCount）
  final int visibleRowCount;

  /// 24 小时制（true：0-23；false：1-12 + AM/PM）
  final bool use24Hour;

  @override
  State<DSTimePicker> createState() => _DSTimePickerState();
}

class _DSTimePickerState extends State<DSTimePicker> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  /// 始终以 0-23 记录小时（12h 制仅影响显示与交互）
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(
      initialItem:
          widget.use24Hour ? _hour : _hour12Of(widget.initialTime) - 1,
    );
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  bool get _isPm => _hour >= 12;

  /// 12h 制显示值（1-12）
  int get _hour12 => _hour % 12 == 0 ? 12 : _hour % 12;

  void _notify() {
    widget.onChanged?.call(TimeOfDay(hour: _hour, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final wheels = _buildWheels(theme);

    if (widget.use24Hour) return wheels;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 160,
          child: DSSegmentedControl(
            options: const ['AM', 'PM'],
            selected: _isPm ? 1 : 0,
            onChanged: (index) {
              setState(() {
                final pm = index == 1;
                _hour =
                    pm
                        ? (_hour < 12 ? _hour + 12 : _hour)
                        : (_hour >= 12 ? _hour - 12 : _hour);
              });
              _notify();
            },
          ),
        ),
        SizedBox(height: theme.spacing.md),
        wheels,
      ],
    );
  }

  Widget _buildWheels(AppThemeData theme) {
    final height = widget.itemExtent * widget.visibleRowCount;
    final use24 = widget.use24Hour;

    Widget wheel({
      required FixedExtentScrollController controller,
      required int itemCount,
      required int currentItem,
      required ValueChanged<int> onSelected,
      required String Function(int) label,
    }) {
      return Expanded(
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: widget.itemExtent,
          diameterRatio: 1.2,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onSelected,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: itemCount,
            builder: (context, index) {
              final selected = index == currentItem;
              return Center(
                child: Text(
                  label(index),
                  style: DsTypography.heading.copyWith(
                    color:
                        selected
                            ? theme.text
                            : theme.textSub.withValues(alpha: 0.5),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // 选中带：手绘胶囊（纸色实底 + 墨线描边）
          Center(
            child: IgnorePointer(
              child: Container(
                height: widget.itemExtent,
                decoration: dsSketchDecoration(
                  theme: theme,
                  fillColor: theme.surfaceAlt,
                  stroke: theme.ink.withValues(alpha: 0.35),
                  strokeWidth: 1.2,
                  radius: theme.radii.pill,
                  seed: 7,
                ),
              ),
            ),
          ),
          Row(
            children: [
              wheel(
                controller: _hourController,
                itemCount: use24 ? 24 : 12,
                currentItem: use24 ? _hour : _hour12 - 1,
                onSelected: (index) {
                  setState(() {
                    if (use24) {
                      _hour = index;
                    } else {
                      // 1-12 显示值 → 0-23 实际值
                      final h12 = index + 1;
                      _hour =
                          _isPm
                              ? (h12 == 12 ? 12 : h12 + 12)
                              : (h12 == 12 ? 0 : h12);
                    }
                  });
                  _notify();
                },
                label:
                    use24
                        ? (h) => h.toString().padLeft(2, '0')
                        : (index) => '${index + 1}',
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
                child: Text(
                  ':',
                  style: DsTypography.heading.copyWith(color: theme.text),
                ),
              ),
              wheel(
                controller: _minuteController,
                itemCount: 60,
                currentItem: _minute,
                onSelected: (value) {
                  setState(() => _minute = value);
                  _notify();
                },
                label: (m) => m.toString().padLeft(2, '0'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static int _hour12Of(TimeOfDay time) =>
      time.hour % 12 == 0 ? 12 : time.hour % 12;
}

/// 便捷时间选择对话框：DSTimePicker + 取消/确认
///
/// [cancelText]/[confirmText] 未传时用内置默认（与 [showDSDatePickerDialog]
/// 一致），需要本地化时由调用方注入。
Future<TimeOfDay?> showDSTimePickerDialog({
  required BuildContext context,
  TimeOfDay? initial,
  bool use24Hour = true,
  String? cancelText,
  String? confirmText,
  AppThemeData? theme,
}) {
  final effectiveTheme = theme ?? AppTheme.of(context);
  final initialTime = initial ?? TimeOfDay.now();
  TimeOfDay selected = initialTime;
  return showDSDialog<TimeOfDay>(
    context: context,
    theme: effectiveTheme,
    builder:
        (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DSTimePicker(
              initialTime: initialTime,
              use24Hour: use24Hour,
              onChanged: (time) => selected = time,
            ),
            SizedBox(height: effectiveTheme.spacing.lg),
            Row(
              children: [
                Expanded(
                  child: DSButton(
                    label: cancelText ?? '取消',
                    variant: DSButtonVariant.outline,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: effectiveTheme.spacing.md),
                Expanded(
                  child: DSButton(
                    label: confirmText ?? '确定',
                    onPressed: () => Navigator.of(context).pop(selected),
                  ),
                ),
              ],
            ),
          ],
        ),
  );
}
