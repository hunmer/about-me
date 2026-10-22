/// 日历事件小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 翻牌日期 + 周历（今日 = 主题强调色浅底圆徽章）/ 事件列表
/// （数据色竖条 + 手绘日历图标，逐项错峰浮现）/ 底部提醒。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 事件数据模型
class EventData {
  final String title;
  final String time;
  final String duration;
  final String? location;
  final Color color;
  final Color iconColor;
  final String? buttonLabel;

  const EventData({
    required this.title,
    required this.time,
    required this.duration,
    this.location,
    required this.color,
    required this.iconColor,
    this.buttonLabel,
  });

  /// 从 JSON 创建
  factory EventData.fromJson(Map<String, dynamic> json) {
    return EventData(
      title: json['title'] as String? ?? '',
      time: json['time'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      location: json['location'] as String?,
      color: Color(json['color'] as int? ?? 0xFF525EAF),
      iconColor: Color(json['iconColor'] as int? ?? 0xFF6264A7),
      buttonLabel: json['buttonLabel'] as String?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'time': time,
      'duration': duration,
      'location': location,
      'color': color.value,
      'iconColor': iconColor.value,
      'buttonLabel': buttonLabel,
    };
  }
}

/// 日历事件小组件
class EventCalendarWidget extends StatefulWidget {
  final int day;
  final String weekday;
  final String month;
  final int eventCount;
  final List<int> weekDates;
  final int weekStartDay;
  final String reminder;
  final String reminderEmoji;
  final List<EventData> events;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const EventCalendarWidget({
    super.key,
    required this.day,
    required this.weekday,
    required this.month,
    required this.eventCount,
    required this.weekDates,
    required this.weekStartDay,
    required this.reminder,
    required this.reminderEmoji,
    required this.events,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory EventCalendarWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final eventsList =
        (props['events'] as List<dynamic>?)
            ?.map((e) => EventData.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    final weekDatesList =
        (props['weekDates'] as List<dynamic>?)?.map((e) => e as int).toList() ??
        [];

    return EventCalendarWidget(
      day: props['day'] as int? ?? 15,
      weekday: props['weekday'] as String? ?? 'Wednesday',
      month: props['month'] as String? ?? 'August',
      eventCount: props['eventCount'] as int? ?? 3,
      weekDates: weekDatesList,
      weekStartDay: props['weekStartDay'] as int? ?? 0,
      reminder: props['reminder'] as String? ?? '',
      reminderEmoji: props['reminderEmoji'] as String? ?? '',
      events: eventsList,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<EventCalendarWidget> createState() => _EventCalendarWidgetState();
}

class _EventCalendarWidgetState extends State<EventCalendarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;
    // 日历强调色（原红色点缀，走主题语义色）
    final primaryColor = theme.danger;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 420,
        height: widget.inline ? double.maxFinite : 220,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child:
            widget.size.category == SizeCategory.large ||
                    widget.size.category == SizeCategory.xlarge
                ? _buildLargeLayout(primaryColor)
                : _buildCompactLayout(primaryColor),
      ),
    );
  }

