import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/plugins/checkin/models/checkin_item.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

// weekly 风格单行布局常量（CheckinWeekdayHeader 依赖这些值对齐圆点列，修改需同步）
const double _kWeeklyIconSize = 32;
const double _kWeeklyGapAfterIcon = 8;
const double _kWeeklyGapBeforeCircles = 6;
const double _kWeeklyCirclesWidth = 154; // 7 列 × 22
const double _kWeeklyColumnWidth = 22;
const double _kWeeklyGapBeforePlus = 6;
const double _kWeeklyPlusSize = 30;

/// 打卡项目卡片组件
///
/// 用于展示打卡项目的卡片，支持三种风格：weekly、small、calendar。
/// 手绘纸墨风：卡片面板走 DsSketchPanel（纸底 + 淡排线 + 墨线框），
/// 小控件走 dsSketchDecoration，动态图标经 WiredIcon 套手绘几何。
///
/// 使用示例：
/// ```dart
/// CheckinItemCardWidget(
///   item: CheckinItem(name: '早起', icon: Icons.wb_sunny),
///   index: 0,
///   itemIndex: 0,
///   onStateChanged: () {},
/// )
/// ```
class CheckinItemCardWidget extends StatefulWidget {
  /// 打卡项目数据
  final CheckinItem item;

  /// 索引
  final int index;

  /// 项目索引
  final int itemIndex;

  /// 状态变更回调（用于+1按钮）
  final VoidCallback onStateChanged;

  /// 点击回调（可选，用于卡片主体导航）
  final VoidCallback? onTap;

  /// 长按回调（可选）
  final VoidCallback? onLongPress;

  /// 日期选择回调（可选，用于点击周圈或日历日期）
  final Function(DateTime selectedDate)? onDateSelected;

  const CheckinItemCardWidget({
    super.key,
    required this.item,
    required this.index,
    required this.itemIndex,
    required this.onStateChanged,
    this.onTap,
    this.onLongPress,
    this.onDateSelected,
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory CheckinItemCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final itemJson = props['item'] as Map<String, dynamic>?;
    return CheckinItemCardWidget(
      item: itemJson != null ? CheckinItem.fromJson(itemJson) : CheckinItem(
        name: props['name'] as String? ?? '',
        icon: props['icon'] != null
            ? dynamicIconData(props['icon'] as int, fontFamily: 'MaterialIcons')
            : Icons.check_circle,
      ),
      index: props['index'] as int? ?? 0,
      itemIndex: props['itemIndex'] as int? ?? 0,
      onStateChanged: props['onStateChanged'] as VoidCallback? ?? () {},
      onTap: props['onTap'] as VoidCallback?,
      onLongPress: props['onLongPress'] as VoidCallback?,
      onDateSelected: props['onDateSelected'] as Function(DateTime)?,
    );
  }

  @override
  State<CheckinItemCardWidget> createState() => _CheckinItemCardWidgetState();
}

class _CheckinItemCardWidgetState extends State<CheckinItemCardWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    Widget content;
    switch (widget.item.cardStyle) {
      case CheckinCardStyle.small:
        content = _buildSmallStyle(context, theme);
        break;
      case CheckinCardStyle.calendar:
        content = _buildCalendarStyle(context, theme);
        break;
      case CheckinCardStyle.weekly:
        content = _buildWeeklyStyle(context, theme);
        break;
    }

