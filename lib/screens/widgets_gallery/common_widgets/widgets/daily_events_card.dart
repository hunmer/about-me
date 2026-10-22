/// 每日事件卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 星期 + 翻牌日期 / 事件色纸贴列表（数据色实底 + 墨线描边 +
/// 数据色竖条，逐项错峰浮现）。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import '../models/daily_event_data.dart';

/// 每日事件卡片小组件
///
/// 显示星期、日期和当日事件列表，支持动画效果
class DailyEventsCardWidget extends StatefulWidget {
  /// 星期标签
  final String weekday;

  /// 日期（几号）
  final int day;

  /// 事件数据列表
  final List<DailyEventData> events;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const DailyEventsCardWidget({
    super.key,
    required this.weekday,
    required this.day,
    required this.events,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从属性 Map 创建组件（用于公共小组件系统）
  static DailyEventsCardWidget fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final eventsList = props['events'] as List<dynamic>?;
    final events =
        eventsList
            ?.map((e) => DailyEventData.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return DailyEventsCardWidget(
      weekday: props['weekday'] as String? ?? 'Monday',
      day: props['day'] as int? ?? 1,
      events: events,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<DailyEventsCardWidget> createState() => _DailyEventsCardWidgetState();
}

class _DailyEventsCardWidgetState extends State<DailyEventsCardWidget>
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

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 200,
        height: widget.inline ? double.maxFinite : 220,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 星期和日期
            Container(
              margin: EdgeInsets.only(
                bottom: widget.size.getTitleSpacing(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.weekday,
                    style: TextStyle(
                      color: theme.danger,
                      fontSize: widget.size.getLegendFontSize(),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: widget.size.getSmallSpacing()),
                  AnimatedFlipCounter(
                    value: widget.day.toDouble() * _animation.value,
                    wholeDigits: 1,
                    fractionDigits: 0,
                    textStyle: TextStyle(
                      color: theme.text,
                      fontSize: widget.size.getLargeFontSize(),
                      fontWeight: FontWeight.w300,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            // 事件列表
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children:
                      widget.events.asMap().entries.map((entry) {
                        final index = entry.key;
                        final event = entry.value;
                        final itemAnimation = CurvedAnimation(
                          parent: _animationController,
                          curve: Interval(
                            0.2 + index * 0.25,
                            (0.6 + index * 0.2).clamp(0.0, 1.0),
                            curve: Curves.easeOutCubic,
                          ),
                        );

                        return _EventItem(
                          event: event,
                          animation: itemAnimation,
                          size: widget.size,
                          events: widget.events,
                        );
                      }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 事件项组件：事件数据色纸贴（实底 + 墨线描边 + 数据色竖条）
class _EventItem extends StatelessWidget {
  final DailyEventData event;
  final Animation<double> animation;
  final HomeWidgetSize size;
  final List<DailyEventData> events;

  const _EventItem({
    required this.event,
    required this.animation,
    required this.size,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(
          bottom: events.length > 1 ? size.getItemSpacing() : 0,
        ),
        height: size.getSubtitleFontSize() * 3.5,
        decoration: dsSketchDecoration(
          theme: theme,
          radius: BorderRadius.circular(8),
          fillColor: Color(event.backgroundColorLightValue),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              color: Color(event.colorValue),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(
                        color: Color(event.textColorLightValue),
                        fontSize: size.getLegendFontSize(),
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: size.getSmallSpacing()),
                    Text(
                      event.time,
                      style: TextStyle(
                        color: Color(event.subtextLightValue),
                        fontSize: size.getLegendFontSize() - 2,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