  /// 大尺寸布局：横向布局，日期+周历在左，事件列表在右
  Widget _buildLargeLayout(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 160,
                child: Column(
                  children: [
                    _DateSection(
                      day: widget.day,
                      weekday: widget.weekday,
                      month: widget.month,
                      eventCount: widget.eventCount,
                      primaryColor: primaryColor,
                      animation: _animation,
                      size: widget.size,
                      textAlignment: CrossAxisAlignment.end,
                    ),
                    SizedBox(height: widget.size.getTitleSpacing()),
                    _WeekCalendar(
                      weekDates: widget.weekDates,
                      currentDay: widget.day,
                      weekStartDay: widget.weekStartDay,
                      primaryColor: primaryColor,
                      size: widget.size,
                      isScrollable: false,
                    ),
                  ],
                ),
              ),
              SizedBox(width: widget.size.getItemSpacing()),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < widget.events.length; i++) ...[
                        if (i > 0)
                          SizedBox(height: widget.size.getItemSpacing()),
                        _EventCard(
                          event: widget.events[i],
                          animation: _animation,
                          index: i,
                          size: widget.size,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: widget.size.getItemSpacing()),
        _ReminderItem(
          emoji: widget.reminderEmoji,
          text: widget.reminder,
          animation: _animation,
          size: widget.size,
        ),
      ],
    );
  }

  /// 紧凑布局：纵向布局，日期在上方，周历横向滚动，事件列表单独一行
  Widget _buildCompactLayout(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DateSection(
          day: widget.day,
          weekday: widget.weekday,
          month: widget.month,
          eventCount: widget.eventCount,
          primaryColor: primaryColor,
          animation: _animation,
          size: widget.size,
          textAlignment: CrossAxisAlignment.end,
        ),
        SizedBox(height: widget.size.getItemSpacing()),
        _WeekCalendar(
          weekDates: widget.weekDates,
          currentDay: widget.day,
          weekStartDay: widget.weekStartDay,
          primaryColor: primaryColor,
          size: widget.size,
          isScrollable: true,
        ),
        SizedBox(height: widget.size.getItemSpacing()),
        // 事件列表单独一行
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < widget.events.length; i++) ...[
                  if (i > 0) SizedBox(height: widget.size.getItemSpacing()),
                  _EventCard(
                    event: widget.events[i],
                    animation: _animation,
                    index: i,
                    size: widget.size,
                  ),
                ],
              ],
            ),
          ),
        ),
        // ReminderItem 始终在底部
        _ReminderItem(
          emoji: widget.reminderEmoji,
          text: widget.reminder,
          animation: _animation,
          size: widget.size,
        ),
      ],
    );
  }
}

class _DateSection extends StatelessWidget {
  final int day;
  final String weekday;
  final String month;
  final int eventCount;
  final Color primaryColor;
  final Animation<double> animation;
  final HomeWidgetSize size;
  final CrossAxisAlignment textAlignment;

