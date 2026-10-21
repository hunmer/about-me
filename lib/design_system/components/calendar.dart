import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/motion.dart';
import '../tokens/typography.dart';
import 'button.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 手绘月历：头部翻月 + 周标头 + 6 行 7 列日期网格
///
/// - 周一为一周起点（周标头「一 ~ 日」，caption 样式 textSub）
/// - 非本月日期弱化展示（textSub 0.4 透明度，仍可点选）
/// - 今日：primary mixWhite(0.92) 淡底 + 主色手绘墨圈
///   （做法同 date_picker.dart 的今日样式）
/// - 选中：JellyBox 正圆 primary 实底 + 反色字
/// - [selected] 非空时受控（选中展示以它为准）；
///   为 null 时组件内部自记选中，点击回调 [onSelected]
/// - [compact] 紧凑模式：日期格与行距缩小
/// - 月份切换 [AnimatedSwitcher] fade（[DsMotion.fast]；
///   动效减弱时直切）
///
/// 月网格逻辑改自 date_picker.dart 的私有网格（其起点为周日且隐藏
/// 非本月日期；此处改为周一起点 + 弱化显示相邻月日期）。
class DSCalendar extends StatefulWidget {
  const DSCalendar({
    super.key,
    this.selected,
    this.initialMonth,
    this.onSelected,
    this.compact = false,
  });

  /// 受控选中日期（null = 非受控，内部记录）
  final DateTime? selected;

  /// 初始展示月份，默认 [selected] 所在月或当前月
  final DateTime? initialMonth;

  final ValueChanged<DateTime>? onSelected;

  /// 紧凑模式：周行高小
  final bool compact;

  @override
  State<DSCalendar> createState() => _DSCalendarState();
}

class _DSCalendarState extends State<DSCalendar> {
  late DateTime _month;
  DateTime? _internalSelected;

  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    final base = widget.initialMonth ?? widget.selected ?? DateTime.now();
    _month = DateTime(base.year, base.month);
  }

  DateTime? get _effectiveSelected => widget.selected ?? _internalSelected;

  void _shiftMonth(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
  });

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _tapDate(DateTime date) {
    if (widget.selected == null) {
      setState(() => _internalSelected = date);
    }
    widget.onSelected?.call(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final cell = widget.compact ? 32.0 : 40.0;
    final rowGap = widget.compact ? 2.0 : theme.spacing.xs;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 头部：翻月按钮 + 「2026年10月」标题
        Row(
          children: [
            DSIconButton(
              icon: DsIconKind.chevronLeft,
              size: 32,
              onPressed: () => _shiftMonth(-1),
            ),
            Expanded(
              child: Text(
                '${_month.year}年${_month.month}月',
                textAlign: TextAlign.center,
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
            ),
            DSIconButton(
              icon: DsIconKind.chevronRight,
              size: 32,
              onPressed: () => _shiftMonth(1),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.sm),
        AnimatedSwitcher(
          duration: context.dsAnimationsDisabled ? Duration.zero : DsMotion.fast,
          child: KeyedSubtree(
            key: ValueKey('${_month.year}-${_month.month}'),
            child: _buildGrid(theme, cell, rowGap),
          ),
        ),
      ],
    );
  }

  /// 周标头 + 固定 6 行 7 列网格（保证月历高度稳定）
  Widget _buildGrid(AppThemeData theme, double cell, double rowGap) {
    // 周一起点：本月 1 号的 weekday - 1 即前置偏移
    final first = DateTime(_month.year, _month.month);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final today = DateTime.now();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        SizedBox(height: theme.spacing.xs),
        for (var row = 0; row < 6; row++)
          Padding(
            padding: EdgeInsets.only(bottom: rowGap),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Center(
                      child: _buildCell(
                        theme,
                        gridStart.add(Duration(days: row * 7 + col)),
                        today,
                        cell,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCell(AppThemeData theme, DateTime date, DateTime today, double cell) {
    final inMonth = date.year == _month.year && date.month == _month.month;
    final selected =
        _effectiveSelected != null && _isSameDay(_effectiveSelected!, date);
    final isToday = _isSameDay(today, date);
    final label = '${date.year}-${date.month}-${date.day}';

    if (selected) {
      return Pressable(
        onPressed: () => _tapDate(date),
        semanticLabel: label,
        child: JellyBox(
          width: cell,
          height: cell,
          radius: theme.radii.circle,
          color: theme.primary,
          alignment: Alignment.center,
          child: Text(
            '${date.day}',
            style: DsTypography.body.copyWith(color: theme.onPrimary),
          ),
        ),
      );
    }

    final Color dayColor = !inMonth
        ? theme.textSub.withValues(alpha: 0.4)
        : isToday
        ? theme.primaryText
        : theme.text;

    return Pressable(
      onPressed: () => _tapDate(date),
      semanticLabel: label,
      child: Container(
        width: cell,
        height: cell,
        alignment: Alignment.center,
        // 今日格：淡紫实底 + 主色墨圈（同 date_picker）；普通日期无装饰
        decoration: isToday
            ? dsSketchDecoration(
                theme: theme,
                circle: true,
                fillColor: theme.primary.mixWhite(0.92),
                stroke: theme.primary,
                strokeWidth: 1.6,
              )
            : null,
        child: Text(
          '${date.day}',
          style: DsTypography.body.copyWith(color: dayColor),
        ),
      ),
    );
  }
}
