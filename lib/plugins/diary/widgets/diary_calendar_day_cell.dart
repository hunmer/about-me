import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:aboutme/plugins/diary/models/diary_entry.dart';
import 'package:aboutme/plugins/diary/widgets/diary_calendar_palette.dart';
import 'package:aboutme/plugins/diary/widgets/diary_mood_face.dart';

/// 从日记内容中提取 Markdown 图片链接 ![alt](url)
List<String> extractImagesFromContent(String content) {
  final regex = RegExp(r'!\[.*?\]\((.*?)\)');
  final matches = regex.allMatches(content);
  return matches.map((m) => m.group(1)!).toList();
}

/// 日历格：马卡龙色心情圆 + 下方日期；✦ 标记含图片的日记。
/// 格子高度由 SfCalendar 决定（行数不同会变化），
/// 内部用 FittedBox 整体缩放，保证内容永不溢出
class DiaryCalendarDayCell extends StatelessWidget {
  final DiaryCalendarPalette palette;
  final DateTime day;
  final DiaryEntry? entry;
  final bool isSelected;
  final bool isToday;
  final bool isOtherMonth;
  final bool isFuture;

  const DiaryCalendarDayCell({
    super.key,
    required this.palette,
    required this.day,
    required this.entry,
    required this.isSelected,
    required this.isToday,
    required this.isOtherMonth,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    // 取局部变量以便空安全提升（实例字段不参与 flow analysis）
    final entry = this.entry;
    final spec = entry?.mood != null ? diaryMoodSpecOf(entry!.mood!) : null;

    var opacity = 1.0;
    if (isOtherMonth) opacity = 0.55;
    if (isFuture) opacity = math.min(opacity, 0.35);

    final hasImages =
        entry != null && extractImagesFromContent(entry.content).isNotEmpty;

    return Opacity(
      opacity: opacity,
      child: Center(
        // 上下留白形成日期行间隔，FittedBox 保证内容不溢出
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.5),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildDayCircle(spec),
                    if (hasImages)
                      const Positioned(
                        top: -4,
                        right: -5,
                        child: Text(
                          '✦',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFBBF24),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        (isToday || isSelected) ? FontWeight.w800 : FontWeight.w600,
                    // 提高可视度：常规日期也用主文字色
                    color:
                        isOtherMonth
                            ? palette.textOtherMonth
                            : palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 圆形心情图标；无日记时为米白空泡
  Widget _buildDayCircle(DiaryMoodSpec? spec) {
    Widget circle;
    if (spec != null) {
      circle = DiaryMoodFaceCircle(spec: spec, size: 30);
    } else if (entry != null) {
      // 有日记但没选心情：白圆 + 小圆点
      circle = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: palette.entryBubble,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: palette.entryDot,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    } else {
      // 无日记：emptyBubble 圆形背景占位
      circle = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: palette.emptyBubble,
          shape: BoxShape.circle,
        ),
      );
    }

    // 选中日加粉色光环、今天加浅色光环
    if (isSelected || isToday) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isSelected ? palette.haloSelected : palette.haloToday,
              spreadRadius: isSelected ? 3 : 2,
            ),
          ],
        ),
        child: circle,
      );
    }
    return circle;
  }
}
