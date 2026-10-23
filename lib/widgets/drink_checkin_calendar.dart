import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import 'package:aboutme/widgets/aboutme_sf_calendar/aboutme_sf_calendar.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 饮品打卡日历 Demo
///
/// 复刻 HTML 原型：SfCalendar 月视图自定义格子（贴纸/数字）+ 打卡记录卡
/// + 绿色胶囊 FAB + SmoothBottomSheet 打卡弹层（日期胶囊 + 贴纸选择器）。
class DrinkCheckinCalendarDemo extends StatefulWidget {
  const DrinkCheckinCalendarDemo({super.key});

  @override
  State<DrinkCheckinCalendarDemo> createState() =>
      _DrinkCheckinCalendarDemoState();
}

class _DrinkCheckinCalendarDemoState extends State<DrinkCheckinCalendarDemo> {
  static const _bgPage = Color(0xFFF7F8F5);
  static const _bgCell = Color(0xFFEAEDE7);
  static const _textPrimary = Color(0xFF111111);
  static const _textCell = Color(0xFF1D201D);
  static const _textMuted = Color(0xFF9DA5A0);
  static const _textDateHeader = Color(0xFF6B706B);
  static const _greenAccent = Color(0xFF80A827);
  static const _greenText = Color(0xFF80A63E);

  final _calendarController = CalendarController();
  late DateTime _visibleMonth;

  /// key: 日期（仅年月日）
  late final Map<DateTime, _DrinkRecord> _records;

