import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/plugins/bill/widgets/month_selector.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/plugins/diary/models/diary_entry.dart';
import 'package:aboutme/plugins/diary/widgets/diary_calendar_palette.dart';
import 'package:aboutme/plugins/diary/widgets/diary_mood_face.dart';

/// 粉色圆角头部：问题标题 + 心情轮播 + 心情名 + 悬浮月份胶囊。
/// 心情筛选与月份切换通过回调交由宿主屏幕处理
/// （日历格渲染与日历控制器都在宿主侧）
class DiaryCalendarHeader extends StatefulWidget {
  final DiaryCalendarPalette palette;
  final DiaryEntry? selectedEntry;
  final DateTime focusedDay;

  /// 当前心情筛选（null 为不筛选）
  final DiaryMoodFaceKind? moodFilter;
  final ValueChanged<DiaryMoodFaceKind?> onMoodFilterChanged;

  /// 月份选择回调（弹窗已自动关闭，宿主负责更新日历显示）
  final ValueChanged<DateTime> onMonthSelected;

  /// 月份统计（篇数/字数），供月份选择弹窗展示
  final Map<String, double> Function(DateTime month) getMonthStats;
  final Widget Function(Map<String, double> stats) buildMonthStats;

  const DiaryCalendarHeader({
    super.key,
    required this.palette,
    required this.selectedEntry,
    required this.focusedDay,
    required this.onMoodFilterChanged,
    required this.onMonthSelected,
    required this.getMonthStats,
    required this.buildMonthStats,
    this.moodFilter,
  });

  @override
  State<DiaryCalendarHeader> createState() => _DiaryCalendarHeaderState();
}

class _DiaryCalendarHeaderState extends State<DiaryCalendarHeader> {
  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final mood = widget.selectedEntry?.mood;
    final centerSpec = mood != null ? diaryMoodSpecOf(mood) : neutralMoodSpec;
    final moodName =
        mood != null
            ? (diaryMoodNameKeys[mood]?.tr ?? mood)
            : 'diary_noMoodRecord'.tr;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
          decoration: BoxDecoration(
            color: palette.headerPink,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(36),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'diary_moodQuestion'.tr,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: palette.moodTitle,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 14),
              _buildMoodCarousel(palette, centerSpec),
              const SizedBox(height: 8),
              Text(
                moodName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: palette.moodTitle,
                ),
              ),
            ],
          ),
        ),
        // 悬浮月份胶囊，骑在头部底边上
        Positioned(
          left: 0,
          right: 0,
          bottom: -20,
          child: Center(child: _buildMonthPill(palette)),
        ),
      ],
    );
  }

  /// 心情轮播：中间大圆为选中日期的心情，两侧表情可点击筛选日历
  Widget _buildMoodCarousel(DiaryCalendarPalette palette, DiaryMoodSpec centerSpec) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCarouselFace(palette, '😴', size: 36),
        const SizedBox(width: 14),
        _buildCarouselFace(palette, '🥳', size: 40),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.centerRing,
            shape: BoxShape.circle,
          ),
          child: DiaryMoodFaceCircle(spec: centerSpec, size: 56),
        ),
        const SizedBox(width: 12),
        _buildCarouselFace(palette, '😍', size: 40),
        const SizedBox(width: 14),
        _buildCarouselFace(palette, '😱', size: 36),
      ],
    );
  }

  Widget _buildCarouselFace(
    DiaryCalendarPalette palette,
    String emoji, {
    required double size,
  }) {
    final spec = diaryMoodSpecOf(emoji);
    final active = widget.moodFilter == spec.kind;
    return GestureDetector(
      onTap: () =>
          widget.onMoodFilterChanged(active ? null : spec.kind),
      child: Opacity(
        opacity: active ? 1 : 0.92,
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? palette.pillBg : Colors.transparent,
          ),
          child: DiaryMoodFaceCircle(spec: spec, size: size),
        ),
      ),
    );
  }

  /// 白色月份胶囊按钮，点击弹出月份选择
  Widget _buildMonthPill(DiaryCalendarPalette palette) {
    return GestureDetector(
      onTap: _showMonthPickerSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: palette.pillBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.pillBorder),
          boxShadow: [
            BoxShadow(
              color: palette.pillShadow,
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 16,
              color: palette.textPrimary.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('yMMMM').format(
                DateTime(widget.focusedDay.year, widget.focusedDay.month),
              ),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: palette.textPrimary.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  /// 月份选择弹窗：复用账单插件的 MonthSelector（含日记统计）
  void _showMonthPickerSheet() {
    final theme = DSThemeBridge.resolve(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SizedBox(
        height: 130,
        child: MonthSelector(
          selectedMonth: widget.focusedDay,
          maxDate: DateTime.now(), // 限制不能选择未来月份
          primaryColor: theme.primary,
          getMonthStats: widget.getMonthStats,
          customStatsBuilder: widget.buildMonthStats,
          onMonthSelected: (month) {
            Navigator.pop(sheetContext);
            widget.onMonthSelected(month);
          },
        ),
      ),
    );
  }
}
