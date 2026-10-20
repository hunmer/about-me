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

/// 选择器视图层级：日期网格 -> 月份列表 -> 年份列表
enum _DPView { date, month, year }

class _DSDatePickerState extends State<DSDatePicker> {
  late DateTime _month;

  _DPView _view = _DPView.date;

  static const _weekLabels = ['日', '一', '二', '三', '四', '五', '六'];

  @override
  void initState() {
    super.initState();
    final base = widget.initialMonth ?? widget.value ?? DateTime.now();
    _month = DateTime(base.year, base.month);
  }

  /// 当前十年起始年（如 2023 -> 2020）
  int get _decadeStart => _month.year ~/ 10 * 10;

  String get _viewTitle => switch (_view) {
    _DPView.date => '${_month.year}年${_month.month}月',
    _DPView.month => '${_month.year}年',
    _DPView.year => '$_decadeStart - ${_decadeStart + 9}',
  };

  /// 按视图翻页：日期翻月 / 月份翻年 / 年份翻十年
  void _shiftPage(int delta) {
    setState(() {
      switch (_view) {
        case _DPView.date:
          _month = DateTime(_month.year, _month.month + delta);
        case _DPView.month:
          _month = DateTime(_month.year + delta, _month.month);
        case _DPView.year:
          _month = DateTime(_month.year + delta * 10, _month.month);
      }
    });
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

  bool _isSelectedMonth(int m) {
    final v = widget.value;
    return v != null && v.year == _month.year && v.month == m;
  }

  bool _isCurrentMonth(int m) {
    final now = DateTime.now();
    return now.year == _month.year && now.month == m;
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
        // 头部：翻页 + 标题（点标题逐级下钻：日期->月份->年份）
        Row(
          children: [
            _NavButton(icon: DsIconKind.chevronLeft, onTap: () => _shiftPage(-1)),
            Expanded(
              child: Pressable(
                onPressed:
                    () => setState(() {
                      if (_view == _DPView.date) {
                        _view = _DPView.month;
                      } else if (_view == _DPView.month) {
                        _view = _DPView.year;
                      }
                    }),
                semanticLabel: _viewTitle,
                child: Text(
                  _viewTitle,
                  textAlign: TextAlign.center,
                  style: DsTypography.heading.copyWith(color: theme.text),
                ),
              ),
            ),
            _NavButton(icon: DsIconKind.chevronRight, onTap: () => _shiftPage(1)),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        // 网格区域支持横滑翻页（日期翻月/月份翻年/年份翻十年）
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v > 200) {
              _shiftPage(-1);
            } else if (v < -200) {
              _shiftPage(1);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: switch (_view) {
              // 月份列表：4行3列，点选后回到该月日期网格
              _DPView.month => [
                for (var row = 0; row < 4; row++)
                  Padding(
                    padding: EdgeInsets.only(bottom: theme.spacing.xs),
                    child: Row(
                      children: [
                        for (var col = 0; col < 3; col++)
                          Expanded(
                            child: _buildMonthCell(
                              context,
                              month: row * 3 + col + 1,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
              // 年份列表：十年一组（首尾各带一格相邻十年的年份，点选跳转）
              _DPView.year => [
                for (var row = 0; row < 4; row++)
                  Padding(
                    padding: EdgeInsets.only(bottom: theme.spacing.xs),
                    child: Row(
                      children: [
                        for (var col = 0; col < 3; col++)
                          Expanded(
                            child: _buildYearCell(
                              context,
                              year: _decadeStart - 1 + row * 3 + col + 1,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
              // 日期视图：星期行 + 日期网格
              _DPView.date => [
                Row(
                  children: [
                    for (final label in _weekLabels)
                      Expanded(
                        child: Center(
                          child: Text(
                            label,
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: theme.spacing.sm),
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
            },
          ),
        ),
      ],
    );
  }

  /// 月份列表格子：选中月主色胶囊，当前月淡底墨圈，点选后回到日期网格
  Widget _buildMonthCell(BuildContext context, {required int month}) {
    final theme = AppTheme.of(context);
    final selected = _isSelectedMonth(month);
    final current = _isCurrentMonth(month);

    return Pressable(
      onPressed:
          () => setState(() {
            _month = DateTime(_month.year, month);
            _view = _DPView.date;
          }),
      semanticLabel: '${_month.year}年$month月',
      child:
          selected
              ? JellyBox(
                height: 44,
                radius: theme.radii.circle,
                color: theme.primary,
                alignment: Alignment.center,
                child: Text(
                  '$month月',
                  style: DsTypography.body.copyWith(color: theme.onPrimary),
                ),
              )
              : Container(
                height: 44,
                alignment: Alignment.center,
                decoration:
                    current
                        ? dsSketchDecoration(
                          theme: theme,
                          circle: true,
                          fillColor: theme.primary.mixWhite(0.92),
                          stroke: theme.primary,
                          strokeWidth: 1.6,
                        )
                        : null,
                child: Text(
                  '$month月',
                  style: DsTypography.body.copyWith(
                    color: current ? theme.primaryText : theme.text,
                  ),
                ),
              ),
    );
  }

  /// 年份列表格子：首尾相邻十年的年份淡化显示，点选后回到月份列表
  Widget _buildYearCell(BuildContext context, {required int year}) {
    final theme = AppTheme.of(context);
    final inDecade = year >= _decadeStart && year < _decadeStart + 10;
    final selected = widget.value?.year == year;
    final current = DateTime.now().year == year;

    return Pressable(
      onPressed:
          () => setState(() {
            _month = DateTime(year, _month.month);
            _view = _DPView.month;
          }),
      semanticLabel: '$year年',
      child:
          selected
              ? JellyBox(
                height: 44,
                radius: theme.radii.circle,
                color: theme.primary,
                alignment: Alignment.center,
                child: Text(
                  '$year',
                  style: DsTypography.body.copyWith(color: theme.onPrimary),
                ),
              )
              : Container(
                height: 44,
                alignment: Alignment.center,
                decoration:
                    current
                        ? dsSketchDecoration(
                          theme: theme,
                          circle: true,
                          fillColor: theme.primary.mixWhite(0.92),
                          stroke: theme.primary,
                          strokeWidth: 1.6,
                        )
                        : null,
                child: Text(
                  '$year',
                  style: DsTypography.body.copyWith(
                    color:
                        !inDecade
                            ? theme.textSub
                            : (current ? theme.primaryText : theme.text),
                  ),
                ),
              ),
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

    return Pressable(
      onPressed: () => widget.onChanged?.call(date),
      semanticLabel: '${_month.year}-${_month.month}-$dayIndex',
      child:
          selected
              ? JellyBox(
                width: 34,
                height: 34,
                radius: theme.radii.circle,
                color: theme.primary,
                alignment: Alignment.center,
                child: Text(
                  '$dayIndex',
                  style: DsTypography.body.copyWith(color: theme.onPrimary),
                ),
              )
              // 今日格：淡紫实底 + 主色墨圈；普通日期无装饰
              : Container(
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
        child: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DSDatePicker(
                value: selected,
                initialMonth: initialValue,
                onChanged: (date) => setState(() => selected = date),
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
    ),
  );
}
