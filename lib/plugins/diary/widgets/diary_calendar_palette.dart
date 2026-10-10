import 'package:flutter/material.dart';

/// 日历页色板：浅色复刻设计稿（stitch_ui_style_replica_project），
/// 深色为同色相暗化版本
class DiaryCalendarPalette {
  final Color canvas; // 米白画布
  final Color headerPink; // 粉色头部
  final Color moodTitle; // 头部标题/心情名
  final Color textPrimary; // 主文字
  final Color textMuted; // 辅助文字
  final Color textOtherMonth; // 上下月补齐日期文字
  final Color emptyBubble; // 无日记空泡
  final Color entryBubble; // 有日记无心情的白圆
  final Color entryDot; // 白圆内小点
  final Color pillBg; // 月份胶囊底色
  final Color pillBorder;
  final Color pillShadow;
  final Color haloToday; // 今天光环
  final Color haloSelected; // 选中光环
  final Color centerRing; // 头部中心白圈

  const DiaryCalendarPalette({
    required this.canvas,
    required this.headerPink,
    required this.moodTitle,
    required this.textPrimary,
    required this.textMuted,
    required this.textOtherMonth,
    required this.emptyBubble,
    required this.entryBubble,
    required this.entryDot,
    required this.pillBg,
    required this.pillBorder,
    required this.pillShadow,
    required this.haloToday,
    required this.haloSelected,
    required this.centerRing,
  });

  static const light = DiaryCalendarPalette(
    canvas: Color(0xFFFBF9F5),
    headerPink: Color(0xFFFFAAB8),
    moodTitle: Color(0xFF2D282A),
    textPrimary: Color(0xFF2D282A),
    textMuted: Color(0xFF9E9895),
    textOtherMonth: Color(0xFFA8A29E),
    emptyBubble: Color(0xFFF2EEE7),
    entryBubble: Color(0xFFFFFFFF),
    entryDot: Color(0x592D282A),
    pillBg: Color(0xFFFFFFFF),
    pillBorder: Color(0xFFF1EDE7),
    pillShadow: Color(0x26E68C9B),
    haloToday: Color(0xFFFFFFFF),
    haloSelected: Color(0xE6FFAAB8),
    centerRing: Color(0x66FFFFFF),
  );

  static const dark = DiaryCalendarPalette(
    canvas: Color(0xFF262223),
    headerPink: Color(0xFF7A545C),
    moodTitle: Color(0xFFF5EFEA),
    textPrimary: Color(0xFFEDE7E3),
    textMuted: Color(0xFF948D89),
    textOtherMonth: Color(0xFF6B6562),
    emptyBubble: Color(0xFF322D2E),
    entryBubble: Color(0xFF3A3436),
    entryDot: Color(0x8C8D8580),
    pillBg: Color(0xFF332E30),
    pillBorder: Color(0xFF453E41),
    pillShadow: Color(0x40000000),
    haloToday: Color(0xFF262223),
    haloSelected: Color(0xFFFFAAB8),
    centerRing: Color(0x1FFFFFFF),
  );

  static DiaryCalendarPalette of(bool isDark) => isDark ? dark : light;
}