    // margin/padding 与 CheckinWeekdayHeader 的对齐约定：8 + 16
    return Container(
      margin: const EdgeInsets.all(8),
      child: Pressable(
        onPressed: widget.onTap,
        onLongPress: widget.onLongPress,
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return Transform.scale(
            scale: pressed ? 0.97 : 1.0,
            child: DsSketchPanel(
              theme: theme,
              radius: BorderRadius.circular(16),
              padding: const EdgeInsets.all(16.0),
              seed: widget.index + 1,
              child: content,
            ),
          );
        },
      ),
    );
  }

  // --- Weekly Style ---
  Widget _buildWeeklyStyle(BuildContext context, AppThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildIcon(theme, size: _kWeeklyIconSize, borderRadius: 10),
        const SizedBox(width: _kWeeklyGapAfterIcon),
        // 标题 + 频次徽章
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.item.name,
                style: DsTypography.heading.copyWith(fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              JellyBox(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                radius: DsRadii.pill,
                color: theme.surfaceAlt,
                child: Text(
                  _getFrequencyText(),
                  style: DsTypography.caption.copyWith(
                    fontSize: 10,
                    color: theme.textSub,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: _kWeeklyGapBeforeCircles),
        // 周打卡圆点（与列表顶部全局星期表头逐列对齐）
        SizedBox(
          width: _kWeeklyCirclesWidth,
          height: 24,
          child: _buildWeeklyCircles(theme),
        ),
        const SizedBox(width: _kWeeklyGapBeforePlus),
        // 快捷打卡按钮
        _buildPlusOneButton(context, theme, size: _kWeeklyPlusSize),
      ],
    );
  }

  // --- Small Style ---
  Widget _buildSmallStyle(BuildContext context, AppThemeData theme) {
    final stats = _calculateMonthlyStats();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                WiredIcon(
                  icon: widget.item.icon,
                  size: 20,
                  color: widget.item.color,
                  drawConfig: theme.wired.drawConfig,
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: Text(
                    widget.item.name,
                    style: DsTypography.heading,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (widget.item.lastCheckinDate != null)
              Row(
                children: [
                  Text(
                    _formatTimeOnly(widget.item.lastCheckinDate!),
                    style: DsTypography.caption.copyWith(
                      fontSize: 10,
                      color: theme.textSub,
                    ),
                  ),
                  DsIcon(DsIconKind.edit, size: 14, color: theme.textSub),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Stats Box
        Container(
          padding: const EdgeInsets.all(8),
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: theme.surfaceAlt.withValues(alpha: 0.5),
            radius: BorderRadius.circular(10),
            strokeWidth: 1.4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSmallStatItem(
                theme,
                DsIconKind.list,
                stats['count']!.toString(),
                'checkin_statCount'.tr,
                theme.primary,
              ),
              _buildSmallStatItem(
                theme,
                DsIconKind.calendar,
                stats['days']!.toString(),
                'checkin_statDays'.tr,
                theme.textSub,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Progress Button (Acting as +1)
        _buildProgressButton(context, theme, stats),
      ],
    );
  }

  // --- Calendar Style ---
  Widget _buildCalendarStyle(BuildContext context, AppThemeData theme) {
    final stats = _calculateMonthlyStats();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildIcon(theme),
                const SizedBox(width: 12),
                Text(
                  widget.item.name,
                  style: DsTypography.heading.copyWith(fontSize: 16),
                ),
              ],
            ),
            if (widget.item.lastCheckinDate != null)
              Row(
                children: [
                  Text(
                    _formatLastCheckinTime(),
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                  const SizedBox(width: 4),
                  DsIcon(DsIconKind.edit, size: 16, color: theme.textSub),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Body
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Calendar Grid
            Expanded(child: _buildMonthCalendar(context, theme)),
            const SizedBox(width: 16),

            // Right Side Stats & Button
            SizedBox(
              width: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: dsSketchDecoration(
                      theme: theme,
                      fillColor: theme.surfaceAlt.withValues(alpha: 0.5),
                      radius: BorderRadius.circular(10),
                      strokeWidth: 1.4,
                    ),
                    child: _buildSmallStatItem(
                      theme,
                      DsIconKind.list,
                      stats['count']!.toString(),
                      'checkin_statCountShort'.tr,
                      theme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPlusOneButton(context, theme, size: 60),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Helper Widgets ---

  /// 图标容器，[borderRadius] 为 null 时圆形，否则方形圆角
  Widget _buildIcon(AppThemeData theme, {double size = 40, double? borderRadius}) {
    final rounded = borderRadius != null;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: widget.item.color.withValues(alpha: 0.12),
        circle: !rounded,
        radius: rounded ? BorderRadius.circular(borderRadius) : null,
        strokeWidth: 1.6,
      ),
      child: WiredIcon(
        icon: widget.item.icon,
        size: size * 0.6,
        color: widget.item.color,
        drawConfig: theme.wired.drawConfig,
      ),
    );
  }

  Widget _buildPlusOneButton(
    BuildContext context,
    AppThemeData theme, {
    required double size,
  }) {
    return Pressable(
      onPressed: widget.onStateChanged,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Transform.scale(
          scale: pressed ? 0.9 : 1.0,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: widget.item.color.withValues(alpha: 0.12),
              radius: BorderRadius.circular(size * 0.3),
              stroke: widget.item.color,
              strokeWidth: 1.6,
            ),
            child: Text(
              '+1',
              style: DsTypography.heading.copyWith(
                color: widget.item.color,
                fontSize: size * 0.35,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressButton(
    BuildContext context,
    AppThemeData theme,
    Map<String, int> stats,
  ) {
    final progress = (stats['count']! / 30).clamp(0.0, 1.0);
    return Pressable(
      onPressed: widget.onStateChanged,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Transform.scale(
          scale: pressed ? 0.97 : 1.0,
          child: SizedBox(
            height: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  // Progress Bar：淡彩实底填充
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: ColoredBox(
                      color: widget.item.color.withValues(alpha: 0.18),
                    ),
                  ),
                  // 墨线轨道（画在边界上）
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: dsSketchDecoration(
                        theme: theme,
                        radius: BorderRadius.circular(10),
                        strokeWidth: 1.6,
                      ),
                    ),
                  ),
                  // Text
                  Center(
                    child: Text(
                      '${stats['count']}/30',
                      style: DsTypography.label.copyWith(
                        color: widget.item.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmallStatItem(
    AppThemeData theme,
    DsIconKind icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        DsIcon(icon, size: 16, color: color.withValues(alpha: 0.8)),
        const SizedBox(height: 2),
        Text(value, style: DsTypography.label),
        Text(
          label,
          style: DsTypography.caption.copyWith(
            fontSize: 9,
            color: theme.textSub,
          ),
        ),
      ],
    );
  }

  /// 周视图打卡圆点：整行铺满 7 列，星期文字由外部固定表头（CheckinWeekdayHeader）展示
  Widget _buildWeeklyCircles(AppThemeData theme) {
    final now = DateTime.now();
    // 标准化为今天的 00:00:00
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final columns = <Widget>[];

    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      // 标准化日期，去除时间部分
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final hasCheckin = widget.item.checkInRecords.containsKey(dateStr) &&
          widget.item.checkInRecords[dateStr]!.isNotEmpty;
      final isToday = normalizedDate.isAtSameMomentAs(today);

      // 检查日期是否在未来（使用标准化日期比较）
      final isFuture = normalizedDate.isAfter(today);

      columns.add(
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: () {
                // 如果是未来日期，不允许点击
                if (isFuture) return;
                // 触发日期选择回调
                widget.onDateSelected?.call(normalizedDate);
              },
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: dsSketchDecoration(
                  theme: theme,
                  circle: true,
                  // 已打卡：项目色实底（描边同色融为一体）；未打卡：纸面/无填充
                  fillColor: hasCheckin
                      ? widget.item.color
                      : (isFuture ? null : theme.surfaceAlt),
                  stroke: hasCheckin
                      ? widget.item.color
                      : (isToday ? widget.item.color : theme.ink),
                  strokeWidth: isToday && !hasCheckin ? 1.8 : 1.2,
                  seed: widget.index * 7 + i + 1,
                ),
                child: hasCheckin
                    ? DsIcon(DsIconKind.check, size: 12, color: theme.paper)
                    : null,
              ),
            ),
          ),
        ),
      );
    }

    return Row(children: columns);
  }

  Widget _buildMonthCalendar(BuildContext context, AppThemeData theme) {
    final now = DateTime.now();
    // 标准化为今天的 00:00:00
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemCount: daysInMonth,
      itemBuilder: (context, index) {
        final day = index + 1;
        final date = DateTime(now.year, now.month, day);
        final dateStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        final hasCheckin =
            widget.item.checkInRecords.containsKey(dateStr) &&
            widget.item.checkInRecords[dateStr]!.isNotEmpty;
        final isToday = date.isAtSameMomentAs(today);

        // 检查日期是否在未来（使用标准化日期比较）
        final isFuture = date.isAfter(today);

        return GestureDetector(
          onTap: () {
            // 如果是未来日期，不允许点击
            if (isFuture) return;
            // 触发日期选择回调
            widget.onDateSelected?.call(date);
          },
          child: Container(
            // 仅已打卡/今天画手绘格（淡彩底 + 墨线），普通日期留白省墨
            decoration: hasCheckin || (isToday && !hasCheckin)
                ? dsSketchDecoration(
                    theme: theme,
                    fillColor: hasCheckin
                        ? widget.item.color.withValues(alpha: 0.18)
                        : null,
                    stroke: isToday && !hasCheckin
                        ? widget.item.color
                        : theme.ink,
                    strokeWidth: 1.2,
                    radius: BorderRadius.circular(6),
                    seed: day,
                  )
                : null,
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: DsTypography.caption.copyWith(
                color: hasCheckin ? widget.item.color : theme.textSub,
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Logic Helpers ---

  Map<String, int> _calculateMonthlyStats() {
    final now = DateTime.now();
    final records = widget.item.getMonthlyRecords(now.year, now.month);
    int count = 0;
    records.forEach((_, list) => count += list.length);
    return {'count': count, 'days': records.length};
  }

  /// 根据 frequency 配置生成频次徽章文案
  String _getFrequencyText() {
    final daysPerWeek = widget.item.frequency.where((enabled) => enabled).length;
    if (daysPerWeek >= 7) return 'checkin_freqEveryday'.tr;
    if (daysPerWeek <= 0) return 'checkin_freqNotSet'.tr;
    return 'checkin_freqPerWeek'.trParams({'days': daysPerWeek.toString()});
  }

  String _formatLastCheckinTime() {
    final lastDate = widget.item.lastCheckinDate;
    if (lastDate == null) return '';

    final now = DateTime.now();
    final diff = now.difference(lastDate);

    if (diff.inDays == 0) {
      final records = widget.item.getDateRecords(lastDate);
      if (records.isNotEmpty) {
        return _formatTimeOnly(records.first.checkinTime);
      }
      return 'checkin_timeToday'.tr;
    } else if (diff.inDays == 1) {
      final records = widget.item.getDateRecords(lastDate);
      if (records.isNotEmpty) {
        return '${'checkin_timeYesterday'.tr} ${_formatTimeOnly(records.first.checkinTime)}';
      }
      return 'checkin_timeYesterday'.tr;
    } else {
      return '${lastDate.month}-${lastDate.day}';
    }
  }

  String _formatTimeOnly(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// 周视图全局星期表头
///
/// 供打卡列表页固定展示在卡片列表上方（不随滚动），替代在每张卡片内显示星期。
/// 水平结构与 [CheckinItemCardWidget] weekly 风格单行布局镜像一致
/// （外边距 16 + 内边距 16 与卡片容器 8+8+16 的内容偏移相同，
/// 图标/标题/圆点/按钮占位相同），因此 7 个星期列与卡片内打卡圆点逐列对齐。
/// 每列上方为星期字、下方为对应日期数字，今天整列高亮。
class CheckinWeekdayHeader extends StatelessWidget {
  const CheckinWeekdayHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    const weekdayChars = ['一', '二', '三', '四', '五', '六', '日'];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekDates = [
      for (int i = 0; i < 7; i++)
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
      child: Row(
        children: [
          // 图标 + 间距占位
          SizedBox(width: _kWeeklyIconSize + _kWeeklyGapAfterIcon),
          // 标题弹性区占位
          const Expanded(child: SizedBox.shrink()),
          SizedBox(width: _kWeeklyGapBeforeCircles),
          // 圆点区：与卡片内圆点列逐列对齐
          SizedBox(
            width: _kWeeklyCirclesWidth,
            child: Row(
              children: [
                for (int i = 0; i < 7; i++)
                  SizedBox(
                    width: _kWeeklyColumnWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          weekdayChars[i],
                          style: DsTypography.caption.copyWith(
                            fontSize: 9,
                            height: 1.2,
                            color: weekDates[i] == today
                                ? theme.text
                                : theme.textSub,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${weekDates[i].day}',
                          style: DsTypography.caption.copyWith(
                            fontSize: 12,
                            height: 1.1,
                            color: weekDates[i] == today
                                ? theme.primary
                                : theme.text,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // +1 按钮占位
          SizedBox(width: _kWeeklyGapBeforePlus + _kWeeklyPlusSize),
        ],
      ),
    );
  }
}