  const _DateSection({
    required this.day,
    required this.weekday,
    required this.month,
    required this.eventCount,
    required this.primaryColor,
    required this.animation,
    required this.size,
    this.textAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedFlipCounter(
          value: day.toDouble(),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          textStyle: TextStyle(
            fontSize: size.getLargeFontSize(),
            fontWeight: FontWeight.w500,
            color: primaryColor,
            height: 1.0,
            letterSpacing: -1,
          ),
        ),
        SizedBox(width: size.getItemSpacing() / 4),
        Expanded(
          child: Column(
            crossAxisAlignment: textAlignment,
            children: [
              Text(
                weekday,
                textAlign:
                    textAlignment == CrossAxisAlignment.end
                        ? TextAlign.end
                        : TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: size.getSubtitleFontSize(),
                  fontWeight: FontWeight.w600,
                  color: theme.text,
                  height: 1.2,
                ),
              ),
              Text(
                '$month · $eventCount Events',
                textAlign:
                    textAlignment == CrossAxisAlignment.end
                        ? TextAlign.end
                        : TextAlign.start,
                style: TextStyle(
                  fontSize: size.getLegendFontSize(),
                  fontWeight: FontWeight.w500,
                  color: theme.textSub,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekCalendar extends StatelessWidget {
  final List<int> weekDates;
  final int currentDay;
  final int weekStartDay;
  final Color primaryColor;
  final HomeWidgetSize size;
  final bool isScrollable;

  const _WeekCalendar({
    required this.weekDates,
    required this.currentDay,
    required this.weekStartDay,
    required this.primaryColor,
    required this.size,
    this.isScrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        const int columns = 7;

        // 根据可用宽度计算单元格大小
        final cellWidth = availableWidth / columns;
        final cellHeight = cellWidth * 0.85; // 保持近方形比例
        final fontSize = (cellWidth * 0.5).clamp(8.0, 14.0);
        final circleSize = (cellWidth * 0.75).clamp(16.0, 24.0);

        // 计算行数
        final rowCount = (weekDates.length / columns).ceil();

        return Column(
          children: [
            // 星期标题行
            SizedBox(
              height: cellHeight * 0.7,
              child: Row(
                children: _buildWeekdayHeaders(
                  columns,
                  fontSize,
                  theme,
                ),
              ),
            ),
            SizedBox(height: size.getItemSpacing() / 4),
            // 日期网格
            ...List.generate(rowCount, (row) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: row < rowCount - 1 ? cellHeight * 0.15 : 0,
                ),
                child: SizedBox(
                  height: cellHeight,
                  child: Row(
                    children: _buildDateRow(
                      row,
                      columns,
                      cellWidth,
                      cellHeight,
                      fontSize,
                      circleSize,
                      theme,
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  /// 构建星期标题
  List<Widget> _buildWeekdayHeaders(
    int columns,
    double fontSize,
    AppThemeData theme,
  ) {
    final weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return List.generate(columns, (index) {
      return Expanded(
        child: Center(
          child: Text(
            weekdays[(weekStartDay + index) % 7],
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w400,
              color: theme.textSub,
            ),
          ),
        ),
      );
    });
  }

  /// 构建日期行
  List<Widget> _buildDateRow(
    int row,
    int columns,
    double cellWidth,
    double cellHeight,
    double fontSize,
    double circleSize,
    AppThemeData theme,
  ) {
    return List.generate(columns, (col) {
      final index = row * columns + col;

      if (index < weekDates.length) {
        final day = weekDates[index];
        final isCurrent = day == currentDay;
        final isPast = day < currentDay;

        return Expanded(
          child: Center(
            child: _buildDayWidget(
              day,
              isCurrent,
              isPast,
              primaryColor,
              fontSize,
              circleSize,
              theme,
            ),
          ),
        );
      } else {
        // 空单元格
        return Expanded(child: SizedBox(height: cellHeight));
      }
    });
  }

  Widget _buildDayWidget(
    int day,
    bool isCurrent,
    bool isPast,
    Color primaryColor,
    double fontSize,
    double circleSize,
    AppThemeData theme,
  ) {
    if (isCurrent) {
      // 今日：强调色浅底圆徽章 + 墨线描边
      return Container(
        width: circleSize,
        height: circleSize,
        decoration: dsSketchDecoration(
          theme: theme,
          circle: true,
          fillColor: primaryColor.withValues(alpha: 0.28),
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
          ),
        ),
      );
    }

    return Text(
      '$day',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: isPast ? FontWeight.w400 : FontWeight.w500,
        color: isPast ? theme.textSub : theme.text,
      ),
    );
  }
}

class _ReminderItem extends StatelessWidget {
  final String emoji;
  final String text;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _ReminderItem({
    required this.emoji,
    required this.text,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Row(
      children: [
        Transform.rotate(
          angle: -0.1,
          child: Text(
            emoji,
            style: TextStyle(fontSize: size.getSubtitleFontSize()),
          ),
        ),
        SizedBox(width: size.getItemSpacing() / 2),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: size.getLegendFontSize(),
              fontWeight: FontWeight.w500,
              color: theme.textSub,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventData event;
  final Animation<double> animation;
  final int index;
  final HomeWidgetSize size;

  const _EventCard({
    required this.event,
    required this.animation,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final itemAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(
        (0.15 + index * 0.12).clamp(0.0, 1.0),
        (0.6 + index * 0.12).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: itemAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: itemAnimation.value,
          child: Transform.translate(
            offset: Offset(10 * (1 - itemAnimation.value), 0),
            child: child,
          ),
        );
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 数据色竖条（事件分类色）
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: event.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: size.getPadding().left * 0.5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: size.getSubtitleFontSize(),
                      fontWeight: FontWeight.w600,
                      color: theme.text,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: size.getItemSpacing() / 4),
                  Row(
                    children: [
                      DsIcon(DsIconKind.calendar, size: 14, color: event.iconColor),
                      SizedBox(width: size.getItemSpacing() / 3),
                      Expanded(
                        child: Text(
                          '${event.time} · ${event.duration}${event.location != null ? ' · ${event.location}' : ''}',
                          style: TextStyle(
                            fontSize: size.getLegendFontSize(),
                            color: theme.textSub,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (event.buttonLabel != null) ...[
                    SizedBox(height: size.getItemSpacing() / 4),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        // 数据色浅底徽章 + 墨线描边
                        decoration: dsSketchDecoration(
                          theme: theme,
                          radius: BorderRadius.circular(8),
                          fillColor: event.color.withValues(alpha: 0.28),
                        ),
                        child: Text(
                          event.buttonLabel!,
                          style: TextStyle(
                            fontSize: size.getLegendFontSize(),
                            fontWeight: FontWeight.w700,
                            color: event.color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
