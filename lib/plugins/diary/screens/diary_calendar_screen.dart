import 'dart:math' as math;

import 'package:get/get.dart';
import 'package:aboutme/plugins/bill/widgets/month_selector.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/widgets/quill_viewer/index.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'diary_editor_screen.dart';
import 'package:aboutme/plugins/diary/models/diary_entry.dart';
import 'package:aboutme/plugins/diary/utils/diary_utils.dart';
import 'package:aboutme/plugins/diary/widgets/diary_entry_card.dart';

// ===== 设计稿色板（stitch_ui_style_replica_project，含深色适配）=====
const Color _darkWarm = Color(0xFF2D282A); // 暖黑（表情兜底线稿色）

/// 页面色板：浅色复刻设计稿，深色为同色相暗化版本
class _DiaryPalette {
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

  const _DiaryPalette({
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

  static const light = _DiaryPalette(
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

  static const dark = _DiaryPalette(
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

  static _DiaryPalette of(bool isDark) => isDark ? dark : light;
}

/// 心情表情类型（对应设计稿中手绘表情）
enum _MoodFaceKind { happy, excited, loved, surprised, tired, sad, angry, thinking, neutral }

/// 心情外观定义：底色 + 线稿色 + 点缀色（爱心/泪滴）
class _MoodSpec {
  final _MoodFaceKind kind;
  final Color bg;
  final Color stroke;
  final Color? accent;

  const _MoodSpec(this.kind, this.bg, this.stroke, {this.accent});
}

/// 编辑器心情 emoji -> 设计稿表情/配色 映射
const Map<String, _MoodSpec> _moodSpecs = {
  '😊': _MoodSpec(_MoodFaceKind.happy, Color(0xFFFEE5A5), Color(0xFF504229)),
  '🥳': _MoodSpec(_MoodFaceKind.excited, Color(0xFFBACBFC), Color(0xFF2E3C64)),
  '😍': _MoodSpec(_MoodFaceKind.loved, Color(0xFFF3D2D6), Color(0xFF5C4247), accent: Color(0xFFE2657A)),
  '😱': _MoodSpec(_MoodFaceKind.surprised, Color(0xFFD5CCF5), Color(0xFF4B4365)),
  '😴': _MoodSpec(_MoodFaceKind.tired, Color(0xFFC6EAE2), Color(0xFF3D524C)),
  '🤮': _MoodSpec(_MoodFaceKind.tired, Color(0xFFC6EAE2), Color(0xFF3D524C)),
  '🤔': _MoodSpec(_MoodFaceKind.thinking, Color(0xFFD5CCF5), Color(0xFF4B4365)),
  '😎': _MoodSpec(_MoodFaceKind.excited, Color(0xFFBACBFC), Color(0xFF2E3C64)),
  '😢': _MoodSpec(_MoodFaceKind.sad, Color(0xFF97C3F9), Color(0xFF1E4472), accent: Color(0xFF60A5FA)),
  '😡': _MoodSpec(_MoodFaceKind.angry, Color(0xFFFCAEAA), Color(0xFF682A27)),
};

// 心情 emoji -> 翻译 key（未命中时直接显示 emoji）
const Map<String, String> _moodNameKeys = {
  '😊': 'diary_mood_happy',
  '🥳': 'diary_mood_excited',
  '😍': 'diary_mood_loved',
  '😱': 'diary_mood_surprised',
  '😴': 'diary_mood_tired',
  '🤮': 'diary_mood_sick',
  '🤔': 'diary_mood_thinking',
  '😎': 'diary_mood_cool',
  '😢': 'diary_mood_sad',
  '😡': 'diary_mood_angry',
};

// 无心情记录时的中性脸
const _MoodSpec _neutralSpec = _MoodSpec(
  _MoodFaceKind.neutral,
  Color(0x66FFFFFF),
  Color(0x802D282A),
);

const List<Color> _fallbackPalette = [
  Color(0xFFFEE5A5),
  Color(0xFFC6EAE2),
  Color(0xFFBACBFC),
  Color(0xFFF3D2D6),
  Color(0xFF97C3F9),
  Color(0xFFFCAEAA),
  Color(0xFFD5CCF5),
];

/// 取心情外观，未知 emoji 时按哈希落到马卡龙色板
_MoodSpec _moodSpecOf(String mood) {
  return _moodSpecs[mood] ??
      _MoodSpec(
        _MoodFaceKind.happy,
        _fallbackPalette[mood.hashCode % _fallbackPalette.length],
        _darkWarm,
      );
}

class DiaryCalendarScreen extends StatefulWidget {
  final StorageManager storage;
  final DateTime? initialDate;

  const DiaryCalendarScreen({
    super.key,
    required this.storage,
    this.initialDate,
  });

  @override
  State<DiaryCalendarScreen> createState() => _DiaryCalendarScreenState();
}

class _DiaryCalendarScreenState extends State<DiaryCalendarScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  Map<DateTime, DiaryEntry> _diaryEntries = {};
  late CalendarController _calendarController;

  // 心情筛选（点击头部两侧表情切换，null 为不筛选）
  _MoodFaceKind? _moodFilter;

  // 搜索相关状态
  String _searchQuery = '';
  List<DiaryEntry> _searchResults = [];

  // GlobalKeys for OpenContainer animation
  final GlobalKey _editButtonKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // 使用 initialDate 或默认为今天
    final initialDay = widget.initialDate ?? DateTime.now();
    _focusedDay = initialDay;
    _selectedDay = DateTime(initialDay.year, initialDay.month, initialDay.day);
    _calendarController = CalendarController();
    _calendarController.displayDate = initialDay;
    _calendarController.selectedDate = _selectedDay;
    _loadDiaryEntries();

    // 订阅同步刷新事件
    EventManager.instance.subscribe('diary_refresh', _handleSyncRefresh);
  }

  @override
  void dispose() {
    // 取消订阅，避免内存泄漏
    EventManager.instance.unsubscribe('diary_refresh', _handleSyncRefresh);
    _calendarController.dispose();
    super.dispose();
  }

  /// 处理同步刷新事件
  void _handleSyncRefresh(EventArgs args) {
    debugPrint('[DiaryCalendarScreen] 收到同步刷新事件');
    _loadDiaryEntries();
  }

  Future<void> _loadDiaryEntries() async {
    final entries = await DiaryUtils.loadDiaryEntries();
    debugPrint('Loaded ${entries.length} diary entries');
    if (mounted) {
      setState(() {
        _diaryEntries = entries;
      });
    }
  }

  /// 处理搜索查询
  Future<void> _handleSearch(String query) async {
    setState(() {
      _searchQuery = query;
    });

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    // 执行搜索
    final results = await DiaryUtils.searchDiaryEntries(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
      });
    }
  }

