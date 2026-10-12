import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'button.dart';
import 'dialog.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 手绘月历选择器（对应设计稿：头部翻月 + 星期行 + 日期网格）
class DSDatePicker extends StatefulWidget {
  const DSDatePicker({
    super.key,
    this.value,
    required this.onChanged,
    this.initialMonth,
  });

  final DateTime? value;
  final ValueChanged<DateTime>? onChanged;

  /// 初始展示的月份，默认取 [value] 所在月或当前月
  final DateTime? initialMonth;

  @override
  State<DSDatePicker> createState() => _DSDatePickerState();
}

class _DSDatePickerState extends State<DSDatePicker> {
  late DateTime _month;

  static const _weekLabels = ['日', '一', '二', '三', '四', '五', '六'];

  @override
  void initState() {
    super.initState();
    final base = widget.initialMonth ?? widget.value ?? DateTime.now();
    _month = DateTime(base.year, base.month);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isSelected(DateTime d) {
    final v = widget.value;
    return v != null &&
        v.year == d.year &&
        v.month == d.month &&
        v.day == d.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    // 周日为一周起点：weekday 1=周一...7=周日，前置空格 = weekday % 7
    final firstWeekday = DateTime(_month.year, _month.month).weekday % 7;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = ((firstWeekday + daysInMonth) / 7).ceil() * 7;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 头部：翻月 + 年月标题
        Row(
          children: [
            _NavButton(
              icon: DsIconKind.chevronLeft,
              onTap: () => _shiftMonth(-1),
            ),
            Expanded(
              child: Text(
                '${_month.year}年${_month.month}月',
                textAlign: TextAlign.center,
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
            ),
            _NavButton(
              icon: DsIconKind.chevronRight,
              onTap: () => _shiftMonth(1),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        // 星期行
        Row(
          children: [
            for (final label in _weekLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: theme.spacing.sm),
        // 日期网格
        for (var row = 0; row < cells / 7; row++)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.xs),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Center(
                      child: _buildCell(
                        context,
                        dayIndex: row * 7 + col - firstWeekday + 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCell(BuildContext context, {required int dayIndex}) {
    final theme = AppTheme.of(context);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    if (dayIndex < 1 || dayIndex > daysInMonth) {
      return const SizedBox(height: 34);
    }
    final date = DateTime(_month.year, _month.month, dayIndex);
    final selected = _isSelected(date);
    final today = _isToday(date);

    if (selected) {
      return JellyBox(
        width: 34,
        height: 34,
        radius: theme.radii.circle,
        color: theme.primary,
        alignment: Alignment.center,
        child: Text(
          '$dayIndex',
          style: DsTypography.body.copyWith(color: theme.onPrimary),
        ),
      );
    }

    // 今日格：淡紫实底 + 主色墨圈；普通日期无装饰
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: today
          ? dsSketchDecoration(
              theme: theme,
              circle: true,
              fillColor: theme.primary.mixWhite(0.92),
              stroke: theme.primary,
              strokeWidth: 1.6,
            )
          : null,
      child: Text(
        '$dayIndex',
        style: DsTypography.body.copyWith(
          color: today ? theme.primaryText : theme.text,
        ),
      ),
    );
  }
}

/// 头部翻月小按钮（轻量样式）
class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});

  final DsIconKind icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hovered ? theme.surfaceAlt : DsColors.transparent,
            shape: BoxShape.circle,
          ),
          child: DsIcon(icon, size: 18, color: theme.primary),
        );
      },
    );
  }
}

/// 便捷日期选择对话框：DSDatePicker + 取消/确认
///
/// [cancelText]/[confirmText] 未传时用内置默认，
/// 需要本地化时由调用方注入。
Future<DateTime?> showDSDatePickerDialog({
  required BuildContext context,
  DateTime? initial,
  String? cancelText,
  String? confirmText,
  AppThemeData? theme,
}) {
  final effectiveTheme = theme ?? AppTheme.of(context);
  final initialValue = initial ?? DateTime.now();
  DateTime selected = initialValue;
  return showDSDialog<DateTime>(
    context: context,
    theme: effectiveTheme,
    // 大面板：纸底 + 淡排线 + 墨框（DsSketchPanel 无 constraints 参数，
    // 用 ConstrainedBox 保住原 maxWidth 布局）
    builder: (context) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: DsSketchPanel(
        theme: effectiveTheme,
        radius: effectiveTheme.radii.xxl,
        padding: EdgeInsets.all(effectiveTheme.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DSDatePicker(
              value: initialValue,
              initialMonth: initialValue,
              onChanged: (date) => selected = date,
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
      ),
    ),
  );
}