  @override
  void initState() {
    super.initState();
    // 原型数据：2026 年 2 月（2 月 1 日为周日，共 28 天）
    _visibleMonth = DateTime(2026, 2);
    _records = {
      for (final e in _seedFeb2026.entries) DateTime(2026, 2, e.key): e.value,
    };
  }

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: SafeArea(
        child: Stack(
          children: [
            // 原型为移动端布局，限制最大宽度避免宽屏格子被拉伸过高
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  children: [
                    _buildMonthHeader(),
                    _buildWeekdayRow(),
                    _buildCalendar(),
                    Expanded(child: _buildRecordsCard()),
                  ],
                ),
              ),
            ),
            _buildBottomOverlay(),
          ],
        ),
      ),
    );
  }

  // ============ 顶部月份切换 ============

  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _arrowButton(Icons.chevron_left, () => _shiftMonth(-1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${_visibleMonth.month}月',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
                height: 1,
              ),
            ),
          ),
          _arrowButton(Icons.chevron_right, () => _shiftMonth(1)),
        ],
      ),
    );
  }

  Widget _arrowButton(IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 20, color: const Color(0xFF222222)),
      ),
    );
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    _calendarController.displayDate = next;
    setState(() => _visibleMonth = next);
  }

  // ============ 星期表头（隐藏 SfCalendar 自带表头，自绘不受本地化影响）============

  Widget _buildWeekdayRow() {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Row(
        children: [
          for (final label in labels)
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: _textMuted,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============ 月历格子（SfCalendar + monthCellBuilder 自定义样式）============

  Widget _buildCalendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      // 6 行格子，格子宽高比约 1:1.24
      child: AspectRatio(
        aspectRatio: 7 / (6 * 1.24),
        child: AboutmeSfCalendar(
          controller: _calendarController,
          view: CalendarView.month,
          initialDisplayDate: _visibleMonth,
          firstDayOfWeek: 1,
          headerHeight: 0,
          viewHeaderHeight: 0,
          backgroundColor: _bgPage,
          cellBorderColor: Colors.transparent,
          todayHighlightColor: _greenAccent,
          selectionDecoration: const BoxDecoration(),
          allowViewNavigation: false,
          showNavigationArrow: false,
          showTrailingAndLeadingDates: false,
          numberOfWeeksInView: 6,
          monthCellBuilder: _monthCellBuilder,
          onViewChanged: (details) {
            final date = details.visibleDates.first;
            final month = DateTime(date.year, date.month);
            if (month != _visibleMonth) {
              setState(() => _visibleMonth = month);
            }
          },
          onTap: (details) {
            final date = details.date;
            if (date != null && date.month == _visibleMonth.month) {
              _openCheckinSheet(date);
            }
          },
        ),
      ),
    );
  }

  Widget _monthCellBuilder(BuildContext context, MonthCellDetails details) {
    final date = details.date;
    if (date.month != _visibleMonth.month) return const SizedBox.shrink();

    final record = _records[_dayKey(date)];
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          color: _bgCell,
          borderRadius: BorderRadius.circular(10),
        ),
        child: record == null
            ? Center(
                child: Text(
                  '${date.day}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _textCell,
                    letterSpacing: -0.2,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(4),
                child: _DrinkSticker(stickerKey: record.sticker),
              ),
      ),
    );
  }

  // ============ 底部打卡记录白卡 ============

  Widget _buildRecordsCard() {
    final days =
        _records.keys
            .where(
              (d) => d.year == _visibleMonth.year && d.month == _visibleMonth.month,
            )
            .toList()
          ..sort((a, b) => b.compareTo(a));

    return Container(
      margin: const EdgeInsets.only(top: 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 96),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final record = _records[day]!;
          return Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${day.month}月${day.day}日',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _textDateHeader,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _openCheckinSheet(day),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 46,
                          height: 46,
                          child: _DrinkSticker(stickerKey: record.sticker),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E201D),
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                record.time,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${record.mg}',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: _greenText,
                                height: 1.1,
                              ),
                            ),
                            const Text(
                              'mg',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============ 底部渐变遮罩 + 绿色胶囊 FAB ============

  Widget _buildBottomOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 92,
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 22),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.65, 1],
              colors: [
                Color(0x00FFFFFF),
                Color(0xC7FFFFFF),
                Color(0xF5FFFFFF),
              ],
            ),
          ),
          child: GestureDetector(
            onTap: _openSheetForNextEmptyDay,
            child: Container(
              width: 98,
              height: 52,
              decoration: BoxDecoration(
                color: _greenAccent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x5C80A727),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }

  void _openSheetForNextEmptyDay() {
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_visibleMonth.year, _visibleMonth.month, d);
      if (!_records.containsKey(date)) {
        _openCheckinSheet(date);
        return;
      }
    }
    _openCheckinSheet(DateTime(_visibleMonth.year, _visibleMonth.month));
  }

  // ============ 打卡弹层（SmoothBottomSheet）============

  void _openCheckinSheet(DateTime initialDay) {
    var activeDay = initialDay;
    final existing = _records[_dayKey(initialDay)];
    var selectedPreset = 0;
    if (existing != null) {
      final idx = _presetOptions.indexWhere((p) => p.sticker == existing.sticker);
      if (idx >= 0) selectedPreset = idx;
    }

    SmoothBottomSheet.show(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final daysInMonth = DateTime(
              _visibleMonth.year,
              _visibleMonth.month + 1,
              0,
            ).day;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${activeDay.month}月${activeDay.day}日 · 饮品打卡',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: _textCell,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '选择一款饮品贴纸完成当日打卡',
                              style: TextStyle(fontSize: 12.5, color: _textMuted),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(sheetContext).pop(),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF2F4F0),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: _textDateHeader,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 日期胶囊选择器
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: daysInMonth,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final date = DateTime(
                          _visibleMonth.year,
                          _visibleMonth.month,
                          index + 1,
                        );
                        final isCurrent = date == _dayKey(activeDay);
                        final hasRecord = _records.containsKey(date);
                        return GestureDetector(
                          onTap: () => setSheetState(() {
                            activeDay = date;
                            final rec = _records[date];
                            final idx = rec == null
                                ? -1
                                : _presetOptions.indexWhere(
                                    (p) => p.sticker == rec.sticker,
                                  );
                            if (idx >= 0) selectedPreset = idx;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? _greenAccent
                                  : hasRecord
                                  ? _bgCell
                                  : const Color(0xFFF5F6F4),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${date.month}月${date.day}日',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isCurrent
                                    ? Colors.white
                                    : hasRecord
                                    ? _textCell
                                    : _textMuted,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 贴纸选择网格
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.82,
                        ),
                    itemCount: _presetOptions.length,
                    itemBuilder: (context, index) {
                      final preset = _presetOptions[index];
                      final isSelected = index == selectedPreset;
                      return GestureDetector(
                        onTap: () =>
                            setSheetState(() => selectedPreset = index),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected ? _bgCell : _bgPage,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: _greenAccent, width: 2)
                                : null,
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: _DrinkSticker(
                                  stickerKey: preset.sticker,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                preset.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: _textCell,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // 操作按钮
                  Row(
                    children: [
                      Expanded(
                        child: _sheetButton(
                          label: '恢复数字显示',
                          color: const Color(0xFFF2F4F0),
                          textColor: _textDateHeader,
                          onTap: () {
                            setState(() => _records.remove(_dayKey(activeDay)));
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _sheetButton(
                          label: '完成打卡',
                          color: _greenAccent,
                          textColor: Colors.white,
                          onTap: () {
                            final preset = _presetOptions[selectedPreset];
                            final now = TimeOfDay.now();
                            final timeStr =
                                '${now.hour.toString().padLeft(2, '0')}:'
                                '${now.minute.toString().padLeft(2, '0')}';
                            setState(() {
                              final key = _dayKey(activeDay);
                              _records[key] = _DrinkRecord(
                                sticker: preset.sticker,
                                name: preset.name,
                                time: _records[key]?.time ?? timeStr,
                                mg: preset.mg,
                              );
                            });
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetButton({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ============ 数据模型 ============

class _DrinkRecord {
  final String sticker;
  final String name;
  final String time;
  final int mg;

  const _DrinkRecord({
    required this.sticker,
    required this.name,
    required this.time,
    required this.mg,
  });
}

class _DrinkPreset {
  final String sticker;
  final String name;
  final int mg;

  const _DrinkPreset(this.sticker, this.name, this.mg);
}

/// 贴纸渲染：flutter_svg 不支持 SVG 的 text 元素，Peet's 杯身字样用 Text 叠加
class _DrinkSticker extends StatelessWidget {
  final String stickerKey;

  const _DrinkSticker({required this.stickerKey});

  @override
  Widget build(BuildContext context) {
    final svg = _drinkStickers[stickerKey]!;
    final picture = SvgPicture.string(svg, fit: BoxFit.contain);
    if (stickerKey != 'peets_coffee') return picture;
    return Stack(
      fit: StackFit.expand,
      children: [
        picture,
        const Align(
          alignment: Alignment(0, 0.35),
          child: Text(
            "Peet's",
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: Color(0xFFEAE2DC),
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

// ============ 预置饮品选项 ============

const _presetOptions = [
  _DrinkPreset('topdown_latte_art', '拿铁', 75),
  _DrinkPreset('tall_matcha_smoothie', 'Milktea', 0),
  _DrinkPreset('red_lemon_cocktail', '红宝石果茶', 0),
  _DrinkPreset('cup_saucer_latte', '热拿铁', 75),
  _DrinkPreset('iced_matcha_glass', '冰抹茶拿铁', 45),
  _DrinkPreset('dirty_coffee_glass', 'Dirty 咖啡', 110),
  _DrinkPreset('caramel_macchiato', '焦糖玛奇朵', 85),
  _DrinkPreset('pink_strawberry_frappe', '草莓冰沙', 0),
  _DrinkPreset('mocha_frappe_straw', '摩卡星冰乐', 65),
  _DrinkPreset('matcha_icecream_cone', '抹茶甜筒', 15),
  _DrinkPreset('boba_milk_tea', '珍珠奶茶', 50),
  _DrinkPreset('orange_cream_tea', '泰式雪顶茶', 40),
  _DrinkPreset('green_popsicle', '蜜瓜雪糕', 0),
  _DrinkPreset('peets_coffee', "Peet's 咖啡", 150),
  _DrinkPreset('pink_soft_serve', '草莓甜筒', 0),
];

/// 原型初始数据（2026 年 2 月）
const _seedFeb2026 = {
  1: _DrinkRecord(
    sticker: 'cup_saucer_latte',
    name: '热拿铁',
    time: '09:15',
    mg: 75,
  ),
  3: _DrinkRecord(
    sticker: 'iced_matcha_glass',
    name: '冰抹茶拿铁',
    time: '14:20',
    mg: 45,
  ),
  4: _DrinkRecord(
    sticker: 'dirty_coffee_glass',
    name: 'Dirty 咖啡',
    time: '10:30',
    mg: 110,
  ),
  6: _DrinkRecord(
    sticker: 'caramel_macchiato',
    name: '焦糖玛奇朵',
    time: '15:10',
    mg: 85,
  ),
  7: _DrinkRecord(
    sticker: 'pink_strawberry_frappe',
    name: '草莓奶昔冰沙',
    time: '16:45',
    mg: 0,
  ),
  9: _DrinkRecord(
    sticker: 'mocha_frappe_straw',
    name: '摩卡可可星冰乐',
    time: '13:50',
    mg: 65,
  ),
  10: _DrinkRecord(
    sticker: 'matcha_icecream_cone',
    name: '抹茶脆筒冰淇淋',
    time: '15:30',
    mg: 15,
  ),
  11: _DrinkRecord(
    sticker: 'boba_milk_tea',
    name: '波霸珍珠奶茶',
    time: '17:12',
    mg: 50,
  ),
  12: _DrinkRecord(
    sticker: 'orange_cream_tea',
    name: '泰式雪顶冰茶',
    time: '14:05',
    mg: 40,
  ),
  13: _DrinkRecord(
    sticker: 'green_popsicle',
    name: '蜜瓜雪糕',
    time: '19:20',
    mg: 0,
  ),
  14: _DrinkRecord(
    sticker: 'peets_coffee',
    name: "Peet's 冰美式",
    time: '10:08',
    mg: 150,
  ),
  17: _DrinkRecord(
    sticker: 'pink_soft_serve',
    name: '粉白双旋甜筒',
    time: '16:10',
    mg: 0,
  ),
  19: _DrinkRecord(
    sticker: 'red_lemon_cocktail',
    name: '红宝石柠檬特调',
    time: '20:15',
    mg: 0,
  ),
  20: _DrinkRecord(
    sticker: 'tall_matcha_smoothie',
    name: 'Milktea',
    time: '16:34',
    mg: 0,
  ),
  22: _DrinkRecord(
    sticker: 'topdown_latte_art',
    name: '拿铁',
    time: '16:37',
    mg: 75,
  ),
};

// ============ 饮品贴纸 SVG ============

const _drinkStickers = {
  'cup_saucer_latte': '''
<svg viewBox="0 0 64 64">
  <ellipse cx="31" cy="44" rx="22" ry="7.5" fill="#D5D2CD"/>
  <ellipse cx="31" cy="42.8" rx="21" ry="6.5" fill="#F4F2EE"/>
  <ellipse cx="31" cy="43" rx="13" ry="3.8" fill="#DFDCD6"/>
  <path d="M45 29 C53 29, 53 39, 44 39" fill="none" stroke="#EAE7E1" stroke-width="3.4" stroke-linecap="round"/>
  <path d="M14 27 C14 41, 21 44, 31 44 C41 44, 48 41, 48 27 Z" fill="#F7F5F0"/>
  <path d="M16 32 C18 41, 24 43.5, 31 43.5 C38 43.5, 44 41, 46 32" fill="#E5E1DA" opacity="0.6"/>
  <ellipse cx="31" cy="27" rx="17" ry="5.5" fill="#FFFFFF"/>
  <ellipse cx="31" cy="27" rx="15.4" ry="4.6" fill="#C67D43"/>
  <ellipse cx="31" cy="26.8" rx="10.5" ry="3" fill="#F3DEC3"/>
  <path d="M25 26.8 Q31 24.5 37 26.8 Q31 29.2 25 26.8 Z" fill="#FFFDF9"/>
  <path d="M31 24.5 L31 29.2" stroke="#B86B35" stroke-width="0.8"/>
</svg>
''',
  'iced_matcha_glass': '''
<svg viewBox="0 0 64 64">
  <defs>
    <linearGradient id="matchaGrad3" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#A8CE78"/>
      <stop offset="35%" stop-color="#699B34"/>
      <stop offset="100%" stop-color="#2D5712"/>
    </linearGradient>
  </defs>
  <path d="M15 14 L17 50 C17.5 55, 23 58, 32 58 C41 58, 46.5 55, 47 50 L49 14 Z" fill="url(#matchaGrad3)" stroke="#E3ECD8" stroke-width="1.5"/>
  <path d="M17 20 Q25 27 33 21 Q41 16 47 23 L46 36 Q36 30 27 37 Q20 34 17 28 Z" fill="#DCECC3" opacity="0.65"/>
  <rect x="20" y="18" width="9" height="7" rx="2" fill="#FFFFFF" opacity="0.75" transform="rotate(-8 24 21)"/>
  <rect x="32" y="19" width="10" height="7.5" rx="2" fill="#FFFFFF" opacity="0.7" transform="rotate(6 37 22)"/>
  <rect x="25" y="27" width="9" height="7" rx="2" fill="#EBF5DF" opacity="0.5"/>
  <ellipse cx="32" cy="14" rx="17" ry="4.5" fill="#CBE0B0" stroke="#FFFFFF" stroke-width="1.2"/>
  <ellipse cx="32" cy="14" rx="15" ry="3.2" fill="#78A841"/>
  <path d="M19 20 L20.5 48" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" opacity="0.55"/>
  <path d="M19 52 Q32 56 45 52" fill="none" stroke="#1B3A09" stroke-width="2.5" stroke-linecap="round"/>
</svg>
''',
  'dirty_coffee_glass': '''
<svg viewBox="0 0 64 64">
  <defs>
    <linearGradient id="dirtyGrad4" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#D79447"/>
      <stop offset="22%" stop-color="#7A3E18"/>
      <stop offset="75%" stop-color="#361809"/>
      <stop offset="100%" stop-color="#220E05"/>
    </linearGradient>
  </defs>
  <ellipse cx="32" cy="52.5" rx="11.5" ry="3.5" fill="#C9C5C0"/>
  <path d="M15 18 L20 50 C20.5 53, 25 54.5, 32 54.5 C39 54.5, 43.5 53, 44 50 L49 18 Z" fill="url(#dirtyGrad4)"/>
  <path d="M15.3 18 L16.5 26 C22 28.5, 42 28.5, 47.5 26 L48.7 18 Z" fill="#DDA059"/>
  <ellipse cx="32" cy="18" rx="17" ry="5" fill="#E8B270" stroke="#F5E6D3" stroke-width="1"/>
  <ellipse cx="27" cy="17.5" rx="4" ry="2" fill="#8C481B"/>
  <ellipse cx="36" cy="18.8" rx="5" ry="2" fill="#A65A28"/>
  <ellipse cx="32" cy="16.2" rx="3" ry="1.3" fill="#F9DEC0"/>
  <path d="M19 24 L22 47" stroke="#FFFFFF" stroke-width="1.8" stroke-linecap="round" opacity="0.4"/>
</svg>
''',
  'caramel_macchiato': '''
<svg viewBox="0 0 64 64">
  <defs>
    <linearGradient id="macchiatoGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#F6EFEA"/>
      <stop offset="25%" stop-color="#C96B27"/>
      <stop offset="58%" stop-color="#DF9B5C"/>
      <stop offset="85%" stop-color="#F1E4D8"/>
      <stop offset="100%" stop-color="#D7C3B2"/>
    </linearGradient>
  </defs>
  <path d="M17 13 L20 53 C20.5 56, 25 58, 32 58 C39 58, 43.5 56, 44 53 L47 13 Z" fill="url(#macchiatoGrad)" stroke="#E6DDD6" stroke-width="1"/>
  <path d="M18 22 Q26 26 32 23 Q39 20 46 23 L45 39 Q37 42 30 37 Q23 41 19 37 Z" fill="#9E4212" opacity="0.85"/>
  <path d="M19.5 41 Q27 38 34 42 Q40 44 44.5 40 L43.8 52 C43 55, 38 56.5, 32 56.5 C26 56.5, 21 55, 20.2 52 Z" fill="#EFE4DA"/>
  <ellipse cx="32" cy="13.5" rx="15" ry="4.5" fill="#FBF7F4" stroke="#E0C9B6" stroke-width="1"/>
  <path d="M20 13.5 C23 9, 30 9.5, 34 12 C38 9.5, 43 11, 44 14 C39 17, 25 17, 20 13.5 Z" fill="#FFFFFF"/>
  <path d="M21 13 Q28 10 35 15 Q40 12 43 14" fill="none" stroke="#B64912" stroke-width="2" stroke-linecap="round"/>
  <path d="M20 19 L22 50" stroke="#FFFFFF" stroke-width="1.8" stroke-linecap="round" opacity="0.55"/>
</svg>
''',
  'pink_strawberry_frappe': '''
<svg viewBox="0 0 64 64">
  <defs>
    <linearGradient id="pinkGrad7" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FAD4DC"/>
      <stop offset="55%" stop-color="#F49CB0"/>
      <stop offset="90%" stop-color="#E75879"/>
      <stop offset="100%" stop-color="#B91D47"/>
    </linearGradient>
  </defs>
  <path d="M17 19 L21 54 C21.5 56.5, 26 58, 32 58 C38 58, 42.5 56.5, 43 54 L47 19 Z" fill="url(#pinkGrad7)"/>
  <path d="M21 48 Q27 45 33 49 Q39 46 43 49 L42.5 54 C41.5 56.5, 37 57.5, 32 57.5 C27 57.5, 22.5 56.5, 21.5 54 Z" fill="#B5173E"/>
  <circle cx="26" cy="44" r="1.5" fill="#C9234B"/>
  <circle cx="35" cy="41" r="1.3" fill="#C9234B"/>
  <circle cx="30" cy="34" r="1.2" fill="#D94368"/>
  <path d="M16 19 C17 11, 25 9, 32 9 C39 9, 47 11, 48 19 Z" fill="#FCE2E8"/>
  <path d="M20 16 Q26 12 32 14 Q38 11 44 16" fill="none" stroke="#F293A9" stroke-width="1.6" stroke-linecap="round"/>
  <ellipse cx="32" cy="19" rx="16.5" ry="3.2" fill="#FFFFFF" opacity="0.85"/>
  <ellipse cx="32" cy="19" rx="15" ry="2.3" fill="#F7B7C6"/>
  <path d="M20 24 L23 51" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" opacity="0.6"/>
</svg>
''',
  'mocha_frappe_straw': '''
<svg viewBox="0 0 64 64">
  <path d="M41 7 L36 22" stroke="#3B2B28" stroke-width="3.2" stroke-linecap="round"/>
  <path d="M18 22 L21 54 C21.5 56.5, 26 58, 32 58 C38 58, 42.5 56.5, 43 54 L46 22 Z" fill="#C68B59"/>
  <path d="M19 25 L21 48 L24 49 L22 25 Z" fill="#3B1A0E"/>
  <path d="M27 26 L28 52 L32 52 L31 26 Z" fill="#4A2112"/>
  <path d="M36 25 L35 49 L39 48 L41 25 Z" fill="#3B1A0E"/>
  <path d="M21 51 C24 56, 40 56, 43 51 L42.5 54.5 C41 57, 37 58, 32 58 C27 58, 23 57, 21.5 54.5 Z" fill="#592A17"/>
  <path d="M17 22 C17 13, 24 11, 32 11 C40 11, 47 13, 47 22 Z" fill="#FAF3EB"/>
  <path d="M20 18 Q26 13 33 17 Q39 13 44 18" fill="none" stroke="#4D2212" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M23 14 Q32 10 40 15" fill="none" stroke="#6E351F" stroke-width="1.5" stroke-linecap="round"/>
  <ellipse cx="32" cy="22" rx="15.5" ry="2.8" fill="#EFE6DC"/>
</svg>
''',
  'matcha_icecream_cone': '''
<svg viewBox="0 0 64 64">
  <path d="M22 33 L32 59 L42 33 Z" fill="#D59B58"/>
  <path d="M24 35 L39 42 M26 42 L36 47 M28 49 L34 52 M39 35 L25 43 M37 42 L28 49" stroke="#B67832" stroke-width="1.1"/>
  <path d="M20 31 L44 31 L42 35 L22 35 Z" fill="#DFAA6B"/>
  <path d="M20 31 C18 26, 23 23, 32 24 C41 23, 46 26, 44 31 C39 33, 25 33, 20 31 Z" fill="#7CB93E"/>
  <path d="M22 25 C20 20, 25 17, 32 18 C39 17, 44 20, 42 25 C37 27, 27 27, 22 25 Z" fill="#89C848"/>
  <path d="M25 19 C24 14, 28 12, 32 12 C36 12, 40 14, 39 19 C35 20.5, 29 20.5, 25 19 Z" fill="#97D555"/>
  <path d="M28 13 C28 9, 31 6, 33 5 C34 8, 37 10, 36 13 Z" fill="#A5E063"/>
  <path d="M23 25 Q32 28 41 25" fill="none" stroke="#5E9626" stroke-width="1.2"/>
  <path d="M26 19 Q32 21 38 19" fill="none" stroke="#5E9626" stroke-width="1.2"/>
</svg>
''',
  'boba_milk_tea': '''
<svg viewBox="0 0 64 64">
  <path d="M16 21 C16 10, 48 10, 48 21 Z" fill="#F5E6DF" stroke="#E5D4CB" stroke-width="1.2"/>
  <ellipse cx="32" cy="14" rx="8" ry="2.5" fill="#E9ACA0" opacity="0.6"/>
  <path d="M16 21 L20 53 C20.5 56, 25 58, 32 58 C39 58, 43.5 56, 44 53 L48 21 Z" fill="#DFCBB5"/>
  <path d="M16.5 21 L18 31 C24 33, 40 33, 46 31 L47.5 21 Z" fill="#F3ECE2"/>
  <rect x="14.5" y="19.5" width="35" height="3" rx="1.5" fill="#F7F4F0"/>
  <path d="M20 49 C23 47, 41 47, 44 49 L43.5 53.5 C42.5 56.5, 38 58, 32 58 C26 58, 21.5 56.5, 20.5 53.5 Z" fill="#2A1710"/>
  <circle cx="24" cy="51" r="2.6" fill="#1A0D08"/>
  <circle cx="30" cy="53" r="2.8" fill="#3D2216"/>
  <circle cx="36" cy="51.5" r="2.6" fill="#1A0D08"/>
  <circle cx="40" cy="53.5" r="2.3" fill="#2A1710"/>
  <circle cx="27" cy="48.5" r="2.2" fill="#3D2216"/>
  <circle cx="31" cy="40" r="3.5" fill="none" stroke="#362A23" stroke-width="1.3"/>
  <circle cx="30" cy="39.5" r="0.8" fill="#362A23"/>
  <path d="M34 38 L37 36" stroke="#362A23" stroke-width="1.2" stroke-linecap="round"/>
</svg>
''',
  'orange_cream_tea': '''
<svg viewBox="0 0 64 64">
  <defs>
    <linearGradient id="orangeTea12" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#F7A440"/>
      <stop offset="55%" stop-color="#E87A1E"/>
      <stop offset="100%" stop-color="#C95208"/>
    </linearGradient>
  </defs>
  <path d="M17 22 L21 54 C21.5 56.5, 26 58, 32 58 C38 58, 42.5 56.5, 43 54 L47 22 Z" fill="url(#orangeTea12)"/>
  <path d="M18 24 Q24 35 28 27 Q33 38 38 28 Q42 35 46 24 Z" fill="#FDEBD2" opacity="0.85"/>
  <ellipse cx="26" cy="41" rx="3.5" ry="5" fill="#FDEBD2" opacity="0.55"/>
  <path d="M16 22 C16 14, 22 12, 26 11 C28 7, 36 7, 38 11 C42 12, 48 14, 48 22 Z" fill="#FFFDFB"/>
  <path d="M21 18 Q28 14 35 18 Q40 15 44 18" fill="none" stroke="#F0DEC8" stroke-width="1.5" stroke-linecap="round"/>
  <rect x="15" y="20.5" width="34" height="2.8" rx="1.4" fill="#FFFFFF"/>
  <path d="M21 27 L23 51" stroke="#FFFFFF" stroke-width="1.8" stroke-linecap="round" opacity="0.5"/>
</svg>
''',
  'green_popsicle': '''
<svg viewBox="0 0 64 64">
  <rect x="29.5" y="43" width="5" height="15" rx="2.5" fill="#E5C39B" stroke="#CFA676" stroke-width="0.8"/>
  <path d="M27 10 C35 9, 42 13, 42 21 L42 41 C42 43.5, 40 45, 37.5 45 L26.5 45 C24 45, 22 43.5, 22 41 L22 20 C24.5 20, 26 18.5, 26 16 C27.5 15, 28 12.5, 27 10 Z" fill="#B5D97C"/>
  <path d="M22 20 C24.5 20, 26 18.5, 26 16 C27.5 15, 28 12.5, 27 10" fill="none" stroke="#DCEFA8" stroke-width="2" stroke-linecap="round"/>
  <path d="M38 15 L38 41" stroke="#9BC45C" stroke-width="2.5" stroke-linecap="round" opacity="0.6"/>
  <path d="M26 23 L26 40" stroke="#D3ECAA" stroke-width="2" stroke-linecap="round" opacity="0.65"/>
</svg>
''',
  'peets_coffee': '''
<svg viewBox="0 0 64 64">
  <path d="M16 19 L20 54 C20.5 56.5, 25 58, 32 58 C39 58, 43.5 56.5, 44 54 L48 19 Z" fill="#2A120A"/>
  <path d="M16.5 19 L18 28 C23 30, 41 30, 46 28 L47.5 19 Z" fill="#C97D35"/>
  <ellipse cx="32" cy="17.5" rx="16.5" ry="4.5" fill="#E8C39E" stroke="#FFFFFF" stroke-width="1.2"/>
  <ellipse cx="32" cy="17.5" rx="14" ry="3.2" fill="#B86B25"/>
  <ellipse cx="29" cy="17" rx="6" ry="1.8" fill="#F3D6B6" opacity="0.8"/>
  <rect x="14.5" y="18" width="35" height="2.8" rx="1.4" fill="#F4EFEA"/>
  <path d="M20 24 L22.5 51" stroke="#FFFFFF" stroke-width="1.5" stroke-linecap="round" opacity="0.3"/>
</svg>
''',
  'pink_soft_serve': '''
<svg viewBox="0 0 64 64">
  <path d="M21 48 L42 48 L40 58 L23 58 Z" fill="#C48B71"/>
  <path d="M22 41 L42 41 L39 52 L25 52 Z" fill="#B8B5E0"/>
  <path d="M23 45 L41 45" stroke="#9A96CE" stroke-width="1.5"/>
  <path d="M19 37 C17 31, 23 29, 32 30 C41 29, 47 31, 45 37 C41 42, 23 42, 19 37 Z" fill="#F2BAC9"/>
  <path d="M20 29 C18 23, 24 21, 32 22 C40 21, 46 23, 44 29 C39 33, 25 33, 20 29 Z" fill="#F7CDD8"/>
  <path d="M22 21 C21 15, 26 14, 32 14 C38 14, 43 15, 42 21 C38 25, 26 25, 22 21 Z" fill="#F9DCE4"/>
  <path d="M25 14 C25 9, 29 6, 31 5 C35 7, 39 10, 39 14 C35 16.5, 29 16.5, 25 14 Z" fill="#F5B1C4"/>
  <path d="M23 36 C25 34, 31 35, 35 37" fill="none" stroke="#FFF9FB" stroke-width="2.5" stroke-linecap="round"/>
  <path d="M24 27 C27 25, 33 26, 37 28" fill="none" stroke="#FFF9FB" stroke-width="2.5" stroke-linecap="round"/>
  <path d="M26 19 C29 18, 34 18, 37 20" fill="none" stroke="#FFF9FB" stroke-width="2.2" stroke-linecap="round"/>
</svg>
''',
  'red_lemon_cocktail': '''
<svg viewBox="0 0 64 64">
  <circle cx="24" cy="16" r="9.5" fill="#F59E0B"/>
  <circle cx="24" cy="16" r="7.8" fill="#FDE68A"/>
  <path d="M24 8.5 L24 23.5 M16.5 16 L31.5 16 M18.5 10.5 L29.5 21.5 M29.5 10.5 L18.5 21.5" stroke="#F59E0B" stroke-width="1"/>
  <circle cx="24" cy="16" r="6.8" fill="none" stroke="#FFFFFF" stroke-width="0.9"/>
  <rect x="17" y="21" width="32" height="35" rx="4" fill="#E5E7EB" stroke="#D1D5DB" stroke-width="1"/>
  <rect x="18.5" y="24" width="29" height="29" rx="2.5" fill="#B91C1C"/>
  <rect x="18.5" y="24" width="29" height="9" rx="2" fill="#EA580C" opacity="0.85"/>
  <rect x="21" y="27" width="10" height="9" rx="2" fill="#FCA5A5" opacity="0.55" transform="rotate(-6 26 31)"/>
  <rect x="33" y="28" width="11" height="9" rx="2" fill="#FECACA" opacity="0.5" transform="rotate(8 38 32)"/>
  <rect x="25" y="38" width="12" height="9" rx="2" fill="#7F1D1D" opacity="0.6"/>
  <rect x="18" y="51" width="30" height="4.5" rx="2" fill="#F3F4F6"/>
  <path d="M20 53.5 L46 53.5" stroke="#9CA3AF" stroke-width="1.2"/>
  <line x1="17.5" y1="21.5" x2="48.5" y2="21.5" stroke="#FFFFFF" stroke-width="1.8" stroke-linecap="round"/>
</svg>
''',
  'tall_matcha_smoothie': '''
<svg viewBox="0 0 64 64">
  <defs>
    <linearGradient id="tallMatcha20" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#D9ECC7"/>
      <stop offset="40%" stop-color="#87B853"/>
      <stop offset="100%" stop-color="#3E6E19"/>
    </linearGradient>
  </defs>
  <path d="M18 19 L22 55 C22.5 57, 26 58.5, 32 58.5 C38 58.5, 41.5 57, 42 55 L46 19 Z" fill="url(#tallMatcha20)"/>
  <path d="M19 23 Q27 29 34 24 Q40 21 45 26 L44 35 Q36 31 28 36 Q22 33 20 29 Z" fill="#F3F8EC" opacity="0.75"/>
  <ellipse cx="29" cy="44" rx="5" ry="3" fill="#DCECC9" opacity="0.6"/>
  <path d="M17 19 C18 11, 25 8, 32 8 C39 8, 46 11, 47 19 Z" fill="#EBF4DF"/>
  <circle cx="28" cy="11" r="2.2" fill="#76A83E"/>
  <circle cx="34" cy="10.5" r="2.5" fill="#63962D"/>
  <circle cx="24" cy="14.5" r="2" fill="#85B64D"/>
  <circle cx="38" cy="14" r="2.2" fill="#76A83E"/>
  <circle cx="31" cy="14.5" r="2.4" fill="#94C55B"/>
  <ellipse cx="32" cy="19" rx="15.5" ry="2.6" fill="#FFFFFF" opacity="0.9"/>
  <path d="M21 24 L24 52" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round" opacity="0.55"/>
</svg>
''',
  'topdown_latte_art': '''
<svg viewBox="0 0 64 64">
  <defs>
    <radialGradient id="cremaGrad22" cx="50%" cy="45%" r="50%">
      <stop offset="0%" stop-color="#B86828"/>
      <stop offset="72%" stop-color="#8F4914"/>
      <stop offset="100%" stop-color="#6B3309"/>
    </radialGradient>
  </defs>
  <circle cx="32" cy="32" r="24" fill="url(#cremaGrad22)"/>
  <circle cx="32" cy="32" r="22.5" fill="none" stroke="#CA8143" stroke-width="0.8" opacity="0.5"/>
  <path d="M20 35 C15 26, 22 17, 27 20 C23 25, 22 33, 32 45 C42 33, 41 25, 37 20 C42 17, 49 26, 44 35 C40 42, 35 46, 32 49 C29 46, 24 42, 20 35 Z" fill="#F5E8DC" opacity="0.92"/>
  <path d="M32 42 C25 38, 22 32, 25 29 C28 31, 30 35, 32 38 C34 35, 36 31, 39 29 C42 32, 39 38, 32 42 Z" fill="#FFFDF9"/>
  <path d="M32 36 C26 32, 24 27, 27 24 C29 26, 31 29, 32 32 C33 29, 35 26, 37 24 C40 27, 38 32, 32 36 Z" fill="#FFFDF9"/>
  <path d="M32 30 C27 27, 26 22, 28.5 20 C30 21.5, 31 24, 32 26 C33 24, 34 21.5, 35.5 20 C38 22, 37 27, 32 30 Z" fill="#FFFDF9"/>
  <path d="M32 23 C29 20, 28 16, 30.5 15 C31.5 15, 32 16.5, 32 17.5 C32 16.5, 32.5 15, 33.5 15 C36 16, 35 20, 32 23 Z" fill="#FFFDF9"/>
  <path d="M32 15 L32 48" stroke="#8F4914" stroke-width="1.1" stroke-linecap="round"/>
</svg>
''',
};