  void _onDayClicked(DateTime selectedDay, DateTime focusedDay) {
    // 标准化选中的日期，只保留年月日
    final normalizedSelectedDay = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    setState(() {
      _selectedDay = normalizedSelectedDay;
      _focusedDay = focusedDay;
    });

    // 更新路由上下文，使"询问当前上下文"功能能获取到当前日期
    final dateStr =
        '${normalizedSelectedDay.year}-${normalizedSelectedDay.month.toString().padLeft(2, '0')}-${normalizedSelectedDay.day.toString().padLeft(2, '0')}';
    RouteHistoryManager.updateCurrentContext(
      pageId: "/diary_detail",
      title: '日记详情 - $dateStr',
      params: {'date': dateStr},
    );
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<String> _extractImagesFromContent(String content) {
    // Simple regex to find markdown images ![alt](url)
    final regex = RegExp(r'!\[.*?\]\((.*?)\)');
    final matches = regex.allMatches(content);
    return matches.map((m) => m.group(1)!).toList();
  }

  /// 月份统计：日记篇数与总字数（复用给月份选择弹窗）
  Map<String, double> _getMonthStats(DateTime month) {
    final monthEntries =
        _diaryEntries.entries.where((entry) {
          return entry.key.year == month.year &&
              entry.key.month == month.month;
        }).toList();

    final entryCount = monthEntries.length;
    final totalWords = monthEntries.fold(
      0,
      (sum, entry) => sum + entry.value.content.length,
    );

    return {
      'income': entryCount.toDouble(), // Use income for entry count
      'expense': totalWords.toDouble(), // Use expense for word count
    };
  }

  /// 月份统计展示：X篇日记 / X字
  Widget _buildMonthStats(Map<String, double> stats) {
    final entryCount = stats['income']?.toInt() ?? 0;
    final wordCount = stats['expense']?.toInt() ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$entryCount篇日记',
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF2ECC71), // 绿色
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          wordCount >= 1000
              ? '${(wordCount / 1000).toStringAsFixed(1)}k字'
              : '$wordCount字',
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF3498DB), // 蓝色
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: SuperCupertinoNavigationWrapper(
        title: Text('diary_myDiary'.tr),
        largeTitle: 'diary_myDiary'.tr,
        // 标题由粉色头部承载，这里只保留小导航栏 + 搜索
        enableLargeTitle: false,

        enableSearchBar: true,
        searchPlaceholder: 'diary_searchPlaceholder'.tr,
        onSearchChanged: _handleSearch,
        onSearchSubmitted: _handleSearch,
        // Builder 让视图方法在主题桥之内构建，可读取 AppTheme
        body: Builder(builder: _buildCalendarView),
        searchBody: Builder(builder: _buildSearchResults),
      ),
    );
  }

  /// 构建搜索结果视图
  Widget _buildSearchResults(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Container(
      color: theme.background,
      child:
          _searchResults.isEmpty
              ? Center(
                child: DSEmptyState(
                  emoji: '🔍',
                  title: '没有找到匹配的日记',
                  message: _searchQuery.isNotEmpty ? '搜索词：$_searchQuery' : null,
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final entry = _searchResults[index];
                  return _buildSearchResultCard(context, entry);
                },
              ),
    );
  }

  /// 构建搜索结果卡片
  Widget _buildSearchResultCard(BuildContext context, DiaryEntry entry) {
    final theme = DSThemeBridge.resolve(context);
    return DiaryEntryCard(
      entry: entry,
      primaryColor: theme.primary,
      textColor: theme.text,
      onTap: () => _navigateToEntry(entry),
    );
  }

  /// 跳转到指定日记条目
  void _navigateToEntry(DiaryEntry entry) {
    NavigationHelper.push(
      context,
      DiaryEditorScreen(
        date: entry.date,
        storage: widget.storage,
        initialTitle: entry.title,
        initialContent: entry.content,
      ),
    ).then((_) => _loadDiaryEntries());
  }

  /// 构建日历视图
  Widget _buildCalendarView(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    // 确保_selectedDay也是标准化的
    final normalizedSelectedDay =
        _selectedDay != null
            ? DateTime(
              _selectedDay!.year,
              _selectedDay!.month,
              _selectedDay!.day,
            )
            : null;
    final selectedEntry =
        normalizedSelectedDay != null
            ? _diaryEntries[normalizedSelectedDay]
            : null;
    final textColor = theme.text;
    final primaryColor = theme.primary;
    final palette = _DiaryPalette.of(theme.isDark);

    return Stack(
      children: [
        Container(
          color: palette.canvas,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // 粉色圆角头部：标题 + 心情轮播 + 悬浮月份胶囊
                _buildHeader(palette, selectedEntry),

                const SizedBox(height: 34),

                // Calendar
                SfCalendar(
                  controller: _calendarController,
                  view: CalendarView.month,
                  initialDisplayDate: _focusedDay,
                  minDate: DateTime.utc(2020, 1, 1),
                  maxDate: DateTime.now(),
                  headerHeight: 0,
                  viewHeaderHeight: 36,
                  showNavigationArrow: false,
                  firstDayOfWeek: 1, // 周一开头（与设计稿一致）
                  todayHighlightColor: Colors.transparent,
                  viewHeaderStyle: ViewHeaderStyle(
                    backgroundColor: palette.canvas,
                    dayTextStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: palette.textMuted,
                    ),
                  ),
                  monthViewSettings: const MonthViewSettings(
                    showTrailingAndLeadingDates: true,
                    dayFormat: 'EEE',
                  ),
                  cellBorderColor: Colors.transparent,
                  selectionDecoration: const BoxDecoration(),
                  monthCellBuilder: (
                    BuildContext context,
                    MonthCellDetails details,
                  ) {
                    return _buildDayCell(palette, details.date);
                  },
                  onTap: (CalendarTapDetails details) {
                    if (details.date != null) {
                      _onDayClicked(details.date!, details.date!);
                      setState(() {
                        _calendarController.selectedDate = details.date;
                      });
                    }
                  },
                  onViewChanged: (ViewChangedDetails details) {
                    if (details.visibleDates.isNotEmpty) {
                      final newFocusedDay =
                          details.visibleDates[details.visibleDates.length ~/ 2];
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _focusedDay = newFocusedDay;
                          });
                        }
                      });
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Selected Day Details
                if (_selectedDay != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    margin: const EdgeInsets.only(
                      bottom: 80,
                    ), // Add padding for FAB
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 日期和编辑按钮行
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('MMMM d, yyyy').format(_selectedDay!),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            DSButton(
                              key: _editButtonKey,
                              label:
                                  selectedEntry != null
                                      ? 'diary_edit'.tr
                                      : 'diary_create'.tr,
                              icon:
                                  selectedEntry != null
                                      ? DsIconKind.edit
                                      : DsIconKind.plus,
                              size: DSButtonSize.sm,
                              onPressed: () {
                                final targetDay = _selectedDay ?? DateTime.now();
                                final normalizedTargetDay = DateTime(
                                  targetDay.year,
                                  targetDay.month,
                                  targetDay.day,
                                );
                                NavigationHelper.openContainerWithHero(
                                  context,
                                  (_) => DiaryEditorScreen(
                                    date: normalizedTargetDay,
                                    storage: widget.storage,
                                    initialTitle: selectedEntry?.title ?? '',
                                    initialContent: selectedEntry?.content ?? '',
                                  ),
                                  sourceKey: _editButtonKey,
                                  heroTag: 'diary_edit_button',
                                  closedColor: primaryColor,
                                  closedShape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ).then((_) => _loadDiaryEntries());
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (selectedEntry != null) ...[
                          // Images list (if any)
                          Builder(
                            builder: (context) {
                              final images = _extractImagesFromContent(
                                selectedEntry.content,
                              );
                              if (images.isEmpty) return const SizedBox.shrink();
                              return Container(
                                height: 100,
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: images.length,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      width: 100,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            images[index],
                                          ), // Or FileImage if local
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                          Container(
                            constraints: const BoxConstraints(
                              minHeight: 200, // Minimum height for better UX
                            ),
                            child: QuillViewer(
                              data: selectedEntry.content,
                              selectable: true,
                            ),
                          ),
                        ] else ...[
                          SizedBox(
                            height: 200,
                            child: Center(
                              child: DSEmptyState(
                                emoji: '📖',
                                title: 'diary_noDiaryForDate'.tr,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  const SizedBox(
                    height: 80,
                  ), // Placeholder when no date is selected
              ],
            ),
          ),
        ),
        // FAB with container transform animation
        Positioned(
          bottom: 16,
          right: 16,
          child: DSFab(
            key: _fabKey,
            size: 56,
            onPressed: () {
              final targetDay = _selectedDay ?? DateTime.now();
              final normalizedTargetDay = DateTime(
                targetDay.year,
                targetDay.month,
                targetDay.day,
              );
              // 获取当前选中日期的条目
              final entry = _diaryEntries[normalizedTargetDay];
              NavigationHelper.openContainerWithHero(
                context,
                (_) => DiaryEditorScreen(
                  date: normalizedTargetDay,
                  storage: widget.storage,
                  initialTitle: entry?.title ?? '',
                  initialContent: entry?.content ?? '',
                ),
                sourceKey: _fabKey,
                heroTag: 'diary_fab_add',
                closedColor: primaryColor,
                closedShape: const CircleBorder(),
              ).then((_) => _loadDiaryEntries());
            },
          ),
        ),
      ],
    );
  }

  /// 粉色圆角头部：问题标题 + 心情轮播 + 心情名 + 悬浮月份胶囊
  Widget _buildHeader(_DiaryPalette palette, DiaryEntry? selectedEntry) {
    final mood = selectedEntry?.mood;
    final centerSpec = mood != null ? _moodSpecOf(mood) : _neutralSpec;
    final moodName =
        mood != null ? (_moodNameKeys[mood]?.tr ?? mood) : 'diary_noMoodRecord'.tr;

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
  Widget _buildMoodCarousel(_DiaryPalette palette, _MoodSpec centerSpec) {
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
          child: _MoodFaceCircle(spec: centerSpec, size: 56),
        ),
        const SizedBox(width: 12),
        _buildCarouselFace(palette, '😍', size: 40),
        const SizedBox(width: 14),
        _buildCarouselFace(palette, '😱', size: 36),
      ],
    );
  }

  Widget _buildCarouselFace(
    _DiaryPalette palette,
    String emoji, {
    required double size,
  }) {
    final spec = _moodSpecOf(emoji);
    final active = _moodFilter == spec.kind;
    return GestureDetector(
      onTap: () => setState(() => _moodFilter = active ? null : spec.kind),
      child: Opacity(
        opacity: active ? 1 : 0.92,
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? palette.pillBg : Colors.transparent,
          ),
          child: _MoodFaceCircle(spec: spec, size: size),
        ),
      ),
    );
  }

  /// 白色月份胶囊按钮，点击弹出月份选择
  Widget _buildMonthPill(_DiaryPalette palette) {
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
                DateTime(_focusedDay.year, _focusedDay.month),
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
          selectedMonth: _focusedDay,
          maxDate: DateTime.now(), // 限制不能选择未来月份
          primaryColor: theme.primary,
          getMonthStats: _getMonthStats,
          customStatsBuilder: _buildMonthStats,
          onMonthSelected: (month) {
            Navigator.pop(sheetContext);
            setState(() {
              // 选中日可能超出目标月天数（如31日切到2月），取月末兜底
              final lastDay = DateTime(month.year, month.month + 1, 0).day;
              _focusedDay = DateTime(
                month.year,
                month.month,
                _focusedDay.day.clamp(1, lastDay),
              );
              _calendarController.displayDate = _focusedDay;
            });
          },
        ),
      ),
    );
  }

  /// 日历格：马卡龙色心情圆 + 下方日期；✦ 标记含图片的日记
  Widget _buildDayCell(_DiaryPalette palette, DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final entry = _diaryEntries[normalizedDay];
    final isToday = _isSameDay(DateTime.now(), day);
    final isSelected = _isSameDay(_selectedDay, day);
    final isOtherMonth =
        day.year != _focusedDay.year || day.month != _focusedDay.month;
    final now = DateTime.now();
    final isFuture = day.isAfter(DateTime(now.year, now.month, now.day));

    final spec = entry?.mood != null ? _moodSpecOf(entry!.mood!) : null;

    var opacity = 1.0;
    if (isOtherMonth) opacity = 0.55;
    if (isFuture) opacity = math.min(opacity, 0.35);
    // 心情筛选：不匹配的日子淡出
    if (_moodFilter != null && spec?.kind != _moodFilter) {
      opacity = math.min(opacity, 0.18);
    }

    final hasImages =
        entry != null && _extractImagesFromContent(entry.content).isNotEmpty;

    // 格子高度由 SfCalendar 决定（行数不同会变化），
    // 用 FittedBox 整体缩放，保证内容永不溢出
    return Opacity(
      opacity: opacity,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildDayCircle(
                    palette,
                    spec,
                    hasEntry: entry != null,
                    isSelected: isSelected,
                    isToday: isToday,
                  ),
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
                      (isToday || isSelected)
                          ? FontWeight.w800
                          : FontWeight.w600,
                  color:
                      isOtherMonth
                          ? palette.textOtherMonth
                          : ((isToday || isSelected)
                              ? palette.textPrimary
                              : palette.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 日历格中的圆形心情图标；无日记时为米白空泡
  Widget _buildDayCircle(
    _DiaryPalette palette,
    _MoodSpec? spec, {
    required bool hasEntry,
    required bool isSelected,
    required bool isToday,
  }) {
    Widget circle;
    if (spec != null) {
      circle = _MoodFaceCircle(spec: spec, size: 30);
    } else if (hasEntry) {
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
              color:
                  isSelected ? palette.haloSelected : palette.haloToday,
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

/// 马卡龙色圆形 + 手绘心情表情
class _MoodFaceCircle extends StatelessWidget {
  final _MoodSpec spec;
  final double size;

  const _MoodFaceCircle({required this.spec, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: spec.bg, shape: BoxShape.circle),
      child: Center(
        child: CustomPaint(
          size: Size.square(size * 0.62),
          painter: _MoodFacePainter(
            kind: spec.kind,
            color: spec.stroke,
            accent: spec.accent,
          ),
        ),
      ),
    );
  }
}

/// 手绘风格心情表情，在 24x24 逻辑坐标系中绘制
class _MoodFacePainter extends CustomPainter {
  final _MoodFaceKind kind;
  final Color color;
  final Color? accent;

  const _MoodFacePainter({
    required this.kind,
    required this.color,
    this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale, scale);
    final strokePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
    final fillPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), strokePaint);

    // 两点间弧线，cy 为控制点纵坐标（小于端点为向上鼓，大于为向下鼓）
    void arc(double x1, double y1, double x2, double y2, double cy) {
      final p =
          Path()
            ..moveTo(x1, y1)
            ..quadraticBezierTo((x1 + x2) / 2, cy, x2, y2);
      canvas.drawPath(p, strokePaint);
    }

    void dot(double cx, double cy, [double r = 1.3]) =>
        canvas.drawCircle(Offset(cx, cy), r, fillPaint);

    // 下半圆张嘴
    void bowl(double cx, double cy, double r) {
      final p =
          Path()
            ..moveTo(cx - r, cy)
            ..arcToPoint(
              Offset(cx + r, cy),
              radius: Radius.circular(r),
              clockwise: false,
            )
            ..close();
      canvas.drawPath(p, fillPaint);
    }

    switch (kind) {
      case _MoodFaceKind.happy:
        arc(6, 10, 10.5, 10, 7); // 左眼 ∩
        arc(13.5, 10, 18, 10, 7); // 右眼 ∩
        arc(9, 14.8, 15, 14.8, 17.4); // 微笑
      case _MoodFaceKind.excited:
        dot(8, 10); // 左眼
        line(13.2, 10.6, 16.8, 9); // 右眼眨眼
        bowl(12, 14.2, 2.2); // 张嘴笑
      case _MoodFaceKind.loved:
        final heartPaint =
            Paint()
              ..color = accent ?? color
              ..style = PaintingStyle.fill;
        canvas.drawPath(_heart(7.6, 10, 1.8), heartPaint);
        canvas.drawPath(_heart(16.4, 10, 1.8), heartPaint);
        arc(10.6, 14.4, 13.4, 14.4, 16); // 小微笑
      case _MoodFaceKind.surprised:
        dot(8, 10);
        dot(16, 10);
        canvas.drawOval(const Rect.fromLTRB(10.6, 13.2, 13.4, 17.6), fillPaint);
      case _MoodFaceKind.tired:
        line(6.2, 8.9, 9.2, 11.3); // 左眼 X
        line(9.2, 8.9, 6.2, 11.3);
        line(14.8, 8.9, 17.8, 11.3); // 右眼 X
        line(17.8, 8.9, 14.8, 11.3);
        line(10, 15.6, 14, 15.6); // 嘴巴一条线
      case _MoodFaceKind.sad:
        arc(7, 9.6, 10.6, 9.6, 11.4); // 左眼 ∪
        arc(13.4, 9.6, 17, 9.6, 11.4); // 右眼 ∪
        bowl(12, 15.6, 2); // 张嘴
        if (accent != null) {
          final tearPaint =
              Paint()
                ..color = accent!
                ..style = PaintingStyle.fill;
          canvas.drawOval(const Rect.fromLTRB(6.2, 12, 7.8, 15.6), tearPaint);
          canvas.drawOval(const Rect.fromLTRB(16.2, 12, 17.8, 15.6), tearPaint);
        }
      case _MoodFaceKind.angry:
        line(6.4, 8.2, 9.6, 10); // 左眉
        line(17.6, 8.2, 14.4, 10); // 右眉
        dot(9, 11.6);
        dot(15, 11.6);
        arc(10, 16.6, 14, 16.6, 14.9); // 撇嘴
      case _MoodFaceKind.thinking:
        line(6.2, 7.9, 9.4, 8.9); // 挑眉
        dot(8, 10.4);
        dot(16, 10.4);
        line(10.4, 15.9, 13.6, 15.2); // 歪嘴
      case _MoodFaceKind.neutral:
        dot(8, 10);
        dot(16, 10);
        line(10, 15.4, 14, 15.4);
    }
  }

  /// 以 (cx, cy) 为中心的心形路径
  Path _heart(double cx, double cy, double s) {
    return Path()
      ..moveTo(cx, cy + s * 0.9)
      ..cubicTo(cx - s * 1.15, cy + s * 0.05, cx - s * 0.6, cy - s * 0.9, cx, cy - s * 0.32)
      ..cubicTo(cx + s * 0.6, cy - s * 0.9, cx + s * 1.15, cy + s * 0.05, cx, cy + s * 0.9)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _MoodFacePainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.color != color ||
      oldDelegate.accent != accent;
}
