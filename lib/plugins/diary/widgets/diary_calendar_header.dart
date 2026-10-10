import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/plugins/bill/widgets/month_selector.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/plugins/diary/models/diary_entry.dart';
import 'package:aboutme/plugins/diary/widgets/diary_calendar_palette.dart';
import 'package:aboutme/plugins/diary/widgets/diary_mood_face.dart';

/// 粉色圆角头部：问题标题 + 横向滚动心情列表 + 心情提示 + 悬浮月份胶囊。
/// 点击表情由宿主处理（今日未记录则打开编辑页，已记录则显示提示）
class DiaryCalendarHeader extends StatefulWidget {
  final DiaryCalendarPalette palette;
  final DiaryEntry? selectedEntry;
  final DateTime focusedDay;

  /// 今日已记录的心情（列表中高亮该表情）
  final String? todayMood;

  /// 点击表情回调（emoji）
  final ValueChanged<String> onMoodTap;

  /// 覆盖心情名的提示文案（如「你今日的心情为 😊 开心」），null 时显示选中日心情
  final String? noticeText;

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
    required this.onMoodTap,
    required this.onMonthSelected,
    required this.getMonthStats,
    required this.buildMonthStats,
    this.todayMood,
    this.noticeText,
  });

  @override
  State<DiaryCalendarHeader> createState() => _DiaryCalendarHeaderState();
}

class _DiaryCalendarHeaderState extends State<DiaryCalendarHeader> {
  final ScrollController _moodScrollController = ScrollController();

  // 表情项步进宽度（44 表情 + 12 间距），用于计算中间放大系数
  static const double _kItemExtent = 56.0;
  static const double _kListPadding = 8.0;

  @override
  void dispose() {
    _moodScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final mood = widget.selectedEntry?.mood;
    final moodName = mood != null
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
              _buildMoodScroller(palette),
              const SizedBox(height: 8),
              Text(
                widget.noticeText ?? moodName,
                textAlign: TextAlign.center,
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

  /// 可左右滚动的心情列表（全部表情）：位于视口中间的表情放大，
  /// 点击交给宿主处理；今日已记录的心情白圈高亮。
  /// 鼠标指针手型 + 不透明命中区域，修复桌面端点击无响应
  Widget _buildMoodScroller(DiaryCalendarPalette palette) {
    return SizedBox(
      height: 64,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth;
          return AnimatedBuilder(
            animation: _moodScrollController,
            builder: (context, _) {
              return ListView.separated(
                controller: _moodScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: _kListPadding),
                itemCount: diaryMoodEmojis.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final emoji = diaryMoodEmojis[index];
                  final spec = diaryMoodSpecOf(emoji);
                  final isTodayMood = emoji == widget.todayMood;

                  // 中间放大：item 中心离视口中心越近缩放越大
                  final itemCenter = _kListPadding + index * _kItemExtent + 22;
                  final scrollOffset = _moodScrollController.hasClients
                      ? _moodScrollController.offset
                      : 0.0;
                  final viewportCenter = scrollOffset + viewportWidth / 2;
                  final distance = (itemCenter - viewportCenter).abs();
                  final t = (distance / (viewportWidth / 2)).clamp(0.0, 1.0);
                  final scale = 1.0 + 0.35 * (1.0 - t);

                  return Center(
                    child: Transform.scale(
                      scale: scale,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onMoodTap(emoji),
                          child: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isTodayMood
                                  ? palette.pillBg
                                  : Colors.transparent,
                              boxShadow: isTodayMood
                                  ? [
                                      BoxShadow(
                                        color: palette.haloSelected,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: DiaryMoodFaceCircle(
                              spec: spec,
                              size: isTodayMood ? 50 : 44,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
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
